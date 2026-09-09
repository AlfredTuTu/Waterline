import Foundation

public struct TokenReferenceSummary: Sendable {
    public let amount: Decimal?
    public let pricedRecords: Int
    public let totalRecords: Int
}

/// Immutable dated standard-API reference, not a historical bill or actual service-tier charge.
public enum TokenReferenceValuation {
    public static let quoteID = "openai-base-standard-2026-09-07-v2"
    public static let reviewedOn = "2026-09-07"
    public static let currency = "USD"
    public static let sourceURL = URL(string: "https://developers.openai.com/api/docs/pricing")!

    private struct Rate: Sendable {
        let input: Decimal
        let cached: Decimal
        let write: Decimal
        let output: Decimal
    }
    private static let rates: [String: Rate] = [
        "gpt-6-astra": Rate(input: 10, cached: 1, write: Decimal(25) / 2, output: 50),
        "gpt-5.6-sol": Rate(input: 4, cached: Decimal(4) / 10, write: 5, output: 20),
        "gpt-5.6-terra": Rate(input: 2, cached: Decimal(2) / 10, write: Decimal(5) / 2, output: 12),
        "gpt-5.6-luna": Rate(
            input: Decimal(2) / 10, cached: Decimal(2) / 100, write: Decimal(25) / 100, output: Decimal(12) / 10),
    ]

    public static func value(for sample: CodexTokenSample) -> Decimal? {
        guard sample.modelProvider == "openai", sample.pricingEligible == true,
            let model = sample.model, let rate = rates[model]
        else {
            return nil
        }
        let tokens = sample.usage
        let uncached = tokens.input - tokens.cachedInput
        guard tokens.cacheWriteInput <= uncached else { return nil }
        let inputMultiplier: Decimal = tokens.input > 272000 ? 2 : 1
        let outputMultiplier: Decimal = tokens.input > 272000 ? Decimal(3) / 2 : 1
        let input = Decimal(uncached - tokens.cacheWriteInput) * rate.input
        let cacheRead = Decimal(tokens.cachedInput) * rate.cached
        let cacheWrite = Decimal(tokens.cacheWriteInput) * rate.write
        let output = Decimal(tokens.output) * rate.output
        return ((input + cacheRead + cacheWrite) * inputMultiplier + output * outputMultiplier) / 1_000_000
    }

    public static func summarize(_ samples: [CodexTokenSample]) -> TokenReferenceSummary {
        let values = samples.compactMap { value(for: $0) }
        return TokenReferenceSummary(
            amount: values.isEmpty ? nil : values.reduce(0, +),
            pricedRecords: values.count, totalRecords: samples.count)
    }
}
