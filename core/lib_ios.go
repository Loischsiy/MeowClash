//go:build ios && cgo

package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"core/mobilebridge"
	"core/state"
	"core/tun"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
	"unsafe"

	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener/sing_tun"
)

const maxIOSMessageBytes = 8 << 20

var iosReplies = mobilebridge.NewBroker(8)
var iosEvents = mobilebridge.NewEventQueue(128, 256<<10)
var iosActions sync.Mutex
var iosActionCompletions sync.Map // port -> actual handler completion
var iosTunnel *sing_tun.Listener
var iosIsExtension, iosCacheReady bool

// Called once by each process, before any action. The app and extension have
// distinct BoltDB caches. Closing UI/backgrounding never closes the VPN core.
//
//export meowSetTunnelProcess
func meowSetTunnelProcess(extension C.int) {
	iosActions.Lock()
	defer iosActions.Unlock()
	iosIsExtension = extension != 0
}

func iosInitCache(home string) error {
	if iosCacheReady {
		return nil
	}
	name := ".ios-ui-cache"
	if iosIsExtension {
		name = ".ios-tunnel-cache"
	}
	cacheDir := filepath.Join(home, name)
	if err := os.MkdirAll(cacheDir, 0700); err != nil {
		return err
	}
	// Cache() captures its path once. All asset/provider paths keep the shared
	// home afterwards; only the process-owned database goes into this subdir.
	constant.SetHomeDir(cacheDir)
	cache := cachefile.Cache()
	constant.SetHomeDir(home)
	if cache.DB == nil {
		return fmt.Errorf("could not open the iOS core cache")
	}
	iosCacheReady = true
	return nil
}

func (result ActionResult) send() {
	defer func() {
		if done, ok := iosActionCompletions.LoadAndDelete(result.Port); ok {
			close(done.(chan struct{}))
		}
	}()
	if err, ok := result.Data.(error); ok {
		result.Data = err.Error()
	}
	data, err := result.Json()
	if err != nil || len(data) > maxIOSMessageBytes {
		result.Code, result.Data = -1, "iOS core response exceeds the bridge limit or cannot be encoded"
		data, _ = result.Json()
	}
	iosReplies.Reply(result.Port, data)
}

func sendMessage(message Message) {
	data, err := (ActionResult{Method: messageMethod, Data: message}).Json()
	if err == nil {
		iosEvents.Push(data)
	}
}

func iosError(action Action, message string) *C.char {
	data, _ := (ActionResult{Id: action.Id, Method: action.Method, Code: -1, Data: message}).Json()
	return C.CString(string(data))
}

//export meowInvokeAction
func meowInvokeAction(input *C.char) *C.char {
	text := C.GoString(input)
	var action Action
	if len(text) > maxIOSMessageBytes {
		return iosError(action, "iOS request exceeds 8 MiB")
	}
	if err := json.Unmarshal([]byte(text), &action); err != nil {
		return iosError(action, err.Error())
	}
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	data, err := iosReplies.Call(ctx, func(port int64) {
		result := ActionResult{Id: action.Id, Method: action.Method, Port: port}
		defer func() {
			if r := recover(); r != nil {
				result.error(fmt.Sprintf("core panic: %v", r))
			}
		}()
		iosActions.Lock()
		defer iosActions.Unlock()
		if ctx.Err() != nil {
			return
		}
		if err := prepareIOSAction(&action); err != nil {
			result.error(err.Error())
			return
		}
		// Some core handlers complete asynchronously. Keep the ownership lock
		// until their callback, even if the IPC caller has already timed out.
		// A late provider write must finish before another config or handoff.
		done := make(chan struct{})
		iosActionCompletions.Store(port, done)
		defer iosActionCompletions.Delete(port)
		handleAction(&action, result)
		<-done
	})
	if err != nil {
		return iosError(action, err.Error())
	}
	return C.CString(string(data))
}

