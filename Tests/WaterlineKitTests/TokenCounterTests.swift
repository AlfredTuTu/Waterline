import Foundation
import Testing

@testable import WaterlineKit

struct TokenCounterTests {
    private func count(
        _ input: Int64, _ output: Int64, cached: Int64 = 0, reasoning: Int64 = 0
    ) throws -> CodexTokenCounters {
        try CodexTokenCounters(
            input: input, cachedInput: cached, output: output, reasoningOutput: reasoning, total: input + output)
    }

    @Test func repeatedTotalsAndRestoredCheckpointDoNotDoubleCount() throws {
        var accumulator = TokenCounterAccumulator(baseline: try count(0, 0))
        let first = try count(100, 20, cached: 40, reasoning: 5)
        #expect(accumulator.observe(first) == .usage(first))
        #expect(accumulator.observe(first) == .duplicate)
        let encoded = try JSONEncoder().encode(accumulator)
        var restored = try JSONDecoder().decode(TokenCounterAccumulator.self, from: encoded)
        #expect(restored.observe(first) == .duplicate)
        let next = try count(150, 30, cached: 50, reasoning: 7)
        #expect(restored.observe(next) == .usage(try count(50, 10, cached: 10, reasoning: 2)))
    }

    @Test func partialLogAndCounterResetDoNotInventUsage() throws {
        var accumulator = TokenCounterAccumulator()
        #expect(accumulator.observe(try count(1000, 200)) == .baseline)
        #expect(accumulator.observe(try count(10, 2)) == .discontinuity)
        #expect(accumulator.observe(try count(15, 3)) == .usage(try count(5, 1)))
    }

    @Test func lateCacheCorrectionIsNotANegativeBillableInputDelta() throws {
        var accumulator = TokenCounterAccumulator(baseline: try count(100, 20, cached: 10))
        #expect(accumulator.observe(try count(100, 20, cached: 50)) == .discontinuity)
        #expect(accumulator.observe(try count(110, 22, cached: 55)) == .usage(try count(10, 2, cached: 5)))
    }

    @Test func decoderRejectsImpossibleOrOverflowingCountersAndFutureCheckpoint() throws {
        for json in [
            #"{"input_tokens":-1,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":0}"#,
            #"{"input_tokens":10,"cached_input_tokens":11,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":11}"#,
            #"{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":2,"total_tokens":11}"#,
            #"{"input_tokens":9223372036854775807,"cached_input_tokens":0,"output_tokens":1,"reasoning_output_tokens":0,"total_tokens":0}"#,
        ] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(CodexTokenCounters.self, from: Data(json.utf8))
            }
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(TokenCounterAccumulator.self, from: Data(#"{"version":2}"#.utf8))
        }
    }
}
