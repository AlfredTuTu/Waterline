import Foundation
import Testing

@testable import WaterlineKit

struct TokenImportTests {
    private func dependencies(_ url: URL) -> Engine.Dependencies {
        .init(
            adapters: [],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"),
                processEnvironment: [:], fileSystem: EmptyFiles(), keychain: EmptyKeychain(),
                allowsUserInteraction: false),
            makeHTTPClient: { _ in UnusedHTTP() }, store: SnapshotStore(url: url))
    }
    private func log(_ totals: [Int64]) throws -> Data {
        var text =
            #"{"type":"session_meta","payload":{"id":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa","source":"cli","model_provider":"openai"}}"#
            + "\n"
        text += #"{"type":"turn_context","payload":{"model":"synthetic-model"}}"# + "\n"
        var previous: Int64 = 0
        for total in totals {
            func counters(_ count: Int64) throws -> String {
                String(
                    decoding: try JSONEncoder().encode(
                        CodexTokenCounters(
                            input: count, cachedInput: 0,
                            output: 0, reasoningOutput: 0, total: count)), as: UTF8.self)
            }
            text +=
                "{\"type\":\"event_msg\",\"timestamp\":\"2026-09-07T01:00:00.123Z\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":\(try counters(total)),\"last_token_usage\":\(try counters(total-previous))}}}\n"
            previous = total
        }
        return Data(text.utf8)
    }

    @Test func importIsIdempotentAppendableAndRestoresWithoutRetainingSourceContent() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "token-import-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appending(path: "source.jsonl"), state = root.appending(path: "state/snapshot.json")
        let deps = dependencies(state), engine = Engine(dependencies: deps)
        try await engine.start()
        try log([10]).write(to: input)
        #expect(try await engine.importCodexLog(input).addedSamples == 1)
        let ledger = root.appending(path: "state/token-history.json")
        let original = try Data(contentsOf: ledger)
        #expect(try await engine.importCodexLog(input).addedSamples == 0)
        #expect(try Data(contentsOf: ledger) == original)
        try log([10, 15]).write(to: input)
        #expect(try await engine.importCodexLog(input).addedSamples == 1)
        await engine.stop()
        let restored = Engine(dependencies: deps)
        try await restored.start()
        #expect(try await restored.tokenHistory().first?.samples.map(\.usage.input) == [10, 5])
        #expect(!String(decoding: try Data(contentsOf: ledger), as: UTF8.self).contains("source.jsonl"))
        let versionTwo = try Data(contentsOf: ledger)
        var legacy = try #require(try JSONSerialization.jsonObject(with: versionTwo) as? [String: Any])
        legacy["version"] = 1
        try JSONSerialization.data(withJSONObject: legacy).write(to: ledger)
        #expect(try await restored.tokenHistory().first?.samples.first?.pricingEligible == nil)
        #expect(try await restored.importCodexLog(input).addedSamples == 0)
        #expect(try await restored.tokenHistory().first?.samples.first?.pricingEligible == true)
        await restored.stop()
    }

    @Test func alreadyCancelledImportCannotCreateALedger() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "token-cancel-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appending(path: "source.jsonl")
        try log([10]).write(to: input)
        let engine = Engine(dependencies: dependencies(root.appending(path: "state/snapshot.json")))
        try await engine.start()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await engine.importCodexLog(input)
        }
        do { _ = try await task.value; Issue.record("Cancelled import must not commit") } catch is CancellationError {}
        #expect(try await engine.tokenHistory().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.appending(path: "state/token-history.json").path))
        await engine.stop()
    }

    @Test func conflictingShorterLogAndFutureLedgerNeverOverwriteSavedRecords() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "token-conflict-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appending(path: "source.jsonl"), state = root.appending(path: "state/snapshot.json")
        let engine = Engine(dependencies: dependencies(state)); try await engine.start()
        try log([10, 15]).write(to: input); _ = try await engine.importCodexLog(input)
        let ledger = root.appending(path: "state/token-history.json"), saved = try Data(contentsOf: ledger)
        try log([5]).write(to: input)
        do {
            _ = try await engine.importCodexLog(input); Issue.record("Conflicting history must fail")
        } catch TokenLedgerError.conflictingSource {}
        #expect(try Data(contentsOf: ledger) == saved)
        let future = Data(#"{"version":3,"sources":[]}"#.utf8); try future.write(to: ledger)
        do {
            _ = try await engine.importCodexLog(input); Issue.record("Unknown ledger version must fail")
        } catch TokenLedgerError.incompatible {}
        #expect(try Data(contentsOf: ledger) == future)
        await engine.stop()
    }
}
