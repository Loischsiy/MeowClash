package main

import (
	"runtime"
	"runtime/debug"
	"time"
)

// init tunes the Go runtime to reduce idle RSS on memory-constrained devices
// (mobile). It runs once at process start so both CGO (mobile) and non-CGO
// (desktop) builds get the same memory profile.
func init() {
	// Lower GC target percentage trades a tiny bit of CPU for noticeably
	// smaller heap retention between collections.
	debug.SetGCPercent(50)

	// Soft memory limit lets the runtime aggressively return memory to the
	// OS when the resident set crosses this threshold. 192 MiB is generous
	// for a proxy core while staying well under typical mobile background
	// budgets that cause the OS to kill the app.
	debug.SetMemoryLimit(192 << 20)

	// Periodically nudge the runtime to release unused arenas back to the
	// OS. Without this, Go can hold on to memory long after the workload
	// shrinks (e.g. after subscription refresh), which is the main source
	// of "the app still uses N MB" complaints.
	go memoryReclaimer()
}

func memoryReclaimer() {
	ticker := time.NewTicker(2 * time.Minute)
	defer ticker.Stop()
	for range ticker.C {
		runtime.GC()
		debug.FreeOSMemory()
	}
}