// Disable OS routing/listeners that belong to NetworkExtension. This changes
// only the runtime copy; the user's original profile is not rewritten.
func prepareIOSAction(action *Action) error {
	text, ok := action.Data.(string)
	if action.Method == initClashMethod {
		var params InitParams
		if !ok {
			return fmt.Errorf("missing init parameters")
		}
		if err := json.Unmarshal([]byte(text), &params); err != nil {
			return err
		}
		return iosInitCache(params.HomeDir)
	}
	if action.Method != setupConfigMethod && action.Method != updateConfigMethod {
		return nil
	}
	if !ok {
		return fmt.Errorf("missing configuration")
	}
	var params map[string]any
	if err := json.Unmarshal([]byte(text), &params); err != nil {
		return err
	}
	raw := params
	if action.Method == setupConfigMethod {
		var exists bool
		raw, exists = params["config"].(map[string]any)
		if !exists {
			return fmt.Errorf("missing config object")
		}
	}
	raw["external-controller"] = ""
	raw["external-controller-tls"] = ""
	raw["external-controller-unix"] = ""
	raw["external-controller-pipe"] = ""
	raw["find-process-mode"] = "off"
	raw["interface-name"] = ""
	raw["allow-lan"] = false
	raw["bind-address"] = "127.0.0.1"
	raw["redir-port"], raw["tproxy-port"] = 0, 0
	if t, ok := raw["tun"].(map[string]any); ok {
		t["enable"], t["auto-route"], t["auto-detect-interface"] = false, false, false
	}
	if action.Method == setupConfigMethod {
		raw["listeners"] = []any{}
		raw["ss-config"], raw["vmess-config"] = "", ""
		delete(raw, "tuic-server")
		if dns, ok := raw["dns"].(map[string]any); ok {
			dns["listen"] = ""
		}
	}
	encoded, err := json.Marshal(params)
	if err == nil {
		action.Data = string(encoded)
	}
	return err
}

func nextHandle(action *Action, result ActionResult) bool {
	result.error("unsupported iOS core method")
	return false
}

//export meowDrainEvents
func meowDrainEvents() *C.char {
	items := iosEvents.Drain()
	encoded := make([]json.RawMessage, 0, len(items))
	for _, data := range items {
		encoded = append(encoded, json.RawMessage(data))
	}
	data, _ := json.Marshal(encoded)
	return C.CString(string(data))
}

//export meowFreeCString
func meowFreeCString(value *C.char) { C.free(unsafe.Pointer(value)) }

//export meowStartTun
func meowStartTun(fd C.int) *C.char {
	iosActions.Lock()
	defer iosActions.Unlock()
	if !iosIsExtension {
		return C.CString("TUN can only be started by PacketTunnel")
	}
	if currentConfig == nil {
		return C.CString("load a profile before starting VPN")
	}
	if iosTunnel != nil {
		_ = iosTunnel.Close()
		iosTunnel = nil
	}
	iosSyncIPv6()
	instance, err := tun.Start(int(fd), "MeowClash", currentConfig.General.Tun.Stack)
	if err != nil {
		return C.CString(err.Error())
	}
	iosTunnel = instance
	return C.CString("")
}

//export meowStopTun
func meowStopTun() {
	iosActions.Lock()
	defer iosActions.Unlock()
	if iosTunnel != nil {
		_ = iosTunnel.Close()
		iosTunnel = nil
	}
	// A network-settings refresh replaces only the TUN socket. Preserve core
	// listeners/isRunning here; meowSuspendCore stops them on full shutdown.
}

// Release the app's preview providers, listeners, logs and queues before the
// extension takes over. The extension is never shut down when Flutter detaches.
//
//export meowSuspendCore
func meowSuspendCore() {
	iosActions.Lock()
	defer iosActions.Unlock()
	handleStopListener()
	handleStopLog()
	stopHealthCheckForwarder()
	empty, err := config.ParseRawConfig(config.DefaultRawConfig())
	if err == nil {
		executor.ApplyConfig(empty, false)
	}
	currentConfig = nil
	isInit = false
	iosEvents.Drain()
	handleForceGc()
}

// Keep the state import explicit: IPv6 TUN addressing is owned by the applied
// raw config on iOS, not Android's VpnService UI preference.
func iosSyncIPv6() {
	if currentConfig != nil {
		state.CurrentState.VpnProps.Ipv6 = currentConfig.General.IPv6
	}
}
