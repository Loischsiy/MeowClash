import Flutter
import Foundation
import NetworkExtension

@MainActor
final class IOSService {
    private let channel: FlutterMethodChannel
    private let engine = CoreEngine()
    private var store: SharedStore?
    private var manager: NETunnelProviderManager?
    private var observer: NSObjectProtocol?
    private var initialization: Task<Void, Error>?
    private var actionTail: Task<Void, Never>?
    private var generation = 0
    private var transition: Int?
    private var needsRestore = false

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.meowclash/ios", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            Task { @MainActor in
                guard let self = self else { result(FlutterError(code: "disposed", message: "iOS bridge unavailable", details: nil)); return }
                self.handle(call, result)
            }
        }
        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.manager?.connection.status == .disconnected { self.needsRestore = true }
                self.channel.invokeMethod("statusChanged", arguments: self.status())
            }
        }
    }

    deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) } }

    private var bundleID: String { Bundle.main.bundleIdentifier! + ".PacketTunnel" }

    private func initialize() async throws {
        if let task = initialization { return try await task.value }
        let task = Task { @MainActor in
            let storage = try SharedStore()
            storage.pruneIPC()
            self.store = storage
            try await self.engine.configure(isExtension: false)
            let managers = try await Self.loadManagers()
            self.manager = managers.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.bundleID }
        }
        initialization = task
        do { try await task.value }
        catch { initialization = nil; throw error }
    }

    private static func loadManagers() async throws -> [NETunnelProviderManager] {
        try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: managers ?? []) }
            }
        }
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    private func status() -> [String: Any] {
        let connection = manager?.connection
        let state: String
        switch connection?.status ?? .disconnected {
        case .connected: state = "connected"
        case .connecting: state = "connecting"
        case .reasserting: state = "reasserting"
        case .disconnecting: state = "disconnecting"
        case .invalid: state = "invalid"
        default: state = "disconnected"
        }
        var result: [String: Any] = ["status": state]
        if (state == "connected" || state == "reasserting"), let date = connection?.connectedDate {
            result["startedAt"] = Int64(date.timeIntervalSince1970 * 1000)
        }
        return result
    }

    private var connected: Bool {
        manager?.connection.status == .connected || manager?.connection.status == .reasserting
    }

    private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        // Lifecycle requests may supersede a start immediately; normal actions
        // are serialized so snapshot persistence cannot reorder configurations.
        if call.method == "action" || call.method == "events" {
            let previous = actionTail
            actionTail = Task { @MainActor in
                await previous?.value
                do {
                    try await self.initialize()
                    if call.method == "events" { result(try await self.events()) }
                    else {
                        guard let text = call.arguments as? String else { throw MeowError("Missing core action") }
                        result(try await self.invoke(text))
                    }
                } catch { self.fail(result, error) }
            }
            return
        }
        Task { @MainActor in
            do {
                try await initialize()
                switch call.method {
                case "initialize": result(status())
                case "homeDirectory": result(store!.home.path)
                case "status": result(status())
                case "start": result(try await start())
                case "stop": result(try await stop())
                case "restartLocal":
                    guard !connected && transition == nil else { throw MeowError("Stop VPN before restarting the preview core") }
                    try await engine.suspend()
                    needsRestore = false
                    result(nil)
                default: result(FlutterMethodNotImplemented)
                }
            } catch { fail(result, error) }
        }
    }

    private func fail(_ result: FlutterResult, _ error: Error) {
        result(FlutterError(code: "ios_vpn", message: error.localizedDescription, details: nil))
    }

    private func invoke(_ text: String) async throws -> String {
        guard transition == nil else { throw MeowError("VPN is changing state; retry after it connects or stops") }
        let request = try SharedStore.object(text)
        if connected {
            // UI shutdown/detach is NOT authorization to stop an independent VPN.
            if request["method"] as? String == "shutdown" {
                return try SharedStore.json(["id": request["id"] ?? "", "method": "shutdown", "data": true, "code": 0])
            }
            needsRestore = true
            return try await send(op: "action", action: text)
        }
        let state = manager?.connection.status
        guard state == nil || state == .invalid || state == .disconnected else {
            throw MeowError("VPN is not ready for core requests")
        }
        if needsRestore {
            let snapshot = try store!.snapshot()
            if snapshot["setup"] != nil { try await engine.restore(snapshot) }
            needsRestore = false
        }
        let reply = try await engine.invoke(text)
        // Return domain errors to Dart unchanged; persist only successful writes.
        if SharedStore.isPersistent(text) {
            if (try? SharedStore.checkSuccess(action: text, result: reply)) != nil {
                try store!.record(action: text, result: reply)
            }
        }
        return reply
    }

    private func events() async throws -> String {
        if transition != nil { return "[]" }
        if connected { return try await send(op: "events") }
        return try await engine.events()
    }

    private func start() async throws -> [String: Any] {
        generation += 1
        let token = generation
        transition = token
        defer { if transition == token { transition = nil } }
        if connected { return status() }
        // Wait for in-flight setup before reading the snapshot and handing off.
        await actionTail?.value
        guard generation == token else { throw MeowError("VPN start cancelled") }
        let snapshot = try store!.snapshot()
        guard snapshot["init"] != nil && snapshot["setup"] != nil else {
            throw MeowError("Apply a profile before starting VPN")
        }
        try await engine.suspend()
        needsRestore = true
        guard generation == token else { throw MeowError("VPN start cancelled") }
        let manager = self.manager ?? NETunnelProviderManager()
        self.manager = manager
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = bundleID
        proto.serverAddress = "MeowClash"
        proto.disconnectOnSleep = false
        manager.protocolConfiguration = proto
        manager.localizedDescription = "MeowClash"
        manager.isEnabled = true
        try await save(manager)
        guard generation == token else { throw MeowError("VPN start cancelled") }
        do {
            try manager.connection.startVPNTunnel()
            let deadline = Date().addingTimeInterval(45)
            while Date() < deadline {
                guard generation == token else { throw MeowError("VPN start cancelled") }
                if connected { return status() }
                try await Task.sleep(nanoseconds: 200_000_000)
            }
            throw MeowError("VPN did not connect within 45 seconds. Check signing, App Group and the selected profile.")
        } catch {
            if generation == token { manager.connection.stopVPNTunnel() }
            throw error
        }
    }

    private func stop() async throws -> [String: Any] {
        generation += 1
        let token = generation
        transition = token
        defer { if transition == token { transition = nil } }
        manager?.connection.stopVPNTunnel()
        needsRestore = true
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            guard generation == token else { throw MeowError("VPN stop superseded") }
            let state = manager?.connection.status ?? .disconnected
            if state == .disconnected || state == .invalid { return status() }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        throw MeowError("VPN has not stopped yet; check its state in iOS Settings")
    }

    private func send(op: String, action: String? = nil) async throws -> String {
        guard let session = manager?.connection as? NETunnelProviderSession, let store = store else {
            throw MeowError("VPN session unavailable")
        }
        let id = UUID().uuidString.lowercased()
        var request: [String: Any] = ["op": op, "expiresAt": Date().timeIntervalSince1970 + 125]
        if let action = action { request["action"] = action }
        try store.write(SharedStore.json(request), to: store.ipcURL(id))
        let envelope = try JSONSerialization.data(withJSONObject: ["id": id])
        return try await withCheckedThrowingContinuation { continuation in
            // Every completion is marshalled to main. Timeout/reply race resumes
            // the continuation once and cleans both bounded IPC files.
            var completed = false
            var timeoutTask: Task<Void, Never>?
            func finish(_ response: Result<String, Error>) {
                guard !completed else { return }
                completed = true
                timeoutTask?.cancel()
                timeoutTask = nil
                store.removeIPC(id)
                continuation.resume(with: response)
            }
            // Cancellation releases per-request captures promptly on success.
            timeoutTask = Task { @MainActor in
                do { try await Task.sleep(nanoseconds: 125_000_000_000) }
                catch { return }
                finish(.failure(MeowError("VPN core request timed out")))
            }
            do {
                try session.sendProviderMessage(envelope) { data in
                    DispatchQueue.main.async {
                        guard !completed else { return }
                        do {
                            guard let data = data,
                                  let ack = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                  ack["ok"] as? Bool == true else {
                                throw MeowError("VPN core could not process the request")
                            }
                            finish(.success(try store.read(store.ipcURL(id, response: true))))
                        } catch { finish(.failure(error)) }
                    }
                }
            } catch { finish(.failure(error)) }
        }
    }
}
