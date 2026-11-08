package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/metacubex/mihomo/config"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/tunnel"
)

// hitCounter is the URL of every external provider below: the core must never
// call it, whatever it does with the cache.
func hitCounter(t *testing.T) (*httptest.Server, *int32) {
	t.Helper()
	var hits int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		atomic.AddInt32(&hits, 1)
		w.WriteHeader(http.StatusNoContent)
	}))
	t.Cleanup(server.Close)
	return server, &hits
}

func externalConfig(proxyURL, ruleURL string) string {
	return fmt.Sprintf(`mixed-port: 0
allow-lan: false
external-controller: ""
geodata-mode: false
geo-auto-update: false
dns:
  enable: false
tun:
  enable: false
proxy-providers:
  ext:
    type: http
    url: %q
    interval: 1
    meowclash-external: true
    health-check:
      enable: false
      url: %q
      interval: 0
rule-providers:
  ext:
    type: http
    behavior: domain
    format: yaml
    url: %q
    interval: 1
    meowclash-external: true
proxy-groups:
  - name: g
    type: select
    use: [ext]
rules:
  - RULE-SET,ext,DIRECT
  - MATCH,DIRECT
`, proxyURL, proxyURL+"/hc", ruleURL)
}

func writeCache(t *testing.T, kind, url, text string) string {
	t.Helper()
	path, err := getProviderCachePath(kind, url)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(text), 0o600); err != nil {
		t.Fatal(err)
	}
	return path
}

// Parity end to end: a file written to the path the FFI reports is exactly the
// one a `meowclash-external` provider (no explicit path) reads, and the core
// does not touch the network to do it.
func TestExternalProviderReadsFFIPathWithoutNetwork(t *testing.T) {
	initProviderCacheHome(t)
	server, hits := hitCounter(t)
	proxyURL, ruleURL := server.URL+"/sub", server.URL+"/rules"
	proxyPath := writeCache(t, "proxies", proxyURL, "proxies:\n  - {name: node-a, type: direct}\n  - {name: node-b, type: direct}\n")
	writeCache(t, "rules", ruleURL, "payload:\n  - example.org\n")

	raw, err := config.UnmarshalRawConfig([]byte(externalConfig(proxyURL, ruleURL)))
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatalf("core refused a cached external provider: %v", err)
	}
	executor.ApplyConfig(parsed, false)
	t.Cleanup(executor.Shutdown)

	proxies := tunnel.Providers()["ext"]
	if proxies == nil || len(proxies.Proxies()) != 2 {
		t.Fatalf("nodes are not visible: %v", proxies)
	}
	if proxies.VehicleType() != cp.File {
		t.Fatalf("external provider must report vehicleType File, got %s", proxies.VehicleType())
	}
	if tunnel.RuleProviders()["ext"].Count() != 1 {
		t.Fatal("rules are not visible")
	}
	if got, _ := toExternalProvider(proxies); got == nil || filepath.Clean(got.Path) != filepath.Clean(proxyPath) || got.VehicleType != "File" {
		t.Fatalf("API model mismatch: %+v", got)
	}

	// vehicleType File must stay in the list the UI and refresh flow use.
	found := 0
	for _, p := range externalProviderCandidates() {
		if p.Name() == "ext" {
			found++
		}
	}
	if found != 2 {
		t.Fatalf("File providers missing from candidates: %d", found)
	}

	// Side-load keeps working with the path guard, and Update() only re-reads
	// the file.
	params := map[string]string{"providerName": "ext", "providerType": "Proxy", "expectedPath": proxyPath}
	if err := applyProviderRefresh(params, []byte("proxies:\n  - {name: node-c, type: direct}\n")); err != nil {
		t.Fatal(err)
	}
	if got := tunnel.Providers()["ext"].Proxies(); len(got) != 1 || got[0].Name() != "node-c" {
		t.Fatalf("side-load did not reach the live provider: %v", got)
	}
	if err := tunnel.Providers()["ext"].Update(); err != nil {
		t.Fatalf("re-reading the cache failed: %v", err)
	}
	if n := atomic.LoadInt32(hits); n != 0 {
		t.Fatalf("the core made %d network requests for external providers", n)
	}
}

// Missing cache is the documented contract: a clear error, never a fetch.
func TestExternalProviderWithoutCacheFailsWithoutNetwork(t *testing.T) {
	initProviderCacheHome(t)
	server, hits := hitCounter(t)
	raw, err := config.UnmarshalRawConfig([]byte(externalConfig(server.URL+"/sub", server.URL+"/rules")))
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatal(err)
	}
	for name, p := range map[string]cp.Provider{"proxy": parsed.Providers["ext"], "rule": parsed.RuleProviders["ext"]} {
		if p == nil {
			t.Fatalf("%s provider missing", name)
		}
		err := p.Initial()
		if err == nil || !strings.Contains(err.Error(), "external provider file not found") {
			t.Fatalf("%s: expected the external-provider contract error, got %v", name, err)
		}
	}
	if n := atomic.LoadInt32(hits); n != 0 {
		t.Fatalf("the core made %d network requests", n)
	}
}
