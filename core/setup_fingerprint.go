package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"sync"

	"github.com/metacubex/mihomo/config"
)

// appliedSetup remembers the fingerprint of the last setupConfig that was
// fully applied. When the Android UI is swiped from recents and reopened, the
// core keeps running inside the VPN service process and the new UI sends the
// very same configuration again. Re-applying it would rebuild every proxy,
// provider and URL-test group (losing their delay history and selection),
// re-run all health checks and allocate a second copy of the config before
// the old one is collected. An identical setup on a running core is skipped.
var appliedSetup struct {
	sync.Mutex
	fingerprint string
}

// setupFingerprint covers everything setupConfig feeds into the runtime except
// SelectedMap: the live core already holds the user's current selection, and
// re-forcing it would pin URL-test groups.
func setupFingerprint(params *SetupParams) string {
	if params == nil || params.Config == nil {
		return ""
	}
	data, err := json.Marshal(struct {
		Config  *config.RawConfig `json:"config"`
		TestURL string            `json:"test-url"`
	}{params.Config, params.TestURL})
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

func appliedSetupFingerprint() string {
	appliedSetup.Lock()
	defer appliedSetup.Unlock()
	return appliedSetup.fingerprint
}

func rememberAppliedSetup(fingerprint string) {
	appliedSetup.Lock()
	appliedSetup.fingerprint = fingerprint
	appliedSetup.Unlock()
}

// invalidateAppliedSetup forces the next setupConfig to apply in full. Call it
// whenever the live runtime stops matching the last applied setup: a partial
// config patch, new geodata files, a state change or a shutdown.
func invalidateAppliedSetup() {
	rememberAppliedSetup("")
}

// canSkipSetup reports whether a setup with this fingerprint would only
// recreate the runtime that is already live. Only a running core qualifies:
// while stopped, provider caches may have been rewritten on disk and must be
// reread by a full setup. Callers hold runLock.
func canSkipSetup(fingerprint string) bool {
	return isRunning &&
		currentConfig != nil &&
		fingerprint != "" &&
		fingerprint == appliedSetupFingerprint()
}
