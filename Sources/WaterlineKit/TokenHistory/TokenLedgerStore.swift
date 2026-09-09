import Foundation

public enum TokenLedgerError: Error { case incompatible, conflictingSource, capacity, busy }

public struct TokenImport: Codable, Identifiable, Sendable {
    public var id: String { threadID }
    public let threadID: String
    public let importedAt: Date
    public let samples: [CodexTokenSample]
    public let coverageGaps: Int
    public let incompleteTail: Bool
}

public struct TokenImportResult: Sendable {
    public let addedSamples: Int
    public let coverageGaps: Int
    public let incompleteTail: Bool
}

struct TokenLedgerStore: Sendable {
    let url: URL
    private struct Document: Codable {
        let version: Int
        var sources: [TokenImport]
    }
    private static let limit = 64 * 1024 * 1024
    private static var encoder: JSONEncoder {
        let value = JSONEncoder(); value.dateEncodingStrategy = .secondsSince1970;
        value.outputFormatting = [.sortedKeys]; return value
    }
    private static var decoder: JSONDecoder {
        let value = JSONDecoder(); value.dateDecodingStrategy = .secondsSince1970; return value
    }

    func load() throws -> [TokenImport] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        var currentURL = url
        currentURL.removeAllCachedResourceValues()
        let info = try currentURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true else { throw TokenLedgerError.incompatible }
        guard let size = info.fileSize, size <= Self.limit else { throw TokenLedgerError.capacity }
        let data = try Data(contentsOf: url)
        guard data.count <= Self.limit else { throw TokenLedgerError.capacity }
        let document = try Self.decoder.decode(Document.self, from: data)
        guard [1, 2].contains(document.version), Set(document.sources.map(\.threadID)).count == document.sources.count
        else {
            throw TokenLedgerError.incompatible
        }
        for source in document.sources {
            guard UUID(uuidString: source.threadID) != nil, source.coverageGaps >= 0,
                Set(source.samples.map(\.id)).count == source.samples.count,
                source.samples.allSatisfy({ $0.threadID == source.threadID && $0.id.count == 64 })
            else { throw TokenLedgerError.incompatible }
        }
        if document.version == 1 {
            return document.sources.map { source in
                TokenImport(
                    threadID: source.threadID, importedAt: source.importedAt,
                    samples: source.samples.map { sample in
                        var value = sample; value.pricingEligible = nil; return value
                    },
                    coverageGaps: source.coverageGaps, incompleteTail: source.incompleteTail)
            }
        }
        return document.sources
    }

    func merge(_ report: CodexTokenLogReport, now: Date) throws -> TokenImportResult {
        var sources = try load()
        let previous = sources.first { $0.threadID == report.threadID }
        let incoming = Dictionary(uniqueKeysWithValues: report.samples.map { ($0.id, $0) })
        var merged = report.samples
        if let previous {
            guard
                previous.samples.allSatisfy({ old in
                    guard var current = incoming[old.id] else { return false }
                    var saved = old; saved.pricingEligible = nil; current.pricingEligible = nil
                    return saved == current
                })
            else { throw TokenLedgerError.conflictingSource }
            let prior = Dictionary(uniqueKeysWithValues: previous.samples.map { ($0.id, $0) })
            merged = merged.map { sample in
                var value = sample
                if prior[sample.id]?.pricingEligible == true { value.pricingEligible = true }
                return value
            }
            if previous.samples == merged,
                previous.coverageGaps == report.coverageGaps, previous.incompleteTail == report.incompleteTail
            {
                return TokenImportResult(
                    addedSamples: 0, coverageGaps: report.coverageGaps, incompleteTail: report.incompleteTail)
            }
        }
        sources.removeAll { $0.threadID == report.threadID }
        sources.append(
            TokenImport(
                threadID: report.threadID, importedAt: now, samples: merged,
                coverageGaps: report.coverageGaps, incompleteTail: report.incompleteTail))
        let data = try Self.encoder.encode(Document(version: 2, sources: sources.sorted { $0.threadID < $1.threadID }))
        guard data.count <= Self.limit else { throw TokenLedgerError.capacity }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return TokenImportResult(
            addedSamples: report.samples.count - (previous?.samples.count ?? 0),
            coverageGaps: report.coverageGaps, incompleteTail: report.incompleteTail)
    }
}
