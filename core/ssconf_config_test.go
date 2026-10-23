package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net"
	"testing"
	"time"

	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
)

func TestSSConfConfigUsesTCPPrefix(t *testing.T) {
	server, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer server.Close()

	const prefix = "POST / HTTP/1.1\r\n"
	port := server.Addr().(*net.TCPAddr).Port
	yaml := fmt.Sprintf(`mixed-port: 7890
allow-lan: false
mode: rule
log-level: info
ipv6: false
proxies:
  - name: "🎯 DartVPN"
    type: ss
    server: 127.0.0.1
    port: %d
    cipher: chacha20-ietf-poly1305
    password: test-password
    udp: true
    prefix: "POST / HTTP/1.1\r\n"
proxy-groups:
  - name: PROXY
    type: select
    proxies: ["🎯 DartVPN"]
rules:
  - MATCH,PROXY
`, port)

	raw, err := config.UnmarshalRawConfig([]byte(yaml))
	if err != nil {
		t.Fatalf("unmarshal config: %v", err)
	}
	parsed, err := config.ParseRawConfig(raw)
	if err != nil {
		t.Fatalf("parse config with current mihomo core: %v", err)
	}
	proxy, ok := parsed.Proxies["🎯 DartVPN"]
	if !ok {
		t.Fatal("parsed config has no DartVPN proxy")
	}
	if proxy.Type() != C.Shadowsocks {
		t.Fatalf("proxy type = %s, want Shadowsocks", proxy.Type())
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	conn, err := proxy.DialContext(ctx, &C.Metadata{
		NetWork: C.TCP,
		Host:    "example.com",
		DstPort: 443,
	})
	if err != nil {
		t.Fatalf("initialize SS connection: %v", err)
	}
	defer conn.Close()

	serverConn, err := server.Accept()
	if err != nil {
		t.Fatalf("accept SS connection: %v", err)
	}
	defer serverConn.Close()
	if err := serverConn.SetReadDeadline(time.Now().Add(time.Second)); err != nil {
		t.Fatal(err)
	}
	got := make([]byte, len(prefix))
	if _, err := io.ReadFull(serverConn, got); err != nil {
		t.Fatalf("read SS salt prefix: %v", err)
	}
	if !bytes.Equal(got, []byte(prefix)) {
		t.Fatalf("SS TCP salt prefix = %q, want %q", got, prefix)
	}
}
