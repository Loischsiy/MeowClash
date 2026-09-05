package main

import (
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func waitForReclaim(t *testing.T, gate *memoryReclaimGate) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for gate.active.Load() {
		if time.Now().After(deadline) {
			t.Fatal("memory reclaim gate did not release")
		}
		time.Sleep(time.Millisecond)
	}
}

func TestMemoryReclaimCoalescesConcurrentPressure(t *testing.T) {
	var gate memoryReclaimGate
	var calls atomic.Int32
	started := make(chan struct{})
	release := make(chan struct{})
	defer func() { close(release); waitForReclaim(t, &gate) }()
	reclaim := func() {
		if calls.Add(1) == 1 {
			close(started)
		}
		<-release
	}
	var requests sync.WaitGroup
	for i := 0; i < 256; i++ {
		requests.Add(1)
		go func() {
			defer requests.Done()
			gate.request(reclaim)
		}()
	}
	requests.Wait()
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("reclaim did not start")
	}
	if got := calls.Load(); got != 1 {
		t.Fatalf("got %d collections, want one", got)
	}
}

func TestMemoryReclaimCanRunAgainAfterCompletion(t *testing.T) {
	var gate memoryReclaimGate
	for i := 0; i < 3; i++ {
		done := make(chan struct{})
		gate.request(func() { close(done) })
		select {
		case <-done:
		case <-time.After(time.Second):
			t.Fatal("later reclaim was lost")
		}
		waitForReclaim(t, &gate)
	}
}

func TestMemoryReclaimDoesNotQueueReentrantRequests(t *testing.T) {
	var gate memoryReclaimGate
	var nested atomic.Bool
	done := make(chan struct{})
	gate.request(func() {
		gate.request(func() { nested.Store(true) })
		close(done)
	})
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("reentrant request blocked")
	}
	waitForReclaim(t, &gate)
	if nested.Load() {
		t.Fatal("queued a redundant nested reclaim")
	}
}
