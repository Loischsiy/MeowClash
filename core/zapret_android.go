//go:build android && cgo

package main

import "C"

// zapret2 Android seam — userspace DPI-bypass packet mutation.
//
// WHY THIS EXISTS
// On a non-root Android device there is no userspace NFQUEUE, so the desktop
// `nfqws` approach cannot run. Instead, the additive zapret2 mode applies DPI
// evasion as *userspace packet mutation on the sing-tun read path*, entirely
// inside libclash.so, driven from Dart over the "zapret2" method channel
// (see lib/services/zapret/backends/android_backend.dart).
//
// STATUS: experimental seam. This file defines the integration surface and the
// state the tun read loop consults; the actual per-packet mutation on the
// sing-tun path is the remaining R&D step (see integration point below). Until
// a strategy is applied, zapret2ShouldMutate() returns false and the tun path
// behaves exactly as before — the feature is inert and additive.
//
// INTEGRATION POINT (core/lib_android.go TunHandler): after the sing-tun
// listener reads a packet and before it is handed to the tunnel, call
// zapret2MutateOutbound(pkt) when zapret2ShouldMutate() is true. The mutation
// interprets a supported subset of the strategy flags (TTL, split, fake) on
// outbound TLS/QUIC (:443) flows to the configured targets.

import (
	"encoding/json"
	"sync"
	"sync/atomic"
)

// zapret2State holds the currently-applied strategy. It is written from the
// Dart method-channel handler ("apply"/"clear") and read (lock-free via the
// atomic flag) from the hot tun read loop.
type zapret2StateT struct {
	mu       sync.RWMutex
	enabled  atomic.Bool
	strategy string
	args     []string
	// hostFilter is the set of target hostnames this strategy applies to
	// (empty = all). Populated from the Dart "apply" payload.
	hostFilter map[string]struct{}
}

var zapret2State = &zapret2StateT{hostFilter: map[string]struct{}{}}

// zapret2ShouldMutate reports whether a strategy is currently applied. Cheap
// enough to call per-packet (single atomic load).
func zapret2ShouldMutate() bool { return zapret2State.enabled.Load() }

// zapret2Apply installs a strategy. Called from the Android "zapret2.apply"
// channel handler. Returns true when the strategy is accepted.
func zapret2Apply(strategy string, args []string, hosts []string) bool {
	zapret2State.mu.Lock()
	defer zapret2State.mu.Unlock()
	zapret2State.strategy = strategy
	zapret2State.args = args
	zapret2State.hostFilter = make(map[string]struct{}, len(hosts))
	for _, h := range hosts {
		zapret2State.hostFilter[h] = struct{}{}
	}
	zapret2State.enabled.Store(strategy != "")
	return zapret2State.enabled.Load()
}

//export zapret2ApplyNative
func zapret2ApplyNative(strategyChar *C.char, argsChar *C.char, hostsChar *C.char) bool {
	var args []string
	var hosts []string
	_ = json.Unmarshal([]byte(C.GoString(argsChar)), &args)
	_ = json.Unmarshal([]byte(C.GoString(hostsChar)), &hosts)
	return zapret2Apply(C.GoString(strategyChar), args, hosts)
}

// zapret2Clear removes any applied strategy (channel "zapret2.clear").
func zapret2Clear() {
	zapret2State.mu.Lock()
	defer zapret2State.mu.Unlock()
	zapret2State.strategy = ""
	zapret2State.args = nil
	zapret2State.hostFilter = map[string]struct{}{}
	zapret2State.enabled.Store(false)
}

//export zapret2ClearNative
func zapret2ClearNative() {
	zapret2Clear()
}

// zapret2MutateOutbound is the hook the tun read loop calls for each outbound
// packet when zapret2ShouldMutate() is true. It returns the (possibly rewritten)
// packet bytes.
//
// TODO(zapret2-android): implement the actual mutation on the sing-tun path
// (TTL clamp / fake / segment split for TLS ClientHello and QUIC Initial on
// :443, gated by hostFilter). Wiring: call from TunHandler in
// core/lib_android.go right after listener.ServePacket reads a packet. This is
// the userspace-mutation R&D deliverable; until it lands the function is an
// identity pass-through so the tun path is unchanged.
func zapret2MutateOutbound(pkt []byte) []byte {
	// Identity pass-through until the sing-tun mutation is implemented.
	return pkt
}
