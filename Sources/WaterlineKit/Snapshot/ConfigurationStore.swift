import Foundation

struct ConfigurationStore: Sendable {
    let url: URL

    func load() throws -> Configuration? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let result = try SnapshotStore.decoder.decode(Configuration.self, from: Data(contentsOf: url))
        try result.validate()
        return result
    }

    func save(_ configuration: Configuration) throws {
        try configuration.validate()
        // An unreadable or newer file must not be replaced with guessed defaults.
        if let previous = try load(), previous.schemaVersion < configuration.schemaVersion {
            let backup = url.deletingLastPathComponent().appending(path: "configuration-legacy-\(UUID()).json")
            try FileManager.default.copyItem(at: url, to: backup)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let data = try SnapshotStore.encoder.encode(configuration)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
