import Foundation

public enum TokenCounterError: Error { case invalidCounters, unsupportedCheckpointVersion }

/// Codex cumulative counters. Cache/reasoning subsets are retained, never added twice to total.
public struct CodexTokenCounters: Codable, Equatable, Sendable {
    public let input: Int64
    public let cachedInput: Int64
    public let cacheWriteInput: Int64
    public let output: Int64
    public let reasoningOutput: Int64
    public let total: Int64

    public init(
        input: Int64, cachedInput: Int64, cacheWriteInput: Int64 = 0,
        output: Int64, reasoningOutput: Int64, total: Int64
    ) throws {
        let sum = input.addingReportingOverflow(output)
        guard [input, cachedInput, cacheWriteInput, output, reasoningOutput, total].allSatisfy({ $0 >= 0 }),
            cachedInput <= input, reasoningOutput <= output, !sum.overflow, sum.partialValue == total
        else { throw TokenCounterError.invalidCounters }
        self.input = input; self.cachedInput = cachedInput; self.cacheWriteInput = cacheWriteInput
        self.output = output; self.reasoningOutput = reasoningOutput; self.total = total
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            input: values.decode(Int64.self, forKey: .input),
            cachedInput: values.decode(Int64.self, forKey: .cachedInput),
            cacheWriteInput: values.decodeIfPresent(Int64.self, forKey: .cacheWriteInput) ?? 0,
            output: values.decode(Int64.self, forKey: .output),
            reasoningOutput: values.decode(Int64.self, forKey: .reasoningOutput),
            total: values.decode(Int64.self, forKey: .total))
    }
    private enum CodingKeys: String, CodingKey {
        case input = "input_tokens", cachedInput = "cached_input_tokens", cacheWriteInput = "cache_write_input_tokens"
        case output = "output_tokens", reasoningOutput = "reasoning_output_tokens", total = "total_tokens"
    }
}

public enum TokenCounterUpdate: Equatable, Sendable {
    case baseline
    case duplicate
    case discontinuity
    case usage(CodexTokenCounters)
}

/// One logical stream only. Callers must resolve ownership/model boundaries before using a delta.
public struct TokenCounterAccumulator: Codable, Sendable {
    public private(set) var baseline: CodexTokenCounters?

    /// Nil is the safe default for a partial log. A verified full stream may explicitly supply zero.
    public init(baseline: CodexTokenCounters? = nil) { self.baseline = baseline }

    public mutating func observe(_ current: CodexTokenCounters) -> TokenCounterUpdate {
        defer { baseline = current }
        guard let previous = baseline else { return .baseline }
        if previous == current { return .duplicate }
        guard current.input >= previous.input, current.cachedInput >= previous.cachedInput,
            current.cacheWriteInput >= previous.cacheWriteInput, current.output >= previous.output,
            current.reasoningOutput >= previous.reasoningOutput, current.total >= previous.total
        else { return .discontinuity }
        guard
            let delta = try? CodexTokenCounters(
                input: current.input - previous.input, cachedInput: current.cachedInput - previous.cachedInput,
                cacheWriteInput: current.cacheWriteInput - previous.cacheWriteInput,
                output: current.output - previous.output,
                reasoningOutput: current.reasoningOutput - previous.reasoningOutput,
                total: current.total - previous.total)
        else { return .discontinuity }
        return .usage(delta)
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        guard try values.decode(Int.self, forKey: .version) == 1 else {
            throw TokenCounterError.unsupportedCheckpointVersion
        }
        baseline = try values.decodeIfPresent(CodexTokenCounters.self, forKey: .baseline)
    }
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(1, forKey: .version)
        try values.encodeIfPresent(baseline, forKey: .baseline)
    }
    private enum CodingKeys: String, CodingKey { case version, baseline }
}
