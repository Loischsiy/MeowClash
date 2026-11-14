package main

import (
	"testing"

	"github.com/metacubex/mihomo/config"
)

const fingerprintProfile = `
mixed-port: 7890
proxies:
  - {name: a, type: ss, server: 1.1.1.1, port: 443, cipher: aes-128-gcm, password: p}
  - {name: b, type: ss, server: 2.2.2.2, port: 443, cipher: aes-128-gcm, password: p}
proxy-providers:
  remote:
    type: http
    url: https://example.com/sub
    interval: 3600
    health-check: {enable: true, url: https://www.gstatic.com/generate_204, interval: 300}
proxy-groups:
  - {name: auto, type: url-test, proxies: [a, b], url: https://www.gstatic.com/generate_204, interval: 300}
  - {name: select, type: select, proxies: [auto, a, b], use: [remote]}
rules:
  - MATCH,select
`

func fingerprintParams(t *testing.T, profile string, testURL string) *SetupParams {
	t.Helper()
	raw, err := config.UnmarshalRawConfig([]byte(profile))
	if err != nil {
		t.Fatalf("parse profile: %v", err)
	}
	return &SetupParams{Config: raw, TestURL: testURL, SelectedMap: map[string]string{}}
}

func TestSetupFingerprintIsStableAndSensitive(t *testing.T) {
	url := "https://www.gstatic.com/generate_204"
	first := setupFingerprint(fingerprintParams(t, fingerprintProfile, url))
	if first == "" {
		t.Fatal("a real profile must produce a fingerprint")
	}
	if again := setupFingerprint(fingerprintParams(t, fingerprintProfile, url)); again != first {
		t.Fatal("the same profile must produce the same fingerprint")
	}
	if other := setupFingerprint(fingerprintParams(t, fingerprintProfile, "https://cp.cloudflare.com")); other == first {
		t.Fatal("a different test URL must change the fingerprint")
	}
	changed := fingerprintParams(t, fingerprintProfile, url)
	changed.Config.Proxy = changed.Config.Proxy[:1]
	if setupFingerprint(changed) == first {
		t.Fatal("a different proxy list must change the fingerprint")
	}
	selected := fingerprintParams(t, fingerprintProfile, url)
	selected.SelectedMap = map[string]string{"select": "b"}
	if setupFingerprint(selected) != first {
		t.Fatal("the selection must not force a rebuild of the live core")
	}
	if setupFingerprint(nil) != "" || setupFingerprint(&SetupParams{}) != "" {
		t.Fatal("missing config must never match")
	}
}

func TestCanSkipSetupOnlyForTheAppliedConfigOnARunningCore(t *testing.T) {
	savedRunning, savedConfig := isRunning, currentConfig
	t.Cleanup(func() {
		isRunning, currentConfig = savedRunning, savedConfig
		invalidateAppliedSetup()
	})
	fingerprint := setupFingerprint(fingerprintParams(t, fingerprintProfile, ""))
	currentConfig = &config.Config{}
	rememberAppliedSetup(fingerprint)

	isRunning = false
	if canSkipSetup(fingerprint) {
		t.Fatal("a stopped core must reread provider caches with a full setup")
	}
	isRunning = true
	if !canSkipSetup(fingerprint) {
		t.Fatal("the same config on a running core must be kept")
	}
	if canSkipSetup("other") || canSkipSetup("") {
		t.Fatal("a different config must be applied")
	}
	invalidateAppliedSetup()
	if canSkipSetup(fingerprint) {
		t.Fatal("an invalidated setup must be applied again")
	}
	rememberAppliedSetup(fingerprint)
	currentConfig = nil
	if canSkipSetup(fingerprint) {
		t.Fatal("a core without config must be set up")
	}
}

func TestStateChangeInvalidatesAppliedSetup(t *testing.T) {
	t.Cleanup(invalidateAppliedSetup)
	rememberAppliedSetup("x")
	handleSetState(`{}`)
	if appliedSetupFingerprint() != "" {
		t.Fatal("a state change must force the next setup")
	}
}
