import Foundation
import Testing

@testable import WaterlineKit

struct DashboardTests {
    @Test func explicitDailyAccountRemainsVisibleBeyondTheOverviewLimit() {
        let rows = (0..<6).map { entry("account-\($0)", usage: .windows(windows: [], plan: nil)) }
        let selected = rows[5].account.id
        let snapshot = Snapshot(
            generatedAt: Date(), accounts: rows,
            preferences: UserPreferences(notchAccountIDs: [selected]))
        let visible = Dashboard.overviewAccounts(snapshot, frozenIDs: rows.map(\.account.id))
        #expect(visible.map(\.account.id) == [selected, rows[0].account.id, rows[1].account.id, rows[2].account.id])
        #expect(Set(visible.map(\.account.id)).count == 4)
    }

    @Test func selectedPausedAccountRemainsAvailableForRecovery() {
        let row = entry("paused", usage: .windows(windows: [], plan: nil))
        let preferences = UserPreferences(disabledProviders: [.deepseek], notchAccountIDs: [row.account.id])
        let selected = Snapshot(generatedAt: Date(), accounts: [row], preferences: preferences)
        #expect(Dashboard.overviewAccounts(selected).map(\.account.id) == [row.account.id])
        let automatic = Snapshot(
            generatedAt: Date(), accounts: [row], preferences: UserPreferences(disabledProviders: [.deepseek]))
        #expect(Dashboard.overviewAccounts(automatic).isEmpty)
    }

    @Test func dailySelectionShowsOnlyFirstLegacyAccountAndNeverSubstitutesAnother() {
        let first = entry("first", usage: .windows(windows: [], plan: nil))
        let second = entry("second", usage: .windows(windows: [], plan: nil))
        func selected(_ ids: [AccountID]?) -> [AccountID] {
            Dashboard.notchAccounts(
                Snapshot(
                    generatedAt: Date(), accounts: [second, first],
                    preferences: UserPreferences(notchAccountIDs: ids))
            ).map(\.account.id)
        }
        #expect(selected([first.account.id, second.account.id]) == [first.account.id])
        #expect(selected([AccountID(rawValue: "missing")]).isEmpty)
        #expect(selected([]).isEmpty)
        #expect(selected(nil).count == 1)
    }

