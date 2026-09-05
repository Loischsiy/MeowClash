package main

import (
	"context"
	"encoding/json"
	"runtime"
	"time"

	"github.com/metacubex/mihomo/common/utils"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

func manualDelayConcurrency() int {
	if runtime.GOOS == "android" {
		return 4
	}
	return 12
}

var manualDelaySlots = make(chan struct{}, manualDelayConcurrency())
var manualDelayProxies proxyLookupCache // guarded by runLock

func delayTimeout(milliseconds int64) time.Duration {
	if milliseconds <= 0 || milliseconds > 5000 {
		milliseconds = 5000
	}
	return time.Duration(milliseconds) * time.Millisecond
}

func acquireDelaySlot(ctx context.Context, slots chan struct{}) bool {
	if ctx.Err() != nil {
		return false
	}
	select {
	case slots <- struct{}{}:
		if ctx.Err() != nil {
			<-slots
			return false
		}
		return true
	case <-ctx.Done():
		return false
	}
}

// The response belongs to the initiating request. Do not additionally send an
// unsolicited DelayMessage: that duplicates every update and bypasses the
// Dart runner's cancellation/generation check after a profile switch.
func handleAsyncTestDelay(paramsString string, fn func(string)) {
	var params TestDelayParams
	if err := json.Unmarshal([]byte(paramsString), &params); err != nil {
		fn("")
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), delayTimeout(params.Timeout))
	go func() {
		defer cancel()
		url := params.TestUrl
		if url == "" {
			url = "https://www.gstatic.com/generate_204"
		}
		result := Delay{Name: params.ProxyName, Url: url, Value: -1}
		defer func() {
			if failure := recover(); failure != nil {
				log.Warnln("[Delay] URL test failed: %v", failure)
				result.Value = -1
			}
			data, _ := json.Marshal(result)
			fn(string(data))
		}()
		if !acquireDelaySlot(ctx, manualDelaySlots) {
			return
		}
		defer func() { <-manualDelaySlots }()

		proxy := lookupDelayProxy(params.ProxyName)
		if proxy == nil || ctx.Err() != nil {
			return
		}
		expected, err := utils.NewUnsignedRanges[uint16]("")
		if err != nil {
			return
		}
		delay, err := proxy.URLTest(ctx, url, expected)
		if err == nil && delay > 0 {
			result.Value = int32(delay)
		}
	}()
}

func lookupDelayProxy(name string) C.Proxy {
	// Serialize only snapshot/index access with profile changes, never network
	// I/O. Unchanged providers take O(number of providers) map lookups.
	runLock.Lock()
	defer runLock.Unlock()
	return manualDelayProxies.lookup(name, tunnel.Proxies(), tunnel.Providers())
}

type providerProxyIndex struct {
	provider P.ProxyProvider
	version  uint32
	proxies  map[string]C.Proxy
}

type proxyLookupCache struct{ entries map[string]providerProxyIndex }

func (cache *proxyLookupCache) lookup(name string, inline map[string]C.Proxy, providers map[string]P.ProxyProvider) C.Proxy {
	if cache.entries == nil {
		cache.entries = make(map[string]providerProxyIndex)
	}
	for providerName := range cache.entries {
		if _, exists := providers[providerName]; !exists {
			delete(cache.entries, providerName)
		}
	}
	result := inline[name]
	for providerName, provider := range providers {
		version := provider.Version()
		entry, exists := cache.entries[providerName]
		if !exists || entry.provider != provider || entry.version != version {
			proxies := provider.Proxies()
			byName := make(map[string]C.Proxy, len(proxies))
			for _, proxy := range proxies {
				byName[proxy.Name()] = proxy
			}
			entry = providerProxyIndex{provider: provider, version: version, proxies: byName}
			// Version and Proxies are separately locked upstream. Never cache
			// a snapshot under the wrong version if an update raced this read.
			if provider.Version() == version {
				cache.entries[providerName] = entry
			} else {
				delete(cache.entries, providerName)
			}
		}
		if proxy := entry.proxies[name]; proxy != nil {
			result = proxy
		}
	}
	return result
}
