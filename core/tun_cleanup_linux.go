//go:build linux

package main

import (
	"net"

	"github.com/jsimonetti/rtnetlink"
	"github.com/metacubex/mihomo/log"
)

func cleanupStaleTunDevice(device string) {
	if device == "" {
		return
	}
	iface, err := net.InterfaceByName(device)
	if err != nil {
		return
	}
	conn, err := rtnetlink.Dial(nil)
	if err != nil {
		log.Warnln("[Listener] failed to open rtnetlink for stale TUN cleanup: %v", err)
		return
	}
	defer conn.Close()

	if err := conn.Link.Delete(uint32(iface.Index)); err != nil {
		log.Warnln("[Listener] failed to delete stale TUN device %s: %v", device, err)
		return
	}
	log.Infoln("[Listener] deleted stale TUN device %s", device)
}