    @Test func dailyHeadlineDoesNotSwitchToWeeklyAfterFiveHourReset() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let row = entry(
            "selected",
            usage: .windows(
                windows: [
                    UsageWindow(
                        label: "7d", usedFraction: 0.95, resetsAt: now.addingTimeInterval(3600), durationSeconds: 604800
                    ),
                    UsageWindow(label: "5h", usedFraction: 0.18, resetsAt: now, durationSeconds: 18000),
                ], plan: "Pro"))
        #expect(Dashboard.accountHeadline(row, preferences: UserPreferences(), now: now) == .awaitingUpdate)
    }

    @Test func dailyHeadlineUsesSelectedAccountsShortestPrimaryWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let row = entry(
            "selected",
            usage: .windows(
                windows: [
                    UsageWindow(
                        label: "7d", usedFraction: 0.95, resetsAt: now.addingTimeInterval(60), durationSeconds: 604800),
                    UsageWindow(
                        label: "5h", usedFraction: 0.18, resetsAt: now.addingTimeInterval(300), durationSeconds: 18000),
                    UsageWindow(label: "Model", usedFraction: 0.99, resetsAt: nil, group: "additional"),
                ], plan: "Pro"))
        #expect(Dashboard.accountHeadline(row, preferences: UserPreferences(), now: now) == .quota(0.18))
    }

    @Test func shortestCadenceComesBeforeHigherWeeklyUsageAndEarlierReset() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fiveHour = UsageWindow(
            label: "5h", usedFraction: 0.1, resetsAt: now.addingTimeInterval(14400), durationSeconds: 18000)
        let week = UsageWindow(
            label: "7d", usedFraction: 0.9, resetsAt: now.addingTimeInterval(60), durationSeconds: 604800)
        let usage = Usage.windows(windows: [week, fiveHour], plan: nil)
        #expect(Dashboard.overviewWindows(usage, now: now).map(\.label) == ["5h", "7d"])
        #expect(fiveHour.observed(at: now).durationSeconds == 18000)
    }
    @Test func expiredHighQuotaDoesNotDisplaceCurrentOverviewMetric() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expired = UsageWindow(label: "Earlier", usedFraction: 0.99, resetsAt: now.addingTimeInterval(-1))
        let current = UsageWindow(label: "Current", usedFraction: 0.2, resetsAt: now.addingTimeInterval(60))
        let usage = Usage.windows(windows: [expired, current], plan: nil)
        #expect(Dashboard.overviewWindows(usage, now: now).map(\.label) == ["Current", "Earlier"])
    }
    @Test func interactionFreezesPositionsButKeepsUpdatedValues() {
        let first = entry(
            "first",
            usage: .windows(windows: [UsageWindow(label: "Quota", usedFraction: 0.1, resetsAt: nil)], plan: nil))
        let second = entry(
            "second",
            usage: .windows(windows: [UsageWindow(label: "Quota", usedFraction: 0.95, resetsAt: nil)], plan: nil))
        let ordered = Dashboard.ordered([first, second])
        #expect(ordered.map(\.account.id) == [second.account.id, first.account.id])
        let frozen = Dashboard.preservingOrder(ordered, ids: [first.account.id, second.account.id])
        #expect(frozen.map(\.account.id) == [first.account.id, second.account.id])
        #expect(frozen[1].state.reading?.usage.quotaWindows.first?.usedFraction == 0.95)
    }

    @Test func frozenOrderDropsRemovedAccountsAndAppendsNewOnesOnce() {
        let existing = entry("existing", usage: .windows(windows: [], plan: nil))
        let added = entry("added", usage: .windows(windows: [], plan: nil))
        let result = Dashboard.preservingOrder(
            [added, existing], ids: [existing.account.id, AccountID(rawValue: "removed"), existing.account.id])
        #expect(result.map(\.account.id) == [existing.account.id, added.account.id])
    }
    @Test func uncappedUsageIsVisibleAndAmountsRespectLocale() {
        let uncapped = UsageWindow(label: "On-demand", usedFraction: nil, resetsAt: nil, used: 0, unit: "USD")
        #expect(Dashboard.usageAmount(uncapped, locale: Locale(identifier: "en_US")) == "0 USD")
        let amount = UsageWindow(
            label: "Spend", usedFraction: nil, resetsAt: nil,
            used: Decimal(string: "1234.5"), limit: 2000, unit: "USD")
        #expect(Dashboard.usageAmount(amount, locale: Locale(identifier: "en_US")) == "1,234.5 / 2,000 USD")
        #expect(Dashboard.usageAmount(amount, locale: Locale(identifier: "de_DE")) == "1.234,5 / 2.000 USD")
    }

    @Test func overviewPrioritizesFreshQuotaBeforeMoneyAndStaleMetrics() {
        let spend = UsageWindow(label: "Spend", usedFraction: nil, resetsAt: nil, used: 20, limit: 100, unit: "USD")
        let low = UsageWindow(label: "Auto", usedFraction: 0.1, resetsAt: nil)
        let high = UsageWindow(label: "API", usedFraction: 0.9, resetsAt: nil)
        let stale = UsageWindow(label: "Earlier", usedFraction: 1, resetsAt: nil, error: .permissionDenied)
        let usage = Usage.metrics(windows: [spend, stale, low, high], balances: [], plan: nil, failures: [])
        #expect(Dashboard.overviewWindows(usage).map(\.label) == ["API", "Auto"])
    }

    @Test func explanatoryNoteDoesNotMakeFreshAccountUnhealthy() {
        let quota = UsageWindow(label: "Included", usedFraction: 0.1, resetsAt: nil)
        let spend = UsageWindow(
            label: "Spend", usedFraction: nil, resetsAt: nil,
            used: 5, unit: "USD", note: "Reported spending")
        let row = entry("cursor", usage: .windows(windows: [quota, spend], plan: "pro"))
        #expect(Dashboard.health(row, preferences: UserPreferences()) == .okay)
    }

    @Test func configuredThresholdChangesHealth() {
        let row = entry(
            "account",
            usage: .windows(windows: [UsageWindow(label: "Week", usedFraction: 0.4, resetsAt: nil)], plan: nil))
        var preferences = UserPreferences()
        #expect(Dashboard.health(row, preferences: preferences) == .okay)
        preferences.windowWarning = 0.3
        #expect(Dashboard.health(row, preferences: preferences) == .warning)
        preferences.windowCritical = 0.4
        #expect(Dashboard.health(row, preferences: preferences) == .critical)
    }

    @Test func mixedCurrenciesUseHealthInsteadOfRawAmount() {
        let cny = entry("cny", usage: .balance(balance: Balance(amount: 40, currency: "CNY", gift: nil)))
        let usd = entry("usd", usage: .balance(balance: Balance(amount: 20, currency: "USD", gift: nil)))
        #expect(Dashboard.ordered([usd, cny]).first?.account.id == cny.account.id)
    }

    @Test func balanceHeadlineUsesHealthAndKeepsCurrenciesSeparate() {
        let healthy = entry("a", usage: .balance(balance: Balance(amount: 100, currency: "CNY", gift: nil)))
        let critical = entry("z", usage: .balance(balance: Balance(amount: 5, currency: "USD", gift: nil)))
        #expect(Dashboard.balanceHeadline([healthy, critical], preferences: UserPreferences())?.currency == "USD")
        #expect(Dashboard.balanceHeadline([healthy, critical], preferences: UserPreferences())?.amount == 5)
    }

    @Test func additionalBucketsDoNotCrowdAccountOverview() {
        let ordinary = UsageWindow(label: "Week", usedFraction: 0.31, resetsAt: nil, group: "primary")
        let additional = UsageWindow(label: "Special model", usedFraction: 0, resetsAt: nil, group: "additional")
        let usage = Usage.metrics(windows: [ordinary, additional], balances: [], plan: nil, failures: [])
        #expect(Dashboard.overviewWindows(usage) == [ordinary])
        #expect(usage.quotaWindows.count == 2)
    }

    @Test func elevenAccountsRemainAvailableInStableOrder() {
        let entries = (0..<11).map { entry(String(format: "%02d", $0), usage: .windows(windows: [], plan: nil)) }
        #expect(Dashboard.ordered(entries.reversed()).map(\.account.id) == entries.map(\.account.id))
    }

    private func entry(_ id: String, usage: Usage) -> AccountEntry {
        AccountEntry(
            account: Account(id: AccountID(rawValue: id), provider: .deepseek, credential: .manual),
            state: .fresh(reading: Reading(usage: usage, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000))))
    }
}
