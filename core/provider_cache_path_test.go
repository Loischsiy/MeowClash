package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

const providerCacheGolden = "../test/fixtures/provider_cache_paths.json"

var providerCacheGoldenURLs = []string{
	"https://example.com/sub",
	"https://example.com/sub?token=abc&x=1",
	"http://127.0.0.1:8080/provider.yaml",
	"https://пример.рф/подписка",
	"https://example.com/a b?q=1#frag",
}

type providerCacheGoldenEntry struct {
	Kind string `json:"kind"`
	URL  string `json:"url"`
	// Path relative to the core home directory, slash separated.
	Path string `json:"path"`
}

func initProviderCacheHome(t *testing.T) string {
	t.Helper()
	home := t.TempDir()
	prevInit := isInit
	prevHome := C.Path.HomeDir()
	C.SetHomeDir(home)
	isInit = true
	t.Cleanup(func() {
		isInit = prevInit
		C.SetHomeDir(prevHome)
	})
	return home
}

// Run with UPDATE_GOLDEN=1 to regenerate test/fixtures/provider_cache_paths.json,
// which the Dart FFI parity test compares against.
func TestProviderCachePathGolden(t *testing.T) {
	home := initProviderCacheHome(t)
	var got []providerCacheGoldenEntry
	for _, kind := range []string{"proxies", "rules"} {
		for _, url := range providerCacheGoldenURLs {
			path, err := getProviderCachePath(kind, url)
			if err != nil {
				t.Fatalf("%s %s: %v", kind, url, err)
			}
			if want := C.Path.GetPathByHash(kind, url); path != want {
				t.Fatalf("not built by GetPathByHash: %s != %s", path, want)
			}
			rel, err := filepath.Rel(home, path)
			if err != nil {
				t.Fatal(err)
			}
			got = append(got, providerCacheGoldenEntry{kind, url, filepath.ToSlash(rel)})
		}
	}
	encoded, err := json.MarshalIndent(got, "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	encoded = append(encoded, '\n')
	if os.Getenv("UPDATE_GOLDEN") == "1" {
		if err := os.WriteFile(providerCacheGolden, encoded, 0o644); err != nil {
			t.Fatal(err)
		}
		return
	}
	want, err := os.ReadFile(providerCacheGolden)
	if err != nil {
		t.Fatalf("golden missing (run with UPDATE_GOLDEN=1): %v", err)
	}
	if string(want) != string(encoded) {
		t.Fatalf("golden mismatch, regenerate with UPDATE_GOLDEN=1\nwant:\n%s\ngot:\n%s", want, encoded)
	}
}

func TestProviderCachePathRejectsBadInput(t *testing.T) {
	initProviderCacheHome(t)
	for _, c := range [][2]string{{"other", "https://x"}, {"proxies", ""}, {"", "https://x"}} {
		if _, err := getProviderCachePath(c[0], c[1]); err == nil {
			t.Fatalf("expected error for %v", c)
		}
	}
}

func TestProviderCachePathRequiresInit(t *testing.T) {
	prev := isInit
	isInit = false
	defer func() { isInit = prev }()
	if _, err := getProviderCachePath("proxies", "https://x"); err == nil {
		t.Fatal("expected not-initialized error")
	}
}
