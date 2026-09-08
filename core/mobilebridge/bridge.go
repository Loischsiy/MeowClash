// Package mobilebridge contains the bounded, pointer-free transport used by
// the iOS C bridge. It is intentionally testable without an Apple SDK.
package mobilebridge

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
)

var ErrBusy = errors.New("too many pending core requests")

type Broker struct {
	sequence atomic.Int64
	pending  sync.Map
	slots    chan struct{}
}

func NewBroker(limit int) *Broker { return &Broker{slots: make(chan struct{}, limit)} }

func (b *Broker) Call(ctx context.Context, dispatch func(int64)) ([]byte, error) {
	select {
	case b.slots <- struct{}{}:
	default:
		return nil, ErrBusy
	}
	defer func() { <-b.slots }()
	id := b.sequence.Add(1)
	reply := make(chan []byte, 1)
	b.pending.Store(id, reply)
	defer b.pending.Delete(id)
	go dispatch(id)
	select {
	case data := <-reply:
		return data, nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

// A timed-out/duplicate reply is discarded, never sent to a recycled pointer.
func (b *Broker) Reply(id int64, data []byte) {
	if value, ok := b.pending.Load(id); ok {
		select {
		case value.(chan []byte) <- data:
		default:
		}
	}
}

type EventQueue struct {
	mu                        sync.Mutex
	items                     [][]byte
	bytes, maxItems, maxBytes int
}

func NewEventQueue(maxItems, maxBytes int) *EventQueue {
	return &EventQueue{maxItems: maxItems, maxBytes: maxBytes}
}

func (q *EventQueue) Push(data []byte) {
	q.mu.Lock()
	defer q.mu.Unlock()
	if len(data) > q.maxBytes || q.maxItems < 1 {
		return
	}
	for len(q.items) > 0 && (len(q.items) >= q.maxItems || q.bytes+len(data) > q.maxBytes) {
		q.bytes -= len(q.items[0])
		q.items[0] = nil
		q.items = q.items[1:]
	}
	q.items = append(q.items, append([]byte(nil), data...))
	q.bytes += len(data)
}

func (q *EventQueue) Drain() [][]byte {
	q.mu.Lock()
	defer q.mu.Unlock()
	items := q.items
	q.items = nil
	q.bytes = 0
	return items
}
