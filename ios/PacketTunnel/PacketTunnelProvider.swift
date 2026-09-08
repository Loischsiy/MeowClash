import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let engine = CoreEngine()
    private var store: SharedStore?
    // All lifecycle/config tasks are chained on MainActor. Go executes on its
    // own serial queue, so even large provider IPC never blocks the main thread.
    @MainActor private var tail: Task<Void, Never>?
    @MainActor private var generation = 0
    @MainActor private var running = false
    @MainActor private var tunnelFD: Int32 = -1

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        Task { @MainActor in
            generation += 1
            let token = generation
            let previous = tail
            tail = Task { @MainActor in
                await previous?.value
                do {
                    let storage = try SharedStore()
                    store = storage
                    storage.pruneIPC()
                    let snapshot = try storage.snapshot()
                    try await engine.configure(isExtension: true)
                    try await engine.restore(snapshot, startListeners: true)
                    guard generation == token else { throw MeowError("VPN start cancelled") }
                    try await applyNetwork(snapshot)
                    guard generation == token else { throw MeowError("VPN start cancelled") }
                    try await restartTun()
                    guard generation == token else { throw MeowError("VPN start cancelled") }
                    running = true
                    completionHandler(nil)
                } catch {
                    try? await engine.stopTun()
                    try? await engine.suspend()
                    completionHandler(error)
                }
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Task { @MainActor in
            generation += 1
            running = false
            let previous = tail
            tail = Task { @MainActor in
                await previous?.value
                try? await engine.stopTun()
                try? await engine.suspend()
                tunnelFD = -1
                completionHandler()
            }
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        Task { @MainActor in
            let previous = tail
            tail = Task { @MainActor in
                await previous?.value
                var requestID: String?
                do {
                    guard running, messageData.count <= 256, let store = store,
                          let envelope = try JSONSerialization.jsonObject(with: messageData) as? [String: Any],
                          let id = envelope["id"] as? String else { throw MeowError("Invalid VPN request") }
                    requestID = id
                    let requestURL = try store.ipcURL(id)
                    let request = try SharedStore.object(store.read(requestURL))
                    try? FileManager.default.removeItem(at: requestURL)
                    guard let expiry = request["expiresAt"] as? Double,
                          expiry >= Date().timeIntervalSince1970,
                          expiry <= Date().timeIntervalSince1970 + 130 else { throw MeowError("Expired VPN request") }
                    let reply: String
                    switch request["op"] as? String {
                    case "events": reply = try await engine.events()
                    case "action":
                        guard let action = request["action"] as? String else { throw MeowError("Missing core action") }
                        reply = try await invoke(action, storage: store)
                    default: throw MeowError("Unsupported VPN operation")
                    }
                    guard Date().timeIntervalSince1970 <= expiry else { throw MeowError("Expired VPN response") }
                    try store.write(reply, to: store.ipcURL(id, response: true))
                    completionHandler?(try JSONSerialization.data(withJSONObject: ["ok": true]))
                } catch {
                    if let id = requestID { store?.removeIPC(id) }
                    completionHandler?(try? JSONSerialization.data(withJSONObject: ["ok": false]))
                }
            }
        }
    }

    @MainActor
    private func invoke(_ action: String, storage: SharedStore) async throws -> String {
        let request = try SharedStore.object(action)
        let method = request["method"] as? String ?? ""
        // These belong to the NE lifecycle, never to an arbitrary UI core call.
        guard !["startListener", "stopListener", "shutdown", "crash"].contains(method) else {
            throw MeowError("Use the VPN lifecycle to start or stop the extension")
        }
        let changesNetwork = method == "setupConfig" || method == "updateConfig"
        let previous = changesNetwork ? try storage.snapshot() : [:]
        let reply = try await engine.invoke(action)
        do { try SharedStore.checkSuccess(action: action, result: reply) }
        catch { return reply }
        if changesNetwork {
            let candidate = try SharedStore.applying(action, to: previous)
            do {
                try await applyNetwork(candidate)
                try await restartTun()
            } catch {
                // Do not save a half-applied configuration. Restore the prior
                // core+routes, or tear down instead of claiming a working VPN.
                do {
                    try await engine.restore(previous, startListeners: true)
                    try await applyNetwork(previous)
                    try await restartTun()
                } catch {
                    running = false
                    cancelTunnelWithError(error)
                }
                throw MeowError("Could not apply VPN network settings; previous profile retained")
            }
        }
        try storage.record(action: action, result: reply)
        return reply
    }

    @MainActor
    private func restartTun() async throws {
        // NetworkExtension may replace its utun socket when routes change.
        // Close the Go-owned duplicate before scanning to avoid finding it.
        try await engine.stopTun()
        let descriptor = MeowFindTunnelDescriptor()
        guard descriptor >= 0 else { throw MeowError("VPN tunnel descriptor is unavailable") }
        tunnelFD = descriptor
        try await engine.startTun(descriptor)
    }

    @MainActor
    private func applyNetwork(_ snapshot: [String: Any]) async throws {
        let settings = try TunnelNetwork.settings(snapshot)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setTunnelNetworkSettings(settings) { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
