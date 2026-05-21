package main

import (
	"github.com/metacubex/mihomo/common/convert"
	"github.com/metacubex/mihomo/config"
	"gopkg.in/yaml.v3"
)

// normalizeSubscription accepts arbitrary subscription bytes and returns
// bytes that mihomo's config package can parse as a clash YAML.
//
// If the input already parses as a clash RawConfig (i.e. it is a regular
// clash YAML profile, encrypted or otherwise), it is returned unchanged.
//
// Otherwise it is treated as a V2Ray-style subscription -- a base64 (or
// plain text) list of vless://, vmess://, trojan://, ss://, hysteria://
// and similar share-links -- and converted into a minimal clash YAML
// containing the parsed proxies plus a single "PROXY" select group and
// a catch-all MATCH rule.
//
// If neither path produces something parseable, the original bytes are
// returned so that downstream validateConfig surfaces the original
// YAML error to the user.
func normalizeSubscription(bytes []byte) []byte {
	if _, err := config.UnmarshalRawConfig(bytes); err == nil {
		return bytes
	}

	proxies, err := convert.ConvertsV2Ray(bytes)
	if err != nil || len(proxies) == 0 {
		return bytes
	}

	names := make([]string, 0, len(proxies))
	for _, p := range proxies {
		if n, ok := p["name"].(string); ok && n != "" {
			names = append(names, n)
		}
	}

	groupProxies := make([]string, 0, len(names)+1)
	groupProxies = append(groupProxies, "DIRECT")
	groupProxies = append(groupProxies, names...)

	raw := map[string]any{
		"proxies": proxies,
		"proxy-groups": []map[string]any{
			{
				"name":    "PROXY",
				"type":    "select",
				"proxies": groupProxies,
			},
		},
		"rules": []string{"MATCH,PROXY"},
	}

	out, err := yaml.Marshal(raw)
	if err != nil {
		return bytes
	}

	if _, err := config.UnmarshalRawConfig(out); err != nil {
		return bytes
	}
	return out
}
