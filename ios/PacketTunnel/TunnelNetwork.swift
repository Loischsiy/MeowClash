import Foundation
import NetworkExtension
import Darwin

// Public NE routing/DNS APIs. No local HTTP controller and no private API for
// packetFlow. The Go TUN uses exactly these addresses and MTU.
enum TunnelNetwork {
    static func settings(_ snapshot: [String: Any]) throws -> NEPacketTunnelNetworkSettings {
        guard let setup = snapshot["setup"] as? [String: Any],
              let config = setup["config"] as? [String: Any] else { throw MeowError("No VPN configuration") }
        let network = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "172.19.0.2")
        network.mtu = 1500
        let v4 = NEIPv4Settings(addresses: ["172.19.0.1"], subnetMasks: ["255.255.255.252"])
        let v6 = NEIPv6Settings(addresses: ["fdfe:dcba:9876::1"], networkPrefixLengths: [126])
        let tun = config["tun"] as? [String: Any] ?? [:]
        let configuredRoutes = tun["route-address"] as? [String] ?? []
        var routes4: [NEIPv4Route] = []
        var routes6: [NEIPv6Route] = []
        for text in configuredRoutes {
            let parts = text.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, let bits = Int(parts[1]) else { throw MeowError("Invalid route CIDR: \(text)") }
            let address = String(parts[0])
            if address.contains(":") {
                var binary = in6_addr()
                guard (0...128).contains(bits), inet_pton(AF_INET6, address, &binary) == 1 else { throw MeowError("Invalid IPv6 route") }
                routes6.append(NEIPv6Route(destinationAddress: address, networkPrefixLength: NSNumber(value: bits)))
            } else {
                var binary = in_addr()
                guard (0...32).contains(bits), inet_pton(AF_INET, address, &binary) == 1 else { throw MeowError("Invalid IPv4 route") }
                let mask: UInt32 = bits == 0 ? 0 : UInt32.max << (32 - bits)
                let dotted = [24,16,8,0].map { String((mask >> $0) & 255) }.joined(separator: ".")
                routes4.append(NEIPv4Route(destinationAddress: address, subnetMask: dotted))
            }
        }
        if configuredRoutes.isEmpty { routes4 = [.default()]; routes6 = [.default()] }
        // Route the tunnel DNS even in custom/split route mode.
        routes4.append(NEIPv4Route(destinationAddress: "172.19.0.0", subnetMask: "255.255.255.252"))
        v4.includedRoutes = routes4
        network.ipv4Settings = v4
        if config["ipv6"] as? Bool == true {
            v6.includedRoutes = routes6
            network.ipv6Settings = v6
        }
        let dns = NEDNSSettings(servers: ["172.19.0.2"])
        dns.matchDomains = [""]
        dns.matchDomainsNoSearch = true
        network.dnsSettings = dns
        return network
    }
}
