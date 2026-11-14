package main

import (
	"core/constant"
	"os"
	"regexp"
	"testing"
)

// The UI and the core's own version come from constant.Version, so a mihomo
// bump that only edits go.mod (e.g. a new replace target) leaves both stale.
func TestCoreVersionMatchesGoMod(t *testing.T) {
	data, err := os.ReadFile("go.mod")
	if err != nil {
		t.Fatal(err)
	}
	mod := string(data)
	want := ""
	if m := regexp.MustCompile(`(?m)^\s*(?:replace\s+)?github\.com/metacubex/mihomo\s*=>\s*\S+\s+(\S+)`).FindStringSubmatch(mod); m != nil {
		want = m[1]
	} else if m := regexp.MustCompile(`(?m)^\s*(?:require\s+)?github\.com/metacubex/mihomo\s+(v\S+)`).FindStringSubmatch(mod); m != nil {
		want = m[1]
	}
	if want == "" {
		t.Fatal("github.com/metacubex/mihomo not found in go.mod")
	}
	if constant.Version != want {
		t.Fatalf("core/constant/version.go has %q, go.mod builds mihomo %q", constant.Version, want)
	}
}
