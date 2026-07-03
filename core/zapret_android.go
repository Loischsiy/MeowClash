//go:build android && cgo

package main

import "C"

// zapret2 Android bridge.
//
// WHY THIS EXISTS
// On a non-root Android device there is no userspace NFQUEUE, so the desktop
// `nfqws` approach cannot run. The shipped path applies DPI evasion inside
// libclash.so by wrapping mihomo outbound streams in core/zapret_stream.go,
// driven from Dart over the "zapret2" method channel.
//
// STATUS: experimental stream backend. Packet-level TUN mutation remains a
// future path if stream splitting is not enough on a target network.

import (
	"encoding/json"
)

//export zapret2ApplyNative
func zapret2ApplyNative(strategyChar *C.char, argsChar *C.char, hostsChar *C.char) bool {
	var args []string
	var hosts []string
	_ = json.Unmarshal([]byte(C.GoString(argsChar)), &args)
	_ = json.Unmarshal([]byte(C.GoString(hostsChar)), &hosts)
	return zapret2Apply(C.GoString(strategyChar), args, hosts)
}

//export zapret2ClearNative
func zapret2ClearNative() {
	zapret2Clear()
}

func zapret2MutateOutbound(pkt []byte) []byte {
	// ponytail: current backend is stream-level; keep this as the future packet
	// hook only if TCP split is not enough.
	return pkt
}
