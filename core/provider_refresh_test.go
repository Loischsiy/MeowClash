package main

import (
	"bytes"
	"encoding/base64"
	"strings"
	"testing"
)

func TestProviderPayloadPreservesBinaryAndLegacyText(t *testing.T) {
	binary := []byte{'M', 'R', 'S', 0, 255, 128, 1, 0}
	for _, original := range [][]byte{binary, []byte("payload:\n - DOMAIN,example.org\n")} {
		result, err := decodeProviderPayload(map[string]string{"dataBase64": base64.StdEncoding.EncodeToString(original)})
		if err != nil || !bytes.Equal(result, original) {
			t.Fatalf("payload changed: %v %v", result, err)
		}
	}
	legacy, err := decodeProviderPayload(map[string]string{"data": "payload: []"})
	if err != nil || string(legacy) != "payload: []" {
		t.Fatalf("legacy caller broken: %s %v", legacy, err)
	}
}

func TestProviderPayloadRejectsInvalidAmbiguousAndOversizedData(t *testing.T) {
	for _, params := range []map[string]string{
		{"dataBase64": "not-base64"},
		{"dataBase64": "", "data": ""},
		{"data": strings.Repeat("x", maxProviderPayloadBytes+1)},
		{"dataBase64": strings.Repeat("x", base64.StdEncoding.EncodedLen(maxProviderPayloadBytes)+1)},
	} {
		if _, err := decodeProviderPayload(params); err == nil {
			t.Fatal("invalid payload was accepted")
		}
	}
}

func TestProviderTargetRequiresNamespaceAndActiveProfilePath(t *testing.T) {
	info := &ExternalProvider{Name: "shared", Type: "Rule", Path: "/profiles/B/rules/list"}
	for _, tc := range []struct {
		name, kind, path string
		want             bool
	}{
		{"shared", "Rule", "/profiles/B/rules/list", true},
		{"shared", "Proxy", "/profiles/B/rules/list", false},
		{"shared", "Rule", "/profiles/A/rules/list", false},
		{"other", "Rule", "/profiles/B/rules/list", false},
		{"shared", "Rule", "", false},
	} {
		if got := providerTargetMatches(info, tc.name, tc.kind, tc.path); got != tc.want {
			t.Errorf("target %+v: got %v", tc, got)
		}
	}
}
