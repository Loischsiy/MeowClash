import Foundation

struct MeowError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

// C calls can parse large profiles / wait for network I/O. Never run them on
// Flutter's platform thread or the NetworkExtension callback queue.
final class CoreEngine {
    private let queue = DispatchQueue(label: "com.meowclash.core", qos: .userInitiated)

    func perform<T>(_ body: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do { continuation.resume(returning: try body()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func configure(isExtension: Bool) async throws {
        try await perform { meowSetTunnelProcess(isExtension ? 1 : 0) }
    }

    func invoke(_ action: String) async throws -> String {
        guard action.utf8.count <= SharedStore.maxMessageBytes else {
            throw MeowError("iOS core request exceeds 8 MiB")
        }
        return try await perform {
            try action.withCString { source in
                guard let result = meowInvokeAction(UnsafeMutablePointer(mutating: source)) else {
                    throw MeowError("Core returned an empty response")
                }
                defer { meowFreeCString(result) }
                return String(cString: result)
            }
        }
    }

    @discardableResult
    func checked(_ method: String, _ data: Any? = nil) async throws -> String {
        let action = try SharedStore.action(method, data)
        let result = try await invoke(action)
        try SharedStore.checkSuccess(action: action, result: result)
        return result
    }

    func restore(_ snapshot: [String: Any], startListeners: Bool = false) async throws {
        guard let initial = snapshot["init"] as? String,
              let setup = snapshot["setup"] as? [String: Any] else {
            throw MeowError("Open MeowClash and apply a profile before starting VPN")
        }
        try await checked("initClash", initial)
        if let state = snapshot["state"] as? String { try await checked("setState", state) }
        try await checked("setupConfig", SharedStore.json(setup))
        try await checked(snapshot["logEnabled"] as? Bool == true ? "startLog" : "stopLog")
        if startListeners { try await checked("startListener") }
    }

    func events() async throws -> String {
        try await perform {
            guard let result = meowDrainEvents() else { return "[]" }
            defer { meowFreeCString(result) }
            return String(cString: result)
        }
    }

    func startTun(_ fd: Int32) async throws {
        try await perform {
            guard let result = meowStartTun(fd) else { throw MeowError("TUN returned no result") }
            defer { meowFreeCString(result) }
            let message = String(cString: result)
            if !message.isEmpty { throw MeowError(message) }
        }
    }

    func stopTun() async throws { try await perform { meowStopTun() } }
    func suspend() async throws { try await perform { meowSuspendCore() } }
}
