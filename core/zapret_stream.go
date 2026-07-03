package main

import (
	"context"
	"encoding/json"
	"net"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/buf"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

type zapret2StateT struct {
	mu         sync.RWMutex
	enabled    atomic.Bool
	strategy   string
	args       []string
	splitPos   []int
	hostFilter map[string]struct{}
}

var zapret2State = &zapret2StateT{hostFilter: map[string]struct{}{}}

func zapret2ShouldMutate() bool { return zapret2State.enabled.Load() }

func zapret2Apply(strategy string, args []string, hosts []string) bool {
	zapret2State.mu.Lock()
	defer zapret2State.mu.Unlock()
	zapret2State.strategy = strategy
	zapret2State.args = args
	zapret2State.splitPos = zapret2ParseSplitPositions(strategy, args)
	zapret2State.hostFilter = make(map[string]struct{}, len(hosts))
	for _, h := range hosts {
		zapret2State.hostFilter[strings.ToLower(strings.TrimSpace(h))] = struct{}{}
	}
	zapret2State.enabled.Store(strategy != "")
	zapret2InstallProxyWrappers()
	return zapret2State.enabled.Load()
}

func zapret2Clear() {
	zapret2State.mu.Lock()
	defer zapret2State.mu.Unlock()
	zapret2State.strategy = ""
	zapret2State.args = nil
	zapret2State.splitPos = nil
	zapret2State.hostFilter = map[string]struct{}{}
	zapret2State.enabled.Store(false)
}

func zapret2ApplyJSON(data string) bool {
	var payload struct {
		Strategy string   `json:"strategy"`
		Args     []string `json:"args"`
		Hosts    []string `json:"hosts"`
	}
	if err := json.Unmarshal([]byte(data), &payload); err != nil {
		return false
	}
	return zapret2Apply(payload.Strategy, payload.Args, payload.Hosts)
}

func zapret2InstallProxyWrappers() {
	if !zapret2ShouldMutate() {
		return
	}
	for _, proxy := range tunnel.Proxies() {
		zapret2WrapProxy(proxy)
	}
	for _, provider := range tunnel.Providers() {
		for _, proxy := range provider.Proxies() {
			zapret2WrapProxy(proxy)
		}
	}
}

func zapret2WrapProxy(proxy C.Proxy) {
	p, ok := proxy.(*adapter.Proxy)
	if !ok {
		return
	}
	if _, wrapped := p.ProxyAdapter.(*zapret2ProxyAdapter); wrapped {
		return
	}
	if _, group := p.ProxyAdapter.(outboundgroup.ProxyGroup); group {
		return
	}
	p.ProxyAdapter = &zapret2ProxyAdapter{ProxyAdapter: p.ProxyAdapter}
}

type zapret2ProxyAdapter struct {
	C.ProxyAdapter
}

func (p *zapret2ProxyAdapter) DialContext(ctx context.Context, metadata *C.Metadata) (C.Conn, error) {
	conn, err := p.ProxyAdapter.DialContext(ctx, metadata)
	if err != nil || !zapret2ShouldMutate() || !zapret2Matches(metadata) {
		return conn, err
	}
	return &zapret2Conn{Conn: conn}, nil
}

func zapret2Matches(metadata *C.Metadata) bool {
	host := strings.ToLower(metadata.Host)
	if host == "" {
		host = strings.ToLower(metadata.DstIP.String())
	}
	zapret2State.mu.RLock()
	defer zapret2State.mu.RUnlock()
	if len(zapret2State.hostFilter) == 0 {
		return true
	}
	_, ok := zapret2State.hostFilter[host]
	return ok
}

func zapret2CurrentSplitPos() []int {
	zapret2State.mu.RLock()
	defer zapret2State.mu.RUnlock()
	return append([]int(nil), zapret2State.splitPos...)
}

type zapret2Conn struct {
	C.Conn
	wroteFirst atomic.Bool
}

func (c *zapret2Conn) Write(p []byte) (int, error) {
	if c.wroteFirst.CompareAndSwap(false, true) && zapret2LooksLikeTLSClientHello(p) {
		if err := zapret2SplitWrite(c.Conn, p, zapret2CurrentSplitPos()); err != nil {
			return 0, err
		}
		return len(p), nil
	}
	return c.Conn.Write(p)
}

func (c *zapret2Conn) WriteBuffer(buffer *buf.Buffer) error {
	_, err := c.Write(buffer.Bytes())
	return err
}

func (c *zapret2Conn) Upstream() any {
	return c.Conn
}

func (c *zapret2Conn) WriterReplaceable() bool {
	return false
}

func zapret2LooksLikeTLSClientHello(p []byte) bool {
	return len(p) > 6 && p[0] == 0x16 && p[1] == 0x03 && p[5] == 0x01
}

func zapret2ParseSplitPositions(strategy string, args []string) []int {
	var positions []int
	for _, arg := range args {
		if value, ok := strings.CutPrefix(arg, "--dpi-desync-split-pos="); ok {
			positions = append(positions, zapret2ParsePosList(value)...)
		}
		if value, ok := strings.CutPrefix(arg, "--stream-split-pos="); ok {
			positions = append(positions, zapret2ParsePosList(value)...)
		}
	}
	if len(positions) > 0 {
		return positions
	}
	switch {
	case strings.Contains(strategy, "tlsrec"):
		return []int{5}
	case strings.Contains(strategy, "multisplit"):
		return []int{1, 5, 16}
	case strings.Contains(strategy, "split2"):
		return []int{1}
	case strings.Contains(strategy, "split_5"):
		return []int{5}
	case strings.Contains(strategy, "split_16"):
		return []int{16}
	case strings.Contains(strategy, "split_32"):
		return []int{32}
	default:
		return []int{1}
	}
}

func zapret2ParsePosList(value string) []int {
	var positions []int
	for _, part := range strings.Split(value, ",") {
		pos, err := strconv.Atoi(strings.TrimSpace(part))
		if err == nil {
			positions = append(positions, pos)
		}
	}
	return positions
}

func zapret2SplitWrite(conn net.Conn, p []byte, positions []int) error {
	// ponytail: stream backend only supports split positions; fake/TTL/QUIC need
	// a lower packet hook if this still fails on a network.
	positions = zapret2NormalizeSplitPositions(positions, len(p))
	if len(positions) == 0 {
		_, err := conn.Write(p)
		return err
	}
	start := 0
	for _, pos := range positions {
		if _, err := conn.Write(p[start:pos]); err != nil {
			return err
		}
		start = pos
	}
	_, err := conn.Write(p[start:])
	return err
}

func zapret2NormalizeSplitPositions(positions []int, size int) []int {
	if size < 2 {
		return nil
	}
	out := make([]int, 0, len(positions))
	seen := map[int]struct{}{}
	for _, pos := range positions {
		if pos <= 0 || pos >= size {
			continue
		}
		if _, ok := seen[pos]; ok {
			continue
		}
		seen[pos] = struct{}{}
		out = append(out, pos)
	}
	sort.Ints(out)
	return out
}
