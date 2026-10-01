package main

import (
	"encoding/json"
	"runtime"
	"testing"
	"time"
)

func TestCoreMemorySplit(t *testing.T) {
	m := runtime.MemStats{HeapInuse: 10, StackInuse: 5, HeapIdle: 20, HeapReleased: 8}
	physical, inUse, reclaimable := coreMemory(&m)
	if inUse != 15 || reclaimable != 12 || physical != 27 {
		t.Fatalf("got physical=%d inUse=%d reclaimable=%d", physical, inUse, reclaimable)
	}
	m = runtime.MemStats{HeapInuse: 1, HeapIdle: 4, HeapReleased: 9}
	if physical, _, reclaimable = coreMemory(&m); reclaimable != 0 || physical != 1 {
		t.Fatalf("released > idle must not underflow: physical=%d reclaimable=%d", physical, reclaimable)
	}
}

func TestGeodataUseWithoutRules(t *testing.T) {
	if got := geodataUse(nil); got != "None" {
		t.Fatalf("geodataUse(nil) = %q", got)
	}
}

func TestHandleGetCoreStatusKeys(t *testing.T) {
	done := make(chan string, 1)
	handleGetCoreStatus(func(value string) { done <- value })
	var raw string
	select {
	case raw = <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("handleGetCoreStatus did not respond")
	}
	var status map[string]any
	if err := json.Unmarshal([]byte(raw), &status); err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{
		"physical", "in-use", "reclaimable", "sys", "goroutines", "heap-objects",
		"last-gc", "rules", "proxies", "proxy-groups", "rule-providers",
		"proxy-providers", "geodata-use",
	} {
		if _, ok := status[key]; !ok {
			t.Errorf("missing key %q in %s", key, raw)
		}
	}
}
