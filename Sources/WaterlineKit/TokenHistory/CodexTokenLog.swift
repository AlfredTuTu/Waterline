import CryptoKit
import Foundation

public enum TokenLogError: Error {
    case unsupportedFile, tooLarge, invalidRecord, ambiguousOwnership
    case invalidRecordAtOffset(Int)
}

public struct CodexTokenSample: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let threadID: String
    public let modelProvider: String?
    public let model: String?
    public let observedAt: Date
    public let usage: CodexTokenCounters
    public var pricingEligible: Bool?
}

public struct CodexTokenLogReport: Sendable {
    public let threadID: String
    public let samples: [CodexTokenSample]
    public let coverageGaps: Int
    public let incompleteTail: Bool
}

/// Read-only, bounded JSONL analysis. Prompt/response content is never returned or persisted.
public enum CodexTokenLog {
    public static func read(_ url: URL) throws -> CodexTokenLogReport {
        var sourceURL = url
        sourceURL.removeAllCachedResourceValues()
        let values = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, let size = values.fileSize else {
            throw TokenLogError.unsupportedFile
        }
        guard size <= 512 * 1024 * 1024 else { throw TokenLogError.tooLarge }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let scanner = JSONLRecordScanner(file: file, length: size)
        var parser = Parser()
        var incompleteTail = false
        do {
            while let record = try scanner.next() {
                if record.type == "event_msg" && (!record.payloadIsObject || record.payloadType == nil) {
                    throw TokenLogError.invalidRecord
                }
                let relevant =
                    record.type == "session_meta" || record.type == "turn_context"
                    || (record.type == "event_msg" && ["token_count", "model_reroute"].contains(record.payloadType))
                if relevant {
                    try parser.consume(scanner.data(for: record))
                } else if parser.threadID == nil {
                    throw TokenLogError.ambiguousOwnership
                }
            }
        } catch JSONLRecordScanner.ScanError.incomplete { incompleteTail = true } catch TokenLogError.invalidRecord {
            throw TokenLogError.invalidRecordAtOffset(scanner.offset)
        }
        guard let threadID = parser.threadID else { throw TokenLogError.ambiguousOwnership }
        return CodexTokenLogReport(
            threadID: threadID, samples: parser.samples, coverageGaps: parser.gaps, incompleteTail: incompleteTail)
    }

    private struct Parser {
        var threadID: String?
        var provider: String?
        var model: String?
        var accumulator = TokenCounterAccumulator()
        var samples: [CodexTokenSample] = []
        var gaps = 0
        var segment = 0
        var lastTime: Date?

