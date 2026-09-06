package main

import (
	"encoding/json"

	"github.com/metacubex/mihomo/constant"
)

// snapshotProxyJSON keeps an immutable wire snapshot, not a second object graph
// of every proxy's delay histories. The caller holds runLock while taking it;
// encoding the response after unlocking must not read live proxy objects again.
func snapshotProxyJSON(proxies map[string]constant.Proxy, descriptions map[string]string) map[string]json.RawMessage {
	result := make(map[string]json.RawMessage, len(proxies))
	for name, proxy := range proxies {
		data, err := json.Marshal(proxy)
		if err != nil {
			continue
		}
		if description := descriptions[name]; description != "" {
			// Only described proxies need a shallow top-level edit. Nested
			// histories, provider metadata and large integer values stay raw.
			var fields map[string]json.RawMessage
			if err := json.Unmarshal(data, &fields); err != nil || fields == nil {
				continue
			}
			fields["serverDescription"], _ = json.Marshal(description)
			data, err = json.Marshal(fields)
			if err != nil {
				continue
			}
		}
		result[name] = json.RawMessage(data)
	}
	return result
}
