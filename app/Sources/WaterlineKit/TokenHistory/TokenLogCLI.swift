import Foundation

extension WaterlineCLI {
    private struct TokenLogSummary: Encodable {
        let observedInputTokens: String
        let observedCachedInputTokens: String
        let observedOutputTokens: String
        let observedTotalTokens: String
        let samples: Int
        let coverageGaps: Int
        let incompleteTail: Bool
        let accountAttributed = false
        let priced = false
    }

    static func analyzeCodexLog(_ url: URL, json: Bool) -> CLIResult {
        do {
            let report = try CodexTokenLog.read(url)
            func sum(_ key: KeyPath<CodexTokenCounters, Int64>) -> String {
                NSDecimalNumber(decimal: report.samples.reduce(Decimal.zero) { $0 + Decimal($1.usage[keyPath: key]) })
                    .stringValue
            }
            let summary = TokenLogSummary(
                observedInputTokens: sum(\.input), observedCachedInputTokens: sum(\.cachedInput),
                observedOutputTokens: sum(\.output), observedTotalTokens: sum(\.total),
                samples: report.samples.count, coverageGaps: report.coverageGaps, incompleteTail: report.incompleteTail)
            let partial = report.coverageGaps > 0 || report.incompleteTail
            let output: String
            if json {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                output = String(decoding: try encoder.encode(summary), as: UTF8.self)
            } else {
                output =
                    "Observed tokens: \(summary.observedTotalTokens) (input \(summary.observedInputTokens), output \(summary.observedOutputTokens))\n"
                    + "Local log only; not attributed to an account or priced."
            }
            return CLIResult(
                exitCode: partial ? 2 : 0, output: output + "\n",
                error: partial ? "Log coverage is incomplete; the result includes observed intervals only.\n" : "")
        } catch {
            let message: String
            switch error {
            case TokenLogError.tooLarge: message = "Log exceeds the supported file or record read budget."
            case TokenLogError.ambiguousOwnership: message = "Inherited or mixed-ownership logs are not yet supported."
            case TokenLogError.invalidRecordAtOffset(let offset):
                message = "Log contains an incompatible record near byte \(offset)."
            case TokenLogError.invalidRecord: message = "Log contains an incompatible or incomplete record."
            default: message = "Could not read the selected regular log file."
            }
            return CLIResult(exitCode: 1, output: "", error: message + "\n")
        }
    }
}