        mutating func consume(_ data: Data) throws {
            let event: Event
            do { event = try JSONDecoder().decode(Event.self, from: data) } catch { throw TokenLogError.invalidRecord }
            switch event.kind {
            case .meta(let id, let providerID, let inherited):
                guard threadID == nil, !inherited, UUID(uuidString: id) != nil else {
                    throw TokenLogError.ambiguousOwnership
                }
                threadID = id.lowercased(); provider = providerID
            case .model(let name):
                guard threadID != nil else { throw TokenLogError.ambiguousOwnership }
                model = name
            case .usage(let total, let last, let cacheFieldsReported):
                guard let threadID, let rawTime = event.timestamp, let time = parseDate(rawTime) else {
                    throw TokenLogError.invalidRecord
                }
                if let lastTime, time < lastTime { throw TokenLogError.invalidRecord }
                lastTime = time
                if accumulator.baseline == nil, total == last {
                    accumulator = TokenCounterAccumulator(
                        baseline: try CodexTokenCounters(
                            input: 0, cachedInput: 0, output: 0, reasoningOutput: 0, total: 0))
                }
                switch accumulator.observe(total) {
                case .baseline: gaps += 1
                case .discontinuity: gaps += 1; segment += 1
                case .duplicate: break
                case .usage(let delta):
                    let attributedModel = delta == last ? model : nil
                    if attributedModel == nil { gaps += 1 }
                    let key = [
                        threadID, String(segment), rawTime, String(total.input), String(total.cachedInput),
                        String(total.cacheWriteInput),
                        String(total.output), String(total.reasoningOutput), String(total.total),
                    ].joined(separator: "/")
                    samples.append(
                        CodexTokenSample(
                            id: SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined(),
                            threadID: threadID, modelProvider: provider, model: attributedModel, observedAt: time,
                            usage: delta, pricingEligible: attributedModel != nil && cacheFieldsReported))
                }
            case .ignored:
                guard threadID != nil else { throw TokenLogError.ambiguousOwnership }
            }
        }
        private func parseDate(_ value: String) -> Date? {
            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = parser.date(from: value) { return date }
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: value)
        }
    }

    private struct Event: Decodable {
        enum Kind {
            case meta(String, String?, Bool), model(String?), usage(CodexTokenCounters, CodexTokenCounters?, Bool),
                ignored
        }
        let timestamp: String?
        let kind: Kind
        enum Key: String, CodingKey {
            case type, timestamp, payload, id, model, info, source
            case threadSource = "thread_source"
            case modelProvider = "model_provider", fork = "forked_from_id", parent = "parent_thread_id"
            case historyBase = "history_base", inheritedOrdinal = "subagent_history_start_ordinal"
            case total = "total_token_usage", last = "last_token_usage", toModel = "to_model"
            case cacheWrite = "cache_write_input_tokens"
        }
        init(from decoder: any Decoder) throws {
            let root = try decoder.container(keyedBy: Key.self)
            timestamp = try root.decodeIfPresent(String.self, forKey: .timestamp)
            let type = try root.decode(String.self, forKey: .type)
            guard ["session_meta", "turn_context", "event_msg"].contains(type) else { kind = .ignored; return }
            let payload = try root.nestedContainer(keyedBy: Key.self, forKey: .payload)
            if type == "session_meta" {
                let source = try payload.decode(String.self, forKey: .source)
                let threadSource = try payload.decodeIfPresent(String.self, forKey: .threadSource)
                var inherited = !["cli", "vscode", "exec"].contains(source) || threadSource == "subagent"
                for key in [Key.fork, .parent, .historyBase, .inheritedOrdinal] {
                    if payload.contains(key), try !payload.decodeNil(forKey: key) { inherited = true }
                }
                kind = .meta(
                    try payload.decode(String.self, forKey: .id),
                    try payload.decodeIfPresent(String.self, forKey: .modelProvider), inherited)
            } else if type == "turn_context" {
                kind = .model(try payload.decodeIfPresent(String.self, forKey: .model))
            } else {
                let event = try payload.decode(String.self, forKey: .type)
                if event == "model_reroute" {
                    kind = .model(try payload.decode(String.self, forKey: .toModel))
                } else if event == "token_count", payload.contains(.info), try !payload.decodeNil(forKey: .info) {
                    let info = try payload.nestedContainer(keyedBy: Key.self, forKey: .info)
                    let total = try info.decode(CodexTokenCounters.self, forKey: .total)
                    // A context adjustment can make last-usage unusable while cumulative totals remain valid.
                    // Such intervals stay unassigned to a model and carry a coverage gap.
                    let last = try? info.decode(CodexTokenCounters.self, forKey: .last)
                    let totalFields = try info.nestedContainer(keyedBy: Key.self, forKey: .total)
                    let lastFields = try? info.nestedContainer(keyedBy: Key.self, forKey: .last)
                    let totalCache =
                        totalFields.contains(.cacheWrite)
                        && ((try? totalFields.decodeNil(forKey: .cacheWrite)) == false)
                    let lastCache =
                        lastFields?.contains(.cacheWrite) == true
                        && ((try? lastFields?.decodeNil(forKey: .cacheWrite)) == false)
                    kind = .usage(total, last, totalCache && lastCache)
                } else {
                    kind = .ignored
                }
            }
        }
    }
}
