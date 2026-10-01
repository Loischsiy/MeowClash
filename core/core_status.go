package main

import (
	"encoding/json"
	"runtime"
	"strings"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

// coreMemory derives the resident Go memory split shown by the core status
// dialog. reclaimable is heap the runtime still holds but has not returned to
// the OS yet; physical approximates Go-owned resident memory (not process RSS).
func coreMemory(m *runtime.MemStats) (physical, inUse, reclaimable uint64) {
	if m.HeapIdle > m.HeapReleased {
		reclaimable = m.HeapIdle - m.HeapReleased
	}
	inUse = m.HeapInuse + m.StackInuse
	return inUse + reclaimable, inUse, reclaimable
}

// geodataUse reports which geo databases the active rules reference.
// Only rules are inspected; DNS policy and sniffer geosite entries are not.
func geodataUse(rules []constant.Rule) string {
	var hasMMDB, hasSite, hasASN bool
	for _, r := range rules {
		if r == nil {
			continue
		}
		switch r.RuleType() {
		case constant.GEOIP, constant.SrcGEOIP:
			hasMMDB = true
		case constant.GEOSITE:
			hasSite = true
		case constant.IPASN, constant.SrcIPASN:
			hasASN = true
		case constant.AND, constant.OR, constant.NOT, constant.SubRules:
			payload := strings.ToUpper(r.Payload())
			if strings.Contains(payload, "(GEOIP,") || strings.Contains(payload, "(SRCGEOIP,") {
				hasMMDB = true
			}
			if strings.Contains(payload, "(GEOSITE,") {
				hasSite = true
			}
			if strings.Contains(payload, "(IPASN,") || strings.Contains(payload, "(SRCIPASN,") {
				hasASN = true
			}
		}
		if hasMMDB && hasSite && hasASN {
			break
		}
	}
	var used []string
	if hasMMDB {
		used = append(used, "MMDB")
	}
	if hasSite {
		used = append(used, "Site")
	}
	if hasASN {
		used = append(used, "ASN")
	}
	if len(used) == 0 {
		return "None"
	}
	return strings.Join(used, ", ")
}

func isBuiltinProxyType(t constant.AdapterType) bool {
	switch t {
	case constant.Direct, constant.Reject, constant.RejectDrop, constant.Compatible,
		constant.Pass, constant.PassRule, constant.Rematch, constant.Dns:
		return true
	}
	return false
}

// Ported from Bettbox's getCoreStatus. ReadMemStats briefly stops the world, so
// the UI polls this only while the core status dialog is open.
func handleGetCoreStatus(fn func(value string)) {
	go func() {
		var m runtime.MemStats
		runtime.ReadMemStats(&m)
		physical, inUse, reclaimable := coreMemory(&m)

		proxyGroups := 0
		proxyNames := make(map[string]struct{})
		for _, p := range tunnel.Proxies() {
			if p == nil {
				continue
			}
			if _, ok := p.Adapter().(outboundgroup.ProxyGroup); ok {
				proxyGroups++
				continue
			}
			if !isBuiltinProxyType(p.Type()) {
				proxyNames[p.Name()] = struct{}{}
			}
		}
		proxyProviders := 0
		for name, pr := range tunnel.Providers() {
			if pr == nil || name == "default" || pr.VehicleType() == cp.Compatible {
				continue
			}
			proxyProviders++
			for _, p := range pr.Proxies() {
				if p != nil {
					proxyNames[p.Name()] = struct{}{}
				}
			}
		}

		rules := tunnel.Rules()
		status := map[string]any{
			"physical":        physical,
			"in-use":          inUse,
			"reclaimable":     reclaimable,
			"sys":             m.Sys,
			"goroutines":      runtime.NumGoroutine(),
			"heap-objects":    m.HeapObjects,
			"last-gc":         m.LastGC / 1000000,
			"rules":           len(rules),
			"proxies":         len(proxyNames),
			"proxy-groups":    proxyGroups,
			"rule-providers":  len(tunnel.RuleProviders()),
			"proxy-providers": proxyProviders,
			"geodata-use":     geodataUse(rules),
		}
		bytes, _ := json.Marshal(status)
		fn(string(bytes))
	}()
}
