import Foundation

/// `~/Library/Application Support/Waterline/snapshot.json`, written atomically. Anything on the
/// machine may read it: the CLI, statusline scripts, other agents.
public enum SnapshotStoreError: Error, Equatable {
    case unsupportedVersion(Int)
}

public struct SnapshotStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func `default`() -> SnapshotStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SnapshotStore(url: support.appending(path: "Waterline/snapshot.json"))
    }

    public func load() throws -> Snapshot? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        return try Self.decoder.decode(Snapshot.self, from: Data(contentsOf: url))
    }

    public func save(_ snapshot: Snapshot) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try load()
            if let existing, existing.schemaVersion < Snapshot.currentVersion {
                let backup = url.deletingLastPathComponent().appending(path: "snapshot-legacy-\(UUID()).json")
                try FileManager.default.copyItem(at: url, to: backup)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
            }
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try Self.encoder.encode(snapshot).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
