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

func TestManualDelayDefaultLimit(t *testing.T) {
	if defaultDelayConcurrency != 10 {
		t.Fatalf("default manual delay limit=%d; want 10", defaultDelayConcurrency)
	}
	if limiter := newDelayLimiter(-5); limiter.limit != 0 {
		t.Fatalf("negative limit=%d; want 0 (unlimited)", limiter.limit)
	}
}

func measureDelayLimiter(t *testing.T, limiter *delayLimiter, workers int) int32 {
	t.Helper()
	var active, maximum atomic.Int32
	var group sync.WaitGroup
	start := make(chan struct{})
	for i := 0; i < workers; i++ {
		group.Add(1)
		go func() {
			defer group.Done()
			<-start
			if !limiter.acquire(context.Background()) {
				t.Error("acquire failed")
				return
			}
			n := active.Add(1)
			for old := maximum.Load(); n > old && !maximum.CompareAndSwap(old, n); old = maximum.Load() {
			}
			time.Sleep(5 * time.Millisecond)
			active.Add(-1)
			limiter.release()
		}()
	}
	close(start)
	group.Wait()
	if limiter.active != 0 {
		t.Fatalf("leaked %d slots", limiter.active)
	}
	return maximum.Load()
}

func TestDelayLimiterBoundsConcurrency(t *testing.T) {
	if maximum := measureDelayLimiter(t, newDelayLimiter(10), 100); maximum > 10 {
		t.Fatalf("max=%d; want <= 10", maximum)
	}
}

func TestDelayLimiterUnlimited(t *testing.T) {
	if maximum := measureDelayLimiter(t, newDelayLimiter(0), 50); maximum <= 10 {
		t.Fatalf("max=%d; unlimited limiter still capped", maximum)
	}
}

func TestDelayLimiterRaiseWakesQueuedTasks(t *testing.T) {
	limiter := newDelayLimiter(1)
	if !limiter.acquire(context.Background()) {
		t.Fatal("first acquire failed")
	}
	acquired := make(chan bool, 1)
	go func() { acquired <- limiter.acquire(context.Background()) }()
	select {
	case <-acquired:
		t.Fatal("second task passed a full limiter")
	case <-time.After(10 * time.Millisecond):
	}
	limiter.setLimit(2)
	select {
	case ok := <-acquired:
		if !ok {
			t.Fatal("queued task failed after raise")
		}
	case <-time.After(time.Second):
		t.Fatal("raising the limit did not wake the queued task")
	}
	limiter.release()
	limiter.release()
}

func TestDelayQueueHonorsDeadline(t *testing.T) {
	limiter := newDelayLimiter(1)
	if !limiter.acquire(context.Background()) {
		t.Fatal("first acquire failed")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
	defer cancel()
	if limiter.acquire(ctx) {
		t.Fatal("expired queued task acquired slot")
	}
	limiter.release()
	if limiter.acquire(ctx) {
		t.Fatal("already expired task acquired a free slot")
	}
	if limiter.active != 0 {
		t.Fatalf("leaked %d slots", limiter.active)
	}
}

func TestDelayParamsConcurrencyIsOptional(t *testing.T) {
	var absent, unlimited TestDelayParams
	if err := json.Unmarshal([]byte(`{"proxy-name":"a"}`), &absent); err != nil || absent.Concurrency != nil {
		t.Fatalf("absent concurrency: %v %v", err, absent.Concurrency)
	}
	if err := json.Unmarshal([]byte(`{"proxy-name":"a","concurrency":0}`), &unlimited); err != nil ||
		unlimited.Concurrency == nil || *unlimited.Concurrency != 0 {
		t.Fatalf("explicit unlimited: %v %v", err, unlimited.Concurrency)
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
