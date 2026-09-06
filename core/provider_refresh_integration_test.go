package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/tunnel"
)

// Real mihomo providers, isolated caches and loopback-only endpoints. No app,
// user profile, listener, TUN device or external subscription is started.
func TestProviderRefreshAppliesToLiveProxyAndRuleNamespaces(t *testing.T) {
	home := t.TempDir()
	previousHome := constant.Path.HomeDir()
	constant.SetHomeDir(home)
	t.Cleanup(func() { constant.SetHomeDir(previousHome) })
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	}))
	defer server.Close()
	proxyPath := filepath.Join(home, "proxies.yaml")
	rulePath := filepath.Join(home, "rules.yaml")
	for path, text := range map[string]string{
		proxyPath: "proxies:\n  - {name: original-proxy, type: direct}\n",
		rulePath:  "payload:\n  - example.org\n",
	} {
		if err := os.WriteFile(path, []byte(text), 0600); err != nil {
			t.Fatal(err)
		}
	}
	yaml := fmt.Sprintf(`mixed-port: 0
allow-lan: false
external-controller: ""
geodata-mode: false
geo-auto-update: false
dns:
  enable: false
tun:
  enable: false
proxy-providers:
  shared:
    type: http
    url: %q
    path: %q
    interval: 0
    health-check:
      enable: false
      url: %q
      interval: 0
rule-providers:
  shared:
    type: http
    behavior: domain
    format: yaml
    url: %q
    path: %q
    interval: 0
proxy-groups:
  - name: fixture-group
    type: select
    use: [shared]
rules:
  - RULE-SET,shared,DIRECT
  - MATCH,DIRECT
`, server.URL+"/proxies", proxyPath, server.URL+"/health", server.URL+"/rules", rulePath)
	raw, err := config.UnmarshalRawConfig([]byte(yaml))
	if err != nil {
		t.Fatal(err)
	}
	parsed, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatal(err)
	}
	executor.ApplyConfig(parsed, false)
	t.Cleanup(executor.Shutdown)

	proxyParams := map[string]string{"providerName": "shared", "providerType": "Proxy", "expectedPath": proxyPath}
	ruleParams := map[string]string{"providerName": "shared", "providerType": "Rule", "expectedPath": rulePath}
	if err := applyProviderRefresh(proxyParams, []byte("proxies:\n  - {name: updated-proxy, type: direct}\n")); err != nil {
		t.Fatal(err)
	}
	if got := tunnel.Providers()["shared"].Proxies()[0].Name(); got != "updated-proxy" {
		t.Fatalf("proxy refresh did not reach live provider: %s", got)
	}
	group, err := json.Marshal(tunnel.Proxies()["fixture-group"])
	if err != nil || !bytes.Contains(group, []byte("updated-proxy")) {
		t.Fatalf("group did not pick up provider update: %s %v", group, err)
	}
	if err := applyProviderRefresh(ruleParams, []byte("payload:\n  - example.net\n  - example.com\n")); err != nil {
		t.Fatal(err)
	}
	if got := tunnel.RuleProviders()["shared"].Count(); got != 2 {
		t.Fatalf("rule refresh did not reach live provider: %d", got)
	}

	for _, params := range []map[string]string{proxyParams, ruleParams} {
		path := params["expectedPath"]
		before, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if err := applyProviderRefresh(params, []byte("[broken yaml")); err == nil {
			t.Fatalf("invalid %s provider data accepted", params["providerType"])
		}
		after, err := os.ReadFile(path)
		if err != nil || !bytes.Equal(before, after) {
			t.Fatalf("rejected provider data damaged cache: %v", err)
		}
	}
	stale := map[string]string{"providerName": "shared", "providerType": "Rule", "expectedPath": filepath.Join(home, "another-profile", "rules.yaml")}
	if err := applyProviderRefresh(stale, []byte("payload:\n  - stale.example\n")); err == nil {
		t.Fatal("stale profile path accepted")
	}
	if got := tunnel.RuleProviders()["shared"].Count(); got != 2 {
		t.Fatalf("rejected payload changed live rules: %d", got)
	}
}
