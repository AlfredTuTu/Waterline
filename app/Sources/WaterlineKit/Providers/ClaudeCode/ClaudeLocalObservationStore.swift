import Foundation

public struct ClaudeLocalObservation: Codable, Sendable, Equatable {
    public let identity: BillingIdentity
    public let sessionID: UUID
    public let quotas: [ClaudeStatuslineQuota]
    /// First receipt of these values, not a claimed server observation timestamp.
    public let receivedAt: Date
}

public struct ClaudeLocalObservationStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }

    private struct Record: Codable, Equatable {
        var binding: ClaudeSessionBinding
        var observation: ClaudeLocalObservation?
    }

    @discardableResult
    public func capture(
        _ reading: ClaudeStatuslineReading, localIdentity: BillingIdentity,
        verifiedIdentity: BillingIdentity, receivedAt: Date
    ) throws -> ClaudeLocalObservation? {
        guard ClaudeLocalLogin.matches(localIdentity, verified: verifiedIdentity) else {
            throw FetchError.credentialMissing
        }
        let lock = try WriterLock(directory: directory)
        defer { withExtendedLifetime(lock) {} }
        let url = directory.appending(path: reading.sessionID.uuidString + ".json")
        let previous = try load(url)
        var record: Record
        if let previous {
            record = previous
        } else {
            guard
                let binding = ClaudeSessionBinding(
                    initial: reading, localIdentity: localIdentity,
                    verifiedIdentity: verifiedIdentity)
            else { return nil }
            record = Record(binding: binding)
        }
        if let quotas = try record.binding.accept(reading, currentIdentity: localIdentity),
            quotas != record.observation?.quotas
        {
            record.observation = ClaudeLocalObservation(
                identity: verifiedIdentity, sessionID: reading.sessionID,
                quotas: quotas, receivedAt: receivedAt)
        }
        if record != previous {
            if previous == nil { try trimSessions(keeping: reading.sessionID) }
            try SnapshotStore.encoder.encode(record).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
        return record.observation
    }

    public func latest(matching identity: BillingIdentity) throws -> ClaudeLocalObservation? {
        var latest: ClaudeLocalObservation?
        for url in try sessionFiles() {
            guard let record = try load(url), let observation = record.observation,
                ClaudeLocalLogin.matches(observation.identity, verified: identity)
            else { continue }
            if latest == nil || observation.receivedAt > latest!.receivedAt { latest = observation }
        }
        return latest
    }

    private func sessionFiles() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
        guard files.count <= 512 else { throw FetchError.schemaChanged(detail: "claude.localObservation.fileCount") }
        return files
    }

    private func trimSessions(keeping sessionID: UUID) throws {
        let files = try sessionFiles().filter { $0.deletingPathExtension().lastPathComponent != sessionID.uuidString }
        guard files.count >= 128 else { return }
        let ordered = try files.map { url in
            (
                url,
                try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
            )
        }.sorted { $0.1 < $1.1 }
        for (url, _) in ordered.prefix(files.count - 127) {
            _ = try load(url)
            try FileManager.default.removeItem(at: url)
        }
    }

    public func observation(sessionID: UUID, matching identity: BillingIdentity) throws -> ClaudeLocalObservation? {
        let record = try load(directory.appending(path: sessionID.uuidString + ".json"))
        guard let observation = record?.observation,
            ClaudeLocalLogin.matches(observation.identity, verified: identity)
        else { return nil }
        return observation
    }

    private func load(_ url: URL) throws -> Record? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 65_536 else { throw FetchError.schemaChanged(detail: "claude.localObservation.size") }
        let record = try SnapshotStore.decoder.decode(Record.self, from: Data(contentsOf: url))
        guard record.binding.sessionID.uuidString + ".json" == url.lastPathComponent,
            record.binding.lastAPIDurationMilliseconds.isFinite, record.binding.lastAPIDurationMilliseconds >= 0,
            ClaudeLocalLogin.matches(record.binding.identity, verified: record.binding.identity)
        else { throw FetchError.schemaChanged(detail: "claude.localObservation.binding") }
        if let observation = record.observation {
            guard observation.sessionID == record.binding.sessionID,
                ClaudeLocalLogin.matches(observation.identity, verified: record.binding.identity),
                Set(observation.quotas.map(\.id)).count == observation.quotas.count,
                observation.quotas.allSatisfy({
                    ["five_hour", "seven_day"].contains($0.id) && $0.usedFraction.isFinite
                        && (0...1).contains($0.usedFraction)
                        && (0...253_402_300_799).contains($0.resetsAt.timeIntervalSince1970)
                })
            else { throw FetchError.schemaChanged(detail: "claude.localObservation.quotas") }
        }
        return record
    }
}
