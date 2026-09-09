import Foundation

public enum HistoryError: Error { case malformedRecord, conflictingObservation, persistenceFailed, incompleteTail }

/// JSONL is append-only between retention compactions. Dates are Unix seconds, preserving subsecond observations.
struct HistoryLoad: Sendable {
    let observations: [BalanceObservation]; let discardedOldRecords: Bool; var tail = Data()
}

struct HistoryStore: Sendable {
    let url: URL

    func load(since cutoff: Date, allowIncompleteTail: Bool = false) throws -> HistoryLoad {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return HistoryLoad(observations: [], discardedOldRecords: false)
        }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        var discardedOldRecords = false
        var buffer = Data()
        var records: [BalanceObservationKey: BalanceObservation] = [:]
        while let chunk = try file.read(upToCount: 65536), !chunk.isEmpty {
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 10) {
                let line = Data(buffer[..<newline])
                buffer.removeSubrange(...newline)
                guard !line.isEmpty else { continue }
                let record = try Self.decoder.decode(BalanceObservation.self, from: line)
                guard !record.amount.isNaN, record.currency.count == 3,
                    record.availableCurrencies.contains(record.currency)
                else { throw HistoryError.malformedRecord }
                if let old = records[record.key], old != record { throw HistoryError.conflictingObservation }
                if record.observedAt >= cutoff { records[record.key] = record } else { discardedOldRecords = true }
            }
            guard buffer.count < 65536 else { throw HistoryError.malformedRecord }
        }
        guard buffer.isEmpty || allowIncompleteTail else { throw HistoryError.incompleteTail }
        return HistoryLoad(
            observations: records.values.sorted { $0.observedAt < $1.observedAt },
            discardedOldRecords: discardedOldRecords, tail: buffer)
    }

    /// Repair only a non-newline-terminated tail after validating every complete record.
    /// A well-formed but incompatible final record is preserved as an error, not discarded.
    func recoverIncompleteTail() throws -> String? {
        let loaded = try load(since: .distantPast, allowIncompleteTail: true)
        guard !loaded.tail.isEmpty else { return nil }
        var records = loaded.observations
        let completeJSON = (try? JSONSerialization.jsonObject(with: loaded.tail, options: .fragmentsAllowed)) != nil
        if completeJSON {
            let record = try Self.decoder.decode(BalanceObservation.self, from: loaded.tail)
            guard !record.amount.isNaN, record.currency.count == 3,
                record.availableCurrencies.contains(record.currency)
            else { throw HistoryError.malformedRecord }
            if let prior = records.first(where: { $0.key == record.key }) {
                guard prior == record else { throw HistoryError.conflictingObservation }
            } else {
                records.append(record)
            }
        }
        let backup = url.deletingLastPathComponent().appending(path: "history-incomplete-\(UUID()).jsonl")
        try FileManager.default.copyItem(at: url, to: backup)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        try compact(records)
        return completeJSON
            ? "History journal repaired; original file kept as a backup."
            : "History restored; the incomplete fragment is preserved in a backup."
    }

    func append(_ records: [BalanceObservation]) throws {
        guard !records.isEmpty else { return }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        if !FileManager.default.fileExists(atPath: url.path) {
            guard
                FileManager.default.createFile(
                    atPath: url.path, contents: Data(), attributes: [.posixPermissions: 0o600])
            else { throw CocoaError(.fileWriteUnknown) }
        }
        let file = try FileHandle(forWritingTo: url)
        defer { try? file.close() }
        let offset = try file.seekToEnd()
        var data = Data()
        for record in records { data.append(try Self.encoder.encode(record)); data.append(10) }
        do { try file.write(contentsOf: data); try file.synchronize() } catch {
            try file.truncate(atOffset: offset)
            throw error
        }
    }

    func compact(_ records: [BalanceObservation]) throws {
        var data = Data()
        for record in records { data.append(try Self.encoder.encode(record)); data.append(10) }
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970;
        encoder.outputFormatting = [.sortedKeys]; return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970; return decoder
    }()
}
