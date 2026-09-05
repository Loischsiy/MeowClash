package main

import (
	"runtime/debug"
	"sync/atomic"
)

// Keep the existing heap budget, but let Go's GC/scavenger respond to actual
// allocations instead of forcing two collections every two minutes while idle.
// This is a soft limit on Go-managed memory, not a cap on process RSS, Flutter,
// native allocations, or the size of a live proxy configuration.
func init() {
	debug.SetGCPercent(50)
	debug.SetMemoryLimit(192 << 20)
}

// OS memory-pressure callbacks and manual requests can arrive together. One
// outstanding reclaim is enough; do not queue a burst of full collections.
// FreeOSMemory already runs GC, so callers must not run runtime.GC first.
type memoryReclaimGate struct {
	active atomic.Bool
}

func (g *memoryReclaimGate) request(reclaim func()) {
	if !g.active.CompareAndSwap(false, true) {
		return
	}
	go func() {
		defer g.active.Store(false)
		reclaim()
	}()
}

var memoryReclaims memoryReclaimGate
