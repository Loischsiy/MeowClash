package main

import (
	"encoding/base64"
	"strings"
	"testing"
)

func TestNormalizeSubscription_PlainText(t *testing.T) {
	// Plain text list of share-link URIs. SS has a simple, fully
	// supported parser in mihomo's convert package so we use it to
	// exercise the plain-text branch.
	input := []byte("ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@example.com:8388#SSNode\n")
	out := normalizeSubscription(input)
	s := string(out)
	if !strings.Contains(s, "proxies:") {
		t.Fatalf("expected proxies section in YAML, got:\n%s", s)
	}
	if !strings.Contains(s, "proxy-groups:") {
		t.Fatalf("expected proxy-groups section in YAML, got:\n%s", s)
	}
	if !strings.Contains(s, "rules:") {
		t.Fatalf("expected rules section in YAML, got:\n%s", s)
	}
	if !strings.Contains(s, "SSNode") {
		t.Fatalf("expected SSNode name in YAML, got:\n%s", s)
	}
}

func TestNormalizeSubscription_Base64SS(t *testing.T) {
	// Same SS URI but the whole subscription base64-encoded -- mirrors
	// the user-reported scenario where the server returns base64.
	plain := "ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ=@example.com:8388#SSNode\n"
	input := []byte(base64.StdEncoding.EncodeToString([]byte(plain)))
	out := normalizeSubscription(input)
	s := string(out)
	if !strings.Contains(s, "SSNode") {
		t.Fatalf("expected base64-decoded SSNode name in YAML, got:\n%s", s)
	}
	if !strings.Contains(s, "proxy-groups:") {
		t.Fatalf("expected proxy-groups section, got:\n%s", s)
	}
}

func TestNormalizeSubscription_Base64Vmess(t *testing.T) {
	// VMess share-link is itself a base64-encoded JSON blob inside a
	// vmess:// scheme; here we wrap a list of vmess URIs in another
	// layer of base64 to mirror the standard v2rayN-style subscription
	// response.
	plain := "vmess://eyJhZGQiOiJleGFtcGxlLmNvbSIsImFpZCI6IjAiLCJob3N0IjoiIiwiaWQiOiJjMjMzMTk2NS01M2NkLTQ0YzAtOTM1ZS0xZjA2Y2I3M2I3MzIiLCJuZXQiOiJ3cyIsInBhdGgiOiIvIiwicG9ydCI6IjQ0MyIsInBzIjoiVmlubmV0IiwidGxzIjoidGxzIiwidHlwZSI6IiIsInYiOiIyIn0=\n"
	input := []byte(base64.StdEncoding.EncodeToString([]byte(plain)))
	out := normalizeSubscription(input)
	s := string(out)
	if !strings.Contains(s, "Vinnet") {
		t.Fatalf("expected Vinnet (vmess ps field) in YAML, got:\n%s", s)
	}
}

func TestNormalizeSubscription_ValidYAML_PassesThrough(t *testing.T) {
	// A trivial but valid clash YAML must be returned unchanged.
	input := []byte("proxies:\n  - name: \"Foo\"\n    type: ss\n    server: example.com\n    port: 8388\n    cipher: aes-256-gcm\n    password: pw\nproxy-groups:\n  - name: PROXY\n    type: select\n    proxies: [DIRECT, Foo]\nrules:\n  - MATCH,PROXY\n")
	out := normalizeSubscription(input)
	if string(out) != string(input) {
		t.Fatalf("expected pass-through for valid YAML; got different output:\nIN:\n%s\nOUT:\n%s", input, out)
	}
}

func TestNormalizeSubscription_Garbage_ReturnsOriginal(t *testing.T) {
	// Something that is neither a valid YAML clash config nor a
	// recognisable subscription -- the original bytes should come back so
	// downstream validateConfig surfaces a meaningful error.
	input := []byte("just some plain text that is not a profile")
	out := normalizeSubscription(input)
	if string(out) != string(input) {
		t.Fatalf("expected original bytes back for unrecognised input")
	}
}
