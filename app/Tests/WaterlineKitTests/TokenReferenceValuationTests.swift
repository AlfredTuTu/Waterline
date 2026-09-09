import Foundation
import Testing

@testable import WaterlineKit

struct TokenReferenceValuationTests {
    private func sample(
        input: Int64, cached: Int64 = 0, writes: Int64 = 0, output: Int64 = 0, reasoning: Int64 = 0,
        model: String? = "gpt-6-astra", eligible: Bool? = true
    ) throws -> CodexTokenSample {
        CodexTokenSample(
            id: String(repeating: "a", count: 64), threadID: "aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",
            modelProvider: "openai", model: model, observedAt: Date(),
            usage: try CodexTokenCounters(
                input: input, cachedInput: cached, cacheWriteInput: writes,
                output: output, reasoningOutput: reasoning, total: input + output), pricingEligible: eligible)
    }
    @Test func cachedWritesAndReasoningAreNotBilledTwice() throws {
        let value = try sample(input: 100, cached: 40, writes: 60, output: 10, reasoning: 5)
        #expect(TokenReferenceValuation.value(for: value) == Decimal(129) / 100000)
    }
    @Test func longContextThresholdUsesEachRequestNotTheCombinedLog() throws {
        let boundary = try sample(input: 272000)
        #expect(TokenReferenceValuation.value(for: boundary) == Decimal(272) / 100)
        let longer = try sample(input: 272001, output: 100)
        #expect(TokenReferenceValuation.value(for: longer) == Decimal(544752) / 100000)
        let small = try sample(input: 200000)
        #expect(TokenReferenceValuation.summarize([small, small]).amount == 4)
    }
    @Test func additionalExactModelsUseTheirOwnRatesAndLongContextMultipliers() throws {
        for (model, short, long) in [
            ("gpt-5.6-sol", Decimal(516) / 1_000_000, Decimal(335) / 1000),
            ("gpt-5.6-terra", Decimal(278) / 1_000_000, Decimal(1678) / 10000),
            ("gpt-5.6-luna", Decimal(278) / 10_000_000, Decimal(1678) / 100000),
        ] {
            #expect(
                TokenReferenceValuation.value(
                    for: try sample(input: 100, cached: 40, writes: 60, output: 10, model: model)) == short)
            #expect(
                TokenReferenceValuation.value(
                    for: try sample(input: 300000, cached: 290000, writes: 10000, output: 100, model: model)) == long)
        }
        #expect(
            TokenReferenceValuation.value(for: try sample(input: 100, model: "gpt-5.6-sol-unknown-snapshot")) == nil)
    }

    @Test func unknownOrUnprovenRowsStayUnpricedAndPartialCoverageIsExplicit() throws {
        let valid = try sample(input: 100)
        let unknown = try sample(input: 100, model: nil)
        #expect(TokenReferenceValuation.value(for: unknown) == nil)
        #expect(TokenReferenceValuation.value(for: try sample(input: 100, eligible: nil)) == nil)
        #expect(TokenReferenceValuation.value(for: try sample(input: 100, cached: 80, writes: 30)) == nil)
        let result = TokenReferenceValuation.summarize([valid, unknown])
        #expect(result.pricedRecords == 1 && result.totalRecords == 2)
        #expect(TokenReferenceValuation.summarize([unknown]).amount == nil)
        #expect(TokenReferenceValuation.summarize([]).amount == nil)
        #expect(TokenReferenceValuation.value(for: try sample(input: 0)) == 0)
        #expect(
            TokenReferenceValuation.value(for: try sample(input: 300000, cached: 290000, writes: 10000, output: 100))
                == Decimal(8375) / 10000)
    }
}
