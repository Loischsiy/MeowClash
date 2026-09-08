import Foundation
import Darwin

// Both targets must have the SAME AppGroupIdentifier and signed entitlement.
// No private-directory fallback: it would appear to work in Runner and leave
// the extension unable to read the profile on a device/reconnect.
final class SharedStore {
    static let maxMessageBytes = 8 * 1024 * 1024
    let home: URL
    let control: URL
    let ipc: URL

    init() throws {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              !group.isEmpty,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw MeowError("App Group unavailable. Sign Runner and PacketTunnel with the same App Group.")
        }
        home = root.appendingPathComponent("MeowClash", isDirectory: true)
        control = home.appendingPathComponent(".ios", isDirectory: true)
        ipc = control.appendingPathComponent("ipc", isDirectory: true)
        for directory in [home, control, ipc] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        }
    }

    static func json(_ value: Any) throws -> String {
        let bytes = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        guard bytes.count <= maxMessageBytes, let result = String(data: bytes, encoding: .utf8) else {
            throw MeowError("iOS message exceeds 8 MiB")
        }
        return result
    }

    static func object(_ text: String) throws -> [String: Any] {
        guard let data = text.data(using: .utf8), data.count <= maxMessageBytes,
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw MeowError("Invalid core message")
        }
        return object
    }

    static func action(_ method: String, _ data: Any? = nil) throws -> String {
        try json(["id": UUID().uuidString, "method": method, "data": data ?? NSNull()])
    }

    static func checkSuccess(action: String, result: String) throws {
        let request = try object(action)
        let response = try object(result)
        guard response["code"] as? Int == 0 else {
            throw MeowError(String(describing: response["data"] ?? "Core request failed"))
        }
        switch request["method"] as? String {
        case "initClash", "setState", "startListener", "stopListener":
            guard response["data"] as? Bool == true else { throw MeowError("Core refused the request") }
        case "setupConfig", "updateConfig", "changeProxy":
            guard let message = response["data"] as? String else { throw MeowError("Invalid core result") }
            if !message.isEmpty { throw MeowError(message) }
        default: break
        }
    }

    // Short file lock around snapshot read/modify/write, shared across processes.
    // No locks are held while invoking the core or waiting for NetworkExtension.
    private func locked<T>(_ body: () throws -> T) throws -> T {
        let fd = open(control.appendingPathComponent("snapshot.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { throw MeowError("Cannot lock shared VPN state") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw MeowError("Cannot lock shared VPN state") }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }

    private func readUnlocked() throws -> [String: Any] {
        let path = control.appendingPathComponent("snapshot.json")
        guard FileManager.default.fileExists(atPath: path.path) else { return [:] }
        return try Self.object(read(path))
    }

    func snapshot() throws -> [String: Any] { try locked { try readUnlocked() } }

    func record(action: String, result: String) throws {
        // Never persist a rejected config as the next reconnect profile.
        try Self.checkSuccess(action: action, result: result)
        guard Self.isPersistent(action) else { return }
        try locked {
            let next = try Self.applying(action, to: readUnlocked())
            try write(Self.json(next), to: control.appendingPathComponent("snapshot.json"))
        }
    }

    static func isPersistent(_ action: String) -> Bool {
        guard let method = try? object(action)["method"] as? String else { return false }
        return ["initClash", "setupConfig", "updateConfig", "setState", "changeProxy", "startLog", "stopLog"].contains(method)
    }

    static func applying(_ action: String, to snapshot: [String: Any]) throws -> [String: Any] {
        let request = try object(action)
        var next = snapshot
        let data = request["data"] as? String ?? ""
        switch request["method"] as? String {
        case "initClash": next["init"] = data
        case "setState": next["state"] = data
        case "setupConfig": next["setup"] = try object(data)
        case "updateConfig":
            guard var setup = next["setup"] as? [String: Any],
                  let config = setup["config"] as? [String: Any] else {
                throw MeowError("Apply a profile before changing VPN settings")
            }
            setup["config"] = merge(config, try object(data))
            next["setup"] = setup
        case "changeProxy":
            if var setup = next["setup"] as? [String: Any] {
                let selection = try object(data)
                if let group = selection["group-name"] as? String,
                   let proxy = selection["proxy-name"] as? String {
                    var selected = setup["selected-map"] as? [String: String] ?? [:]
                    selected[group] = proxy
                    setup["selected-map"] = selected
                    next["setup"] = setup
                }
            }
        case "startLog": next["logEnabled"] = true
        case "stopLog": next["logEnabled"] = false
        default: break
        }
        return next
    }

    private static func merge(_ old: [String: Any], _ update: [String: Any]) -> [String: Any] {
        var result = old
        for (key, value) in update where !(value is NSNull) {
            if let a = result[key] as? [String: Any], let b = value as? [String: Any] {
                result[key] = merge(a, b)
            } else { result[key] = value }
        }
        return result
    }

    func write(_ text: String, to url: URL) throws {
        guard let data = text.data(using: .utf8), data.count <= Self.maxMessageBytes else {
            throw MeowError("iOS message exceeds 8 MiB")
        }
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func read(_ url: URL) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              let size = attrs[.size] as? NSNumber, size.intValue <= Self.maxMessageBytes else {
            throw MeowError("Invalid or oversized shared message")
        }
        let data = try Data(contentsOf: url)
        guard data.count <= Self.maxMessageBytes, let text = String(data: data, encoding: .utf8) else {
            throw MeowError("Invalid shared message encoding")
        }
        return text
    }

    // IPC paths are derived ONLY from canonical UUIDs; never accept arbitrary
    // file paths from a provider-message envelope.
    func ipcURL(_ id: String, response: Bool = false) throws -> URL {
        guard let uuid = UUID(uuidString: id), uuid.uuidString.lowercased() == id else {
            throw MeowError("Invalid IPC request id")
        }
        return ipc.appendingPathComponent(id + (response ? ".response.json" : ".request.json"))
    }

    func removeIPC(_ id: String) {
        for response in [false, true] {
            if let url = try? ipcURL(id, response: response) { try? FileManager.default.removeItem(at: url) }
        }
    }

    func pruneIPC() {
        let files = (try? FileManager.default.contentsOfDirectory(at: ipc,
            includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for url in files {
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               Date().timeIntervalSince(date) > 300 { try? FileManager.default.removeItem(at: url) }
        }
    }
}
