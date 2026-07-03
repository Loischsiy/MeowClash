package main

import (
	"net"
	"testing"
	"time"
)

type zapret2RecordingConn struct {
	writes [][]byte
}

func (c *zapret2RecordingConn) Read([]byte) (int, error)        { return 0, nil }
func (c *zapret2RecordingConn) Close() error                    { return nil }
func (c *zapret2RecordingConn) LocalAddr() net.Addr             { return nil }
func (c *zapret2RecordingConn) RemoteAddr() net.Addr            { return nil }
func (c *zapret2RecordingConn) SetDeadline(time.Time) error     { return nil }
func (c *zapret2RecordingConn) SetReadDeadline(time.Time) error { return nil }
func (c *zapret2RecordingConn) SetWriteDeadline(time.Time) error {
	return nil
}
func (c *zapret2RecordingConn) Write(p []byte) (int, error) {
	c.writes = append(c.writes, append([]byte(nil), p...))
	return len(p), nil
}

func TestZapret2SplitWriteSplitsTLSClientHello(t *testing.T) {
	payload := []byte{0x16, 0x03, 0x01, 0, 4, 0x01, 1, 2, 3, 4}
	conn := &zapret2RecordingConn{}

	if !zapret2LooksLikeTLSClientHello(payload) {
		t.Fatal("payload should be detected as TLS ClientHello")
	}
	if err := zapret2SplitWrite(conn, payload); err != nil {
		t.Fatal(err)
	}
	if len(conn.writes) != 2 {
		t.Fatalf("writes = %d, want 2", len(conn.writes))
	}
	if string(append(conn.writes[0], conn.writes[1]...)) != string(payload) {
		t.Fatal("split writes did not preserve payload")
	}
}
