package main

import (
	"errors"

	C "github.com/metacubex/mihomo/constant"
)

// getProviderCachePath returns the exact file an external (meowclash-external)
// provider is read from when its config has no explicit `path`. It delegates to
// mihomo itself, so Dart never re-implements the hashing.
func getProviderCachePath(kind, url string) (string, error) {
	if kind != "proxies" && kind != "rules" {
		return "", errors.New("unknown provider kind: " + kind)
	}
	if url == "" {
		return "", errors.New("provider url is empty")
	}
	if !isInit {
		return "", errors.New("core is not initialized")
	}
	return C.Path.GetPathByHash(kind, url), nil
}
