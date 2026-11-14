package main

import (
	"sync"
	"time"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

// networkRecheckDelay coalesces the burst of callbacks Android sends while a
// network comes up (available, link properties, idle-mode exit).
const networkRecheckDelay = 3 * time.Second

var networkRecheck struct {
	sync.Mutex
	timer *time.Timer
}

// scheduleNetworkRecheck re-runs health checks once the network settles.
// While the phone sleeps, health checks run without a usable network (Doze,
// Wi-Fi power save, stale DNS) and mark every node dead; a url-test group then
// falls back to its first proxy and fallback groups stay on a dead node until
// the next interval, so traffic stops after unlocking.
func scheduleNetworkRecheck() {
	networkRecheck.Lock()
	defer networkRecheck.Unlock()
	if networkRecheck.timer != nil {
		networkRecheck.timer.Stop()
	}
	networkRecheck.timer = time.AfterFunc(networkRecheckDelay, runNetworkRecheck)
}

func runNetworkRecheck() {
	runLock.Lock()
	ready := currentConfig != nil && isRunning
	runLock.Unlock()
	if !ready {
		return
	}
	providers := groupHealthCheckProviders()
	log.Infoln("[Network] network changed, rechecking %d providers", len(providers))
	for _, p := range providers {
		go p.HealthCheck()
	}
}

// groupHealthCheckProviders returns every proxy provider once: the configured
// proxy-providers plus the inline-proxy providers of each proxy group.
func groupHealthCheckProviders() []cp.ProxyProvider {
	seen := map[cp.ProxyProvider]struct{}{}
	var result []cp.ProxyProvider
	add := func(p cp.ProxyProvider) {
		if p == nil {
			return
		}
		if _, ok := seen[p]; ok {
			return
		}
		seen[p] = struct{}{}
		result = append(result, p)
	}
	for _, p := range tunnel.Providers() {
		add(p)
	}
	for _, proxy := range tunnel.Proxies() {
		group, ok := proxy.Adapter().(outboundgroup.ProxyGroup)
		if !ok {
			continue
		}
		for _, p := range group.Providers() {
			add(p)
		}
	}
	return result
}
