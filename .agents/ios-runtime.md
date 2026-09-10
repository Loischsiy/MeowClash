# iOS runtime architecture (Runner vs PacketTunnel)

Router: `AGENTS.md`. Build-time iOS notes: `.agents/platform-gotchas.md`.

- Dart keeps MeowClash's existing `id / method / data` + `code` protocol, including its double-encoded
  config strings. Do not import the newer reference project's protocol into this older core.
- **Runner** hosts a foreground preview core; **PacketTunnel** hosts the independent VPN core with no
  Flutter engine. Backgrounding or disposing Flutter must never stop the VPN.
- Both processes share profiles/geodata through the App Group, but each has its **own BoltDB**
  (`.ios-ui-cache` / `.ios-tunnel-cache`) so one database is never owned twice. Runner releases preview
  providers/listeners before the VPN starts.
- A successful config, the selected-proxy map, raw updates and core state are saved atomically for
  reconnects. A rejected config update must not replace that snapshot.
- Large payloads use bounded UUID-scoped files in the App Group; only the small UUID envelope goes
  through `sendProviderMessage`, and no public TCP control server is exposed. Requests/responses cap at
  **8 MiB**; UI event storage caps at **128 events / 256 KiB** and is drained only while Flutter is
  foregrounded — dropping old events must never interrupt the tunnel.
- Go runs with a **32 MiB soft memory limit** inside the extension. That is not an RSS guarantee: large
  geodata, huge rule sets or complex transports can still get the NE killed by the OS.
- The extension owns TUN/DNS/routes and Go receives a duplicated NE socket descriptor. Internal
  auto-routing, process discovery, the external controller and profile-defined inbound listeners are
  **disabled on iOS**; loopback HTTP/SOCKS stay available inside the running core.
- Android's per-app access control and system-proxy/allow-bypass switches must not be advertised on iOS.
  Disabling IPv6 removes IPv6 tunnel routes — it is not an IPv6 kill switch. There is no kill switch,
  per-app routing or leak-prevention guarantee.
- Subscription decryption and JS profile/provider transforms stay in the existing Dart services and run
  only while the app is foregrounded; PacketTunnel has no Android-style Flutter background service.
