package main

import "testing"

func TestNetworkRecheckIsANoOpOnAStoppedCore(t *testing.T) {
	savedRunning := isRunning
	t.Cleanup(func() { isRunning = savedRunning })
	isRunning = false
	runNetworkRecheck()
	if got := groupHealthCheckProviders(); len(got) != 0 {
		t.Fatalf("an empty tunnel has no providers, got %d", len(got))
	}
}

func TestNetworkRecheckCoalescesBursts(t *testing.T) {
	scheduleNetworkRecheck()
	first := networkRecheck.timer
	scheduleNetworkRecheck()
	networkRecheck.Lock()
	second := networkRecheck.timer
	networkRecheck.Unlock()
	if first == second {
		t.Fatal("a new callback must restart the delay")
	}
	if first.Stop() {
		t.Fatal("the earlier timer must already be stopped")
	}
	second.Stop()
}
