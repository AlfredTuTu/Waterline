import Foundation
import Testing

@testable import WaterlineKit

struct CodexTokenLogTests {
    private let header =
        #"{"type":"session_meta","payload":{"id":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa","model_provider":"openai","source":"cli"}}"#
    private let context = #"{"type":"turn_context","payload":{"model":"synthetic-model"}}"#
    private func usage(_ total: Int, last: Int, time: String = "2026-09-07T01:00:00Z") -> String {
        func counter(_ value: Int) -> String {
            "{\"input_tokens\":\(value),\"cached_input_tokens\":0,\"output_tokens\":0,\"reasoning_output_tokens\":0,\"total_tokens\":\(value)}"
        }
        return
            "{\"type\":\"event_msg\",\"timestamp\":\"\(time)\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":\(counter(total)),\"last_token_usage\":\(counter(last))}}}"
    }
    private func read(_ text: String) throws -> CodexTokenLogReport {
        let url = FileManager.default.temporaryDirectory.appending(path: "token-log-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(text.utf8).write(to: url)
        return try CodexTokenLog.read(url)
    }

    @Test func repeatedEventsAndCopiedFileProduceStableSampleIDsWithoutContent() throws {
        let text =
            [
                header, context,
                #"{"type":"response_item","payload":{"text":"do-not-retain-this-content"}}"#,
                usage(10, last: 10), usage(10, last: 10), usage(15, last: 5),
            ].joined(separator: "\n") + "\n"
        let first = try read(text), copy = try read(text)
        #expect(first.samples.map(\.usage.input) == [10, 5])
        #expect(first.samples.map(\.id) == copy.samples.map(\.id))
        #expect(first.samples.allSatisfy { $0.model == "synthetic-model" })
        let encoded = String(decoding: try JSONEncoder().encode(first.samples), as: UTF8.self)
        #expect(!encoded.contains("do-not-retain"))
    }

    @Test func unknownPrefixAndIncompleteTailAreNotCountedAsFreshUsage() throws {
        let result = try read(
            [header, context, usage(100, last: 10), usage(110, last: 10)].joined(separator: "\n") + "\n{unfinished")
        #expect(result.samples.map(\.usage.input) == [10])
        #expect(result.coverageGaps == 1 && result.incompleteTail)
    }

    @Test func inheritedOrMixedOwnershipIsRejected() throws {
        let fork =
            #"{"type":"session_meta","payload":{"id":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa","forked_from_id":"parent"}}"#
        #expect(throws: (any Error).self) { try read(fork + "\n") }
        #expect(throws: (any Error).self) { try read(header + "\n" + header + "\n") }
        #expect(throws: (any Error).self) { try read(context + "\n") }
    }

    @Test func cliAnalysisReportsObservedCountsWithoutMutatingTheSource() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "token-cli-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data(
            ([header, context, usage(10, last: 10), usage(15, last: 5)].joined(separator: "\n") + "\n").utf8)
        try original.write(to: url)
        let result = await WaterlineCLI.run(["analyze-codex-log", url.path, "--json"])
        #expect(result.exitCode == 0)
        let output = try #require(try JSONSerialization.jsonObject(with: Data(result.output.utf8)) as? [String: Any])
        #expect(output["observedTotalTokens"] as? String == "15")
        #expect(output["accountAttributed"] as? Bool == false)
        #expect(output["priced"] as? Bool == false)
        #expect(try Data(contentsOf: url) == original)
        let invalid = await WaterlineCLI.run(["analyze-codex-log"])
        #expect(invalid.exitCode == 64)
    }

    @Test func invalidLastUsageDoesNotDiscardValidCumulativeDeltaOrAcquireAPriceModel() throws {
        let badLast = usage(15, last: 5).replacingOccurrences(of: "\"total_tokens\":5", with: "\"total_tokens\":99")
        let result = try read([header, context, usage(10, last: 10), badLast].joined(separator: "\n") + "\n")
        #expect(result.samples.map(\.usage.input) == [10, 5])
        #expect(result.samples[1].model == nil)
        #expect(result.coverageGaps == 1)
    }

    @Test func resetThenRepeatedTotalHasANewStableIdentity() throws {
        let text =
            [header, context, usage(10, last: 10), usage(5, last: 5), usage(10, last: 5)]
            .joined(separator: "\n") + "\n"
        let result = try read(text)
        #expect(result.samples.map(\.usage.input) == [10, 5])
        #expect(Set(result.samples.map(\.id)).count == 2)
        #expect(result.coverageGaps == 1)
    }

    @Test func unobservedIntermediateResponsesRemainUnpriced() throws {
        let result = try read(
            [header, context, usage(10, last: 10), usage(40, last: 5)].joined(separator: "\n") + "\n")
        #expect(result.samples[1].usage.input == 30)
        #expect(result.samples[1].model == nil)
        #expect(result.coverageGaps == 1)
    }
}
