package main

import (
	"context"
	"encoding/json"
	"math"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
)

func TestDelaySlotsBoundConcurrency(t *testing.T) {
	slots := make(chan struct{}, 4)
	var active, maximum atomic.Int32
	var workers sync.WaitGroup
	for i := 0; i < 100; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			if !acquireDelaySlot(context.Background(), slots) {
				t.Error("acquire failed")
				return
			}
			n := active.Add(1)
			for old := maximum.Load(); n > old && !maximum.CompareAndSwap(old, n); old = maximum.Load() {
			}
			time.Sleep(time.Millisecond)
			active.Add(-1)
			<-slots
		}()
	}
	workers.Wait()
	if maximum.Load() > 4 || len(slots) != 0 {
		t.Fatalf("max=%d slots=%d", maximum.Load(), len(slots))
	}
}

func TestDelayQueueHonorsDeadline(t *testing.T) {
	slots := make(chan struct{}, 1)
	slots <- struct{}{}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
	defer cancel()
	if acquireDelaySlot(ctx, slots) {
		t.Fatal("expired queued task acquired slot")
	}
	<-slots
	if acquireDelaySlot(ctx, slots) {
		t.Fatal("already expired task acquired a free slot")
	}
}

func TestDelayTimeoutIsBounded(t *testing.T) {
	for _, value := range []int64{-1, 0, 6000, math.MaxInt64} {
		if delayTimeout(value) != 5*time.Second {
			t.Errorf("unexpected timeout for %d", value)
		}
	}
	if delayTimeout(100) != 100*time.Millisecond {
		t.Fatal("valid timeout changed")
	}
}

type lookupProxy struct {
	C.Proxy
	name string
}

func (p *lookupProxy) Name() string { return p.name }

type lookupProvider struct {
	P.ProxyProvider
	proxies     []C.Proxy
	version     uint32
	reads       int
	raceVersion bool
}

func (p *lookupProvider) Version() uint32 { return p.version }
func (p *lookupProvider) Proxies() []C.Proxy {
	p.reads++
	if p.raceVersion {
		p.version++
	}
	return p.proxies
}

func TestDelayProxyIndexRefreshAndNoPerProbeCopy(t *testing.T) {
	a := &lookupProxy{name: "a"}
	b := &lookupProxy{name: "b"}
	provider := &lookupProvider{proxies: []C.Proxy{a}, version: 1}
	providers := map[string]P.ProxyProvider{"source": provider}
	var cache proxyLookupCache
	for i := 0; i < 10000; i++ {
		if cache.lookup("a", nil, providers) != a {
			t.Fatal("proxy missing")
		}
	}
	if provider.reads != 1 {
		t.Fatalf("copied provider %d times", provider.reads)
	}
	provider.proxies = []C.Proxy{b}
	provider.version++
	if cache.lookup("a", nil, providers) != nil || cache.lookup("b", nil, providers) != b {
		t.Fatal("stale provider membership")
	}
	replacement := &lookupProvider{proxies: []C.Proxy{a}, version: provider.version}
	providers["source"] = replacement
	if cache.lookup("a", nil, providers) != a {
		t.Fatal("same-version provider replacement was not detected")
	}
	delete(providers, "source")
	if cache.lookup("a", nil, providers) != nil || len(cache.entries) != 0 {
		t.Fatal("removed provider retained")
	}
	if cache.lookup("b", map[string]C.Proxy{"b": b}, nil) != b {
		t.Fatal("inline proxy missing")
	}
}

func TestDelayIndexDoesNotCacheRacingSnapshot(t *testing.T) {
	p := &lookupProvider{proxies: []C.Proxy{&lookupProxy{name: "a"}}, raceVersion: true}
	var cache proxyLookupCache
	providers := map[string]P.ProxyProvider{"source": p}
	cache.lookup("a", nil, providers)
	cache.lookup("a", nil, providers)
	if p.reads != 2 || len(cache.entries) != 0 {
		t.Fatal("racing version cached")
	}
}

func TestMissingDelayProxyKeepsIdentity(t *testing.T) {
	for _, url := range []string{"", "https://example.com/204"} {
		input, _ := json.Marshal(TestDelayParams{ProxyName: "__missing_test_proxy__", TestUrl: url, Timeout: 100})
		replies := make(chan string, 2)
		handleAsyncTestDelay(string(input), func(value string) { replies <- value })
		select {
		case response := <-replies:
			var delay Delay
			if err := json.Unmarshal([]byte(response), &delay); err != nil {
				t.Fatal(err)
			}
			if url == "" {
				url = "https://www.gstatic.com/generate_204"
			}
			if delay.Url != url || delay.Name != "__missing_test_proxy__" || delay.Value != -1 {
				t.Fatalf("bad response: %+v", delay)
			}
		case <-time.After(time.Second):
			t.Fatal("missing proxy did not finish")
		}
	}
}
