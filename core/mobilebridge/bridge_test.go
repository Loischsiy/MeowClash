package mobilebridge

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

func TestBrokerReplyAndLateReply(t *testing.T) {
	b := NewBroker(1)
	var id int64
	result, err := b.Call(context.Background(), func(port int64) {
		id = port
		b.Reply(port, []byte("ok"))
	})
	if err != nil || string(result) != "ok" {
		t.Fatalf("%s %v", result, err)
	}
	b.Reply(id, []byte("late"))
	result, err = b.Call(context.Background(), func(port int64) { b.Reply(port, []byte("next")) })
	if err != nil || string(result) != "next" {
		t.Fatalf("%s %v", result, err)
	}
}

func TestBrokerTimeoutDoesNotLeakSlot(t *testing.T) {
	b := NewBroker(1)
	ctx, cancel := context.WithTimeout(context.Background(), time.Millisecond)
	defer cancel()
	_, err := b.Call(ctx, func(int64) {})
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal(err)
	}
	data, err := b.Call(context.Background(), func(id int64) { b.Reply(id, []byte("ok")) })
	if err != nil || string(data) != "ok" {
		t.Fatalf("%s %v", data, err)
	}
}

func TestBrokerBoundsPendingRequests(t *testing.T) {
	b := NewBroker(1)
	entered, release, done := make(chan struct{}), make(chan struct{}), make(chan struct{})
	go func() {
		defer close(done)
		_, _ = b.Call(context.Background(), func(id int64) {
			close(entered)
			<-release
			b.Reply(id, nil)
		})
	}()
	<-entered
	_, err := b.Call(context.Background(), func(int64) { t.Error("must not dispatch") })
	if !errors.Is(err, ErrBusy) {
		t.Fatal(err)
	}
	close(release)
	<-done
}

func TestEventQueueBoundsAndOwnership(t *testing.T) {
	q := NewEventQueue(2, 6)
	input := []byte("one")
	q.Push(input)
	input[0] = 'X'
	q.Push([]byte("two"))
	q.Push([]byte("three"))
	q.Push([]byte("too large"))
	got := q.Drain()
	if len(got) != 1 || string(got[0]) != "three" {
		t.Fatalf("%q", got)
	}
	if len(q.Drain()) != 0 {
		t.Fatal("drain did not clear queue")
	}
	q.Push([]byte("new"))
	if string(got[0]) != "three" {
		t.Fatal("drained memory was reused")
	}
}

func TestEventQueueConcurrent(t *testing.T) {
	q := NewEventQueue(8, 64)
	var wg sync.WaitGroup
	for i := 0; i < 20; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 50; j++ {
				q.Push([]byte("event"))
				q.Drain()
			}
		}()
	}
	wg.Wait()
}
