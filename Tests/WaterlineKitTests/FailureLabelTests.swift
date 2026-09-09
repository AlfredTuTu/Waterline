import Testing

@testable import WaterlineKit

struct FailureLabelTests {
    @Test func retainedScopeUsesReadableLabelsWithoutDuplicates() {
        let usage = Usage.windows(
            windows: [
                UsageWindow(label: "Week", usedFraction: nil, resetsAt: nil, id: "a", failureScopes: ["group"]),
                UsageWindow(label: "Week", usedFraction: nil, resetsAt: nil, id: "b", failureScopes: ["group"]),
            ], plan: nil)
        #expect(usage.label(for: MetricFailure(id: "group", error: .permissionDenied)) == "Week")
    }
    @Test func absentKnownQuotaAndCurrencyStayIdentifiable() {
        let usage = Usage.windows(windows: [], plan: nil)
        #expect(usage.label(for: MetricFailure(id: "seven_day", error: .permissionDenied)) == "7d")
        #expect(usage.label(for: MetricFailure(id: "balance.CNY", error: .permissionDenied)) == "CNY")
    }
    @Test func unknownTechnicalPathIsNotTheMainLabel() {
        let usage = Usage.windows(windows: [], plan: nil)
        #expect(usage.label(for: MetricFailure(id: "future.private.path", error: .permissionDenied)) == "Usage")
    }
}
