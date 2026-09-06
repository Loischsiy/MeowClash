package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"testing"

	C "github.com/metacubex/mihomo/constant"
)

type snapshotTestProxy struct {
	C.Proxy
	data  []byte
	err   error
	reads int
}

func (p *snapshotTestProxy) MarshalJSON() ([]byte, error) {
	p.reads++
	return p.data, p.err
}

func TestProxySnapshotPreservesWireFields(t *testing.T) {
	const original = `{"name":"cat","type":"Selector","all":["one","two"],"now":"one","hidden":true,"history":[{"time":"2026-09-06T00:00:00Z","delay":123}],"extra":{"url":{"alive":true,"history":[]}},"precise":9007199254740993,"serverDescription":"old"}`
	for _, description := range []string{"", "Кот \"one\"\n<>& 🐈"} {
		t.Run(fmt.Sprintf("description=%t", description != ""), func(t *testing.T) {
			proxy := &snapshotTestProxy{data: []byte(original)}
			snapshot := snapshotProxyJSON(map[string]C.Proxy{"cat": proxy}, map[string]string{"cat": description})
			var actual, expected map[string]json.RawMessage
			if err := json.Unmarshal(snapshot["cat"], &actual); err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal([]byte(original), &expected); err != nil {
				t.Fatal(err)
			}
			if description != "" {
				expected["serverDescription"], _ = json.Marshal(description)
			}
			if !reflect.DeepEqual(actual, expected) {
				t.Fatalf("fields changed: got %s", snapshot["cat"])
			}
			if string(actual["precise"]) != "9007199254740993" {
				t.Fatal("integer precision lost")
			}
			if proxy.reads != 1 {
				t.Fatalf("proxy serialized %d times", proxy.reads)
			}
			// The response must remain a snapshot when a provider changes later.
			proxy.data = []byte(`{"name":"replacement"}`)
			wire, err := (ActionResult{Data: snapshot}).Json()
			if err != nil {
				t.Fatal(err)
			}
			var response struct {
				Data map[string]json.RawMessage `json:"data"`
			}
			if err := json.Unmarshal(wire, &response); err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(response.Data, snapshot) {
				t.Fatal("response was not a snapshot")
			}
			if proxy.reads != 1 {
				t.Fatal("response reread live proxy")
			}
		})
	}
}

func TestProxySnapshotSkipsMarshalFailures(t *testing.T) {
	proxies := map[string]C.Proxy{
		"valid":     &snapshotTestProxy{data: []byte(`{"name":"valid"}`)},
		"error":     &snapshotTestProxy{err: errors.New("cannot serialize")},
		"malformed": &snapshotTestProxy{data: []byte(`{`)},
	}
	got := snapshotProxyJSON(proxies, nil)
	if len(got) != 1 || got["valid"] == nil {
		t.Fatalf("unexpected snapshot: %v", got)
	}
}

// The pre-optimization implementation is kept only as a benchmark reference.
func legacyProxySnapshot(proxies map[string]C.Proxy, descriptions map[string]string) map[string]interface{} {
	result := make(map[string]interface{}, len(proxies))
	for name, proxy := range proxies {
		data, err := json.Marshal(proxy)
		if err != nil {
			continue
		}
		item := make(map[string]interface{})
		if err := json.Unmarshal(data, &item); err != nil {
			continue
		}
		if description := descriptions[name]; description != "" {
			item["serverDescription"] = description
		}
		result[name] = item
	}
	return result
}

func BenchmarkProxySnapshot(b *testing.B) {
	// Synthetic 1,000-proxy API response with ten regular and ten URL-specific
	// delay samples per proxy. No network, credentials, or user's profile.
	proxies := make(map[string]C.Proxy, 1000)
	descriptions := make(map[string]string, 1000)
	history := make([]map[string]interface{}, 10)
	for i := range history {
		history[i] = map[string]interface{}{"time": "2026-09-06T00:00:00Z", "delay": i + 1}
	}
	for i := 0; i < 1000; i++ {
		name := fmt.Sprintf("proxy-%04d", i)
		raw, err := json.Marshal(map[string]interface{}{
			"name": name, "type": "Vless", "udp": true, "alive": true,
			"history": history,
			"extra":   map[string]interface{}{"https://example.invalid/204": map[string]interface{}{"alive": true, "history": history}},
		})
		if err != nil {
			b.Fatal(err)
		}
		proxies[name] = &snapshotTestProxy{data: raw}
		descriptions[name] = "Server description"
	}
	for _, withDescriptions := range []bool{false, true} {
		var desc map[string]string
		if withDescriptions {
			desc = descriptions
		}
		b.Run(fmt.Sprintf("described=%t", withDescriptions), func(b *testing.B) {
			for _, legacy := range []bool{true, false} {
				label := "raw"
				if legacy {
					label = "legacy"
				}
				b.Run(label, func(b *testing.B) {
					b.ReportAllocs()
					for i := 0; i < b.N; i++ {
						var snapshot interface{}
						if legacy {
							snapshot = legacyProxySnapshot(proxies, desc)
						} else {
							snapshot = snapshotProxyJSON(proxies, desc)
						}
						wire, err := (ActionResult{Data: snapshot}).Json()
						if err != nil || len(wire) == 0 {
							b.Fatalf("encode response: %v", err)
						}
					}
				})
			}
		})
	}
}
