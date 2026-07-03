package main

import (
	"context"
	"encoding/json"
	"net"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/common/buf"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

type zapret2StateT struct {
	mu         sync.RWMutex
	enabled    atomic.Bool
	strategy   string
	args       []string
	hostFilter map[string]struct{}
}

var zapret2State = &zapret2StateT{hostFilter: map[string]struct{}{}}

func zapret2ShouldMutate() bool { return zapret2State.enabled.Load() }

func zapret2Apply(strategy string, args []string, hosts []string) bool {
	zapret2State.mu.Lock()
	defer zapret2State.mu.Unlock()
	zapret2State.strategy = strategy
	zapret2State.args = args
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

type zapret2Conn struct {
	C.Conn
	wroteFirst atomic.Bool
}

func (c *zapret2Conn) Write(p []byte) (int, error) {
	if c.wroteFirst.CompareAndSwap(false, true) && zapret2LooksLikeTLSClientHello(p) {
		if err := zapret2SplitWrite(c.Conn, p); err != nil {
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

func zapret2SplitWrite(conn net.Conn, p []byte) error {
	// ponytail: one-byte split; add strategy-specific split positions when this
	// userspace backend proves useful enough to tune per network.
	if len(p) < 2 {
		_, err := conn.Write(p)
		return err
	}
	if _, err := conn.Write(p[:1]); err != nil {
		return err
	}
	_, err := conn.Write(p[1:])
	return err
}
