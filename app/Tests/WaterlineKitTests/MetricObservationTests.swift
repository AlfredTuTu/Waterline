import Foundation
import Testing

@testable import WaterlineKit

struct MetricObservationTests {
    @Test(arguments: ["grok.subscription-plan", "antigravity.subscription-plan"])
    func failedPlanLookupPreservesLastPlanAcrossPersistence(scope: String) throws {
        let now = Date(timeIntervalSince1970: 1800000000)
        let previous = Reading(usage: .windows(windows: [], plan: "Prior paid plan"), fetchedAt: now)
        let failure = MetricFailure(id: scope, error: .rateLimited(retryAfter: 120))
        let response = Usage.metrics(
            windows: [UsageWindow(label: "5h", usedFraction: 0.25, resetsAt: nil)],
            balances: [], plan: nil, failures: [failure])
        let merged = response.accepting(at: now.addingTimeInterval(60), previous: previous)
        let restored = try JSONDecoder().decode(Usage.self, from: JSONEncoder().encode(merged))
        #expect(restored.planLabel == "Prior paid plan")
        #expect(restored.quotaWindows.first?.usedFraction == 0.25)
        #expect(restored.componentFailures == [failure])
        #expect(response.accepting(at: now, previous: nil).planLabel == nil)
        let updated = Usage.windows(windows: [], plan: "New plan")
        let last = Reading(usage: restored, fetchedAt: now)
        #expect(updated.accepting(at: now, previous: last).planLabel == "New plan")
        #expect(Usage.windows(windows: [], plan: nil).accepting(at: now, previous: last).planLabel == nil)
    }

    let earlier = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func failedWindowKeepsItsOwnTimestampAcrossRepeatedFailures() throws {
        let original = try CodexAdapter.parse(
            Data(#"{"rate_limit":{"primary_window":{"used_percent":95},"secondary_window":{"used_percent":10}}}"#.utf8)
        )
        .accepting(at: earlier, previous: nil)
        let previous = Reading(usage: original, fetchedAt: earlier)
        let response = try CodexAdapter.parse(
            Data(
                #"{"rate_limit":{"primary_window":{"used_percent":"broken"},"secondary_window":{"used_percent":20}}}"#
                    .utf8))
        let partial = response.accepting(at: earlier.addingTimeInterval(300), previous: previous)
        let retained = try #require(partial.quotaWindows.first { $0.id == "rate_limit.primary_window" })
        #expect(retained.usedFraction == 0.95)
        #expect(retained.observedAt == earlier)
        #expect(retained.error != nil)
        #expect(
            partial.quotaWindows.first { $0.id == "rate_limit.secondary_window" }?.observedAt
                == earlier.addingTimeInterval(300))
        let repeated = response.accepting(
            at: earlier.addingTimeInterval(600),
            previous: Reading(usage: partial, fetchedAt: earlier.addingTimeInterval(300)))
        #expect(repeated.quotaWindows.first { $0.id == "rate_limit.primary_window" }?.observedAt == earlier)
        #expect(Dashboard.health(entry(partial), preferences: UserPreferences()) == .muted)
    }

    @Test func freshCriticalWindowStillSignalsInPartialAccount() {
        let usage = Usage.metrics(
            windows: [UsageWindow(label: "Week", usedFraction: 0.95, resetsAt: nil)], balances: [], plan: nil,
            failures: [MetricFailure(id: "other", error: .schemaChanged(detail: "other"))])
        #expect(Dashboard.health(entry(usage), preferences: UserPreferences()) == .critical)
    }

    @Test func similarGroupNamesDoNotReviveAnUnrelatedWindow() {
        let previous = Reading(
            usage: .metrics(
                windows: [
                    UsageWindow(
                        label: "Unrelated model", usedFraction: 0.9,
                        resetsAt: nil, group: "additional_rate_limits.model.long",
                        id: "additional_rate_limits.model.long.primary_window")
                ],
                balances: [], plan: nil, failures: []), fetchedAt: earlier)
        let response = Usage.metrics(
            windows: [], balances: [], plan: nil,
            failures: [MetricFailure(id: "additional_rate_limits.model", error: .schemaChanged(detail: "model"))])
        #expect(response.accepting(at: earlier.addingTimeInterval(300), previous: previous).quotaWindows.isEmpty)
    }

    @Test func declaredParentFailureRetainsItsOwnWindows() throws {
        let prior = try CodexAdapter.parse(
            Data(#"{"rate_limit":{"primary_window":{"used_percent":30},"secondary_window":{"used_percent":40}}}"#.utf8)
        )
        .accepting(at: earlier, previous: nil)
        let failed = try CodexAdapter.parse(Data(#"{"rate_limit":"broken"}"#.utf8))
        let merged = failed.accepting(
            at: earlier.addingTimeInterval(300), previous: Reading(usage: prior, fetchedAt: earlier))
        #expect(merged.quotaWindows.count == 2)
        #expect(merged.quotaWindows.allSatisfy { $0.error != nil && $0.observedAt == earlier })
    }

    @Test func optionalOmissionDoesNotReviveOldWindow() throws {
        let previous = Reading(
            usage: .windows(
                windows: [UsageWindow(label: "5h", usedFraction: 0.8, resetsAt: nil, id: "rate_limit.primary_window")],
                plan: nil), fetchedAt: earlier)
        let omitted = try CodexAdapter.parse(Data(#"{"rate_limit":null}"#.utf8))
        #expect(omitted.accepting(at: earlier.addingTimeInterval(300), previous: previous).quotaWindows.isEmpty)
    }

    @Test func currencyFailuresRetainOnlyThatCurrency() {
        let previous = Reading(
            usage: .metrics(
                windows: [], balances: [Balance(amount: 50, currency: "CNY", gift: nil)], plan: nil, failures: []),
            fetchedAt: earlier)
        let response = Usage.metrics(
            windows: [], balances: [Balance(amount: 20, currency: "USD", gift: nil)], plan: nil,
            failures: [MetricFailure(id: "balance.CNY", error: .schemaChanged(detail: "balance.CNY"))])
        let partial = response.accepting(at: earlier.addingTimeInterval(300), previous: previous)
        #expect(partial.balances.count == 2)
        #expect(partial.balances.first { $0.currency == "CNY" }?.observedAt == earlier)
        #expect(partial.balances.first { $0.currency == "USD" }?.error == nil)
    }

    private func entry(_ usage: Usage) -> AccountEntry {
        AccountEntry(
            account: Account(provider: .codex, credential: .manual),
            state: .partial(reading: Reading(usage: usage, fetchedAt: earlier.addingTimeInterval(300))))
    }
}
