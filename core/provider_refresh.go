package main

import (
	"encoding/base64"
	"errors"
	"path/filepath"

	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

const maxProviderPayloadBytes = 16 << 20

// Keep proxy and rule providers separate: their YAML namespaces may contain
// the same name. The legacy name-only map remains for older callers.
func externalProviderCandidates() []cp.Provider {
	proxies := tunnel.Providers()
	rules := tunnel.RuleProviders()
	result := make([]cp.Provider, 0, len(proxies)+len(rules))
	for _, p := range proxies {
		if p.VehicleType() != cp.Compatible {
			result = append(result, p)
		}
	}
	for _, p := range rules {
		if p.VehicleType() != cp.Compatible {
			result = append(result, p)
		}
	}
	return result
}

func decodeProviderPayload(params map[string]string) ([]byte, error) {
	if encoded, exists := params["dataBase64"]; exists {
		if _, ambiguous := params["data"]; ambiguous {
			return nil, errors.New("ambiguous provider payload")
		}
		if len(encoded) > base64.StdEncoding.EncodedLen(maxProviderPayloadBytes) {
			return nil, errors.New("provider payload is too large")
		}
		data, err := base64.StdEncoding.DecodeString(encoded)
		if err != nil {
			return nil, errors.New("invalid provider base64 payload")
		}
		if len(data) > maxProviderPayloadBytes {
			return nil, errors.New("provider payload is too large")
		}
		return data, nil
	}
	data := []byte(params["data"])
	if len(data) > maxProviderPayloadBytes {
		return nil, errors.New("provider payload is too large")
	}
	return data, nil
}

func providerTargetMatches(info *ExternalProvider, name, kind, path string) bool {
	return info.Name == name && info.Type == kind && path != "" &&
		filepath.Clean(info.Path) == filepath.Clean(path)
}

// Resolve against live providers under runLock, never against an obsolete API
// snapshot. The path guard prevents a late download crossing profile boundaries.
func applyProviderRefresh(params map[string]string, data []byte) error {
	runLock.Lock()
	defer runLock.Unlock()
	name, kind, path := params["providerName"], params["providerType"], params["expectedPath"]
	if kind == "" && path == "" { // Backward-compatible UTF-8 caller.
		p, exists := getExternalProvidersRaw()[name]
		if !exists {
			return errors.New("external provider does not exist")
		}
		return sideUpdateExternalProvider(p, data)
	}
	for _, p := range externalProviderCandidates() {
		if p.Name() != name || p.Type().String() != kind {
			continue
		}
		info, err := toExternalProvider(p)
		if err == nil && providerTargetMatches(info, name, kind, path) {
			return sideUpdateExternalProvider(p, data)
		}
	}
	return errors.New("provider context changed or provider does not exist")
}
