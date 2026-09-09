import Foundation
import Testing

@testable import WaterlineKit

struct HeadlineTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func partialFailureDoesNotHideFreshQuota() {
        let usage = Usage.metrics(
            windows: [UsageWindow(label: "Main", usedFraction: 0.4, resetsAt: nil)],
            balances: [], plan: nil, failures: [MetricFailure(id: "extra", error: .permissionDenied)])
        let entry = row(.partial(reading: Reading(usage: usage, fetchedAt: now)))
        #expect(Dashboard.headline(Snapshot(generatedAt: now, accounts: [entry]), now: now) == .quota(0.4))
        #expect(Dashboard.health(entry, preferences: UserPreferences(), now: now) == .muted)
    }

    @Test func oldNumbersExpireEvenWithoutANewSnapshot() {
        let usage = Usage.windows(windows: [UsageWindow(label: "Week", usedFraction: 0.4, resetsAt: nil)], plan: nil)
        let entry = row(.fresh(reading: Reading(usage: usage, fetchedAt: now)))
        let snapshot = Snapshot(generatedAt: now, accounts: [entry])
        #expect(Dashboard.headline(snapshot, now: now.addingTimeInterval(601)) == .updated(now))
        #expect(Dashboard.health(entry, preferences: UserPreferences(), now: now.addingTimeInterval(601)) == .muted)
    }

    @Test func staleBalanceCannotWinHeadline() {
        let old = now.addingTimeInterval(-601)
        let usage = Usage.balance(balance: Balance(amount: 500, currency: "USD", gift: nil, observedAt: old))
        let entry = row(.partial(reading: Reading(usage: usage, fetchedAt: now)))
        #expect(Dashboard.balanceHeadline([entry], preferences: UserPreferences(), now: now) == nil)
    }

    @Test func emptyPendingDisabledAndUnsupportedStayDistinct() {
        #expect(Dashboard.headline(Snapshot(generatedAt: now, accounts: []), now: now) == .connect)
        let pending = row(.pending)
        #expect(Dashboard.headline(Snapshot(generatedAt: now, accounts: [pending]), now: now) == .checking)
        var preferences = UserPreferences()
        preferences.disabledProviders = [.codex]
        #expect(
            Dashboard.headline(Snapshot(generatedAt: now, accounts: [pending], preferences: preferences), now: now)
                == .paused)
        let unsupported = row(
            .fresh(reading: Reading(usage: .unsupported(reason: "No verified query"), fetchedAt: now)))
        #expect(Dashboard.headline(Snapshot(generatedAt: now, accounts: [unsupported]), now: now) == .unsupported)
    }

    private func row(_ state: AccountState) -> AccountEntry {
        AccountEntry(
            account: Account(id: AccountID(rawValue: "test"), provider: .codex, credential: .manual), state: state)
    }

    @Test func quotaSourceTracksWinnerAndStableTies() {
        func quota(_ id: String, _ provider: Provider, _ fraction: Double) -> AccountEntry {
            AccountEntry(
                account: Account(id: AccountID(rawValue: id), provider: provider, credential: .manual),
                state: .fresh(
                    reading: Reading(
                        usage: .windows(
                            windows: [UsageWindow(label: "5h", usedFraction: fraction, resetsAt: nil)], plan: nil),
                        fetchedAt: now)))
        }
        let codex = quota("a", .codex, 0.3)
        let claude = quota("b", .claudeCode, 0.7)
        let winner = Dashboard.headlineSelection(Snapshot(generatedAt: now, accounts: [codex, claude]), now: now)
        #expect(winner.value == .quota(0.7))
        #expect(winner.accountID == claude.account.id)
        let tied = quota("c", .cursor, 0.7)
        for accounts in [[tied, claude], [claude, tied]] {
            #expect(
                Dashboard.headlineSelection(Snapshot(generatedAt: now, accounts: accounts), now: now).accountID
                    == claude.account.id)
        }
        let expired = Dashboard.headlineSelection(
            Snapshot(generatedAt: now, accounts: [codex, claude]), now: now.addingTimeInterval(601))
        #expect(expired.accountID == nil)
        #expect(expired.value == .updated(now))
    }

    @Test func balanceSourceMatchesSelectedCurrencyWithoutAmountRanking() {
        let usd = AccountEntry(
            account: Account(id: AccountID(rawValue: "usd"), provider: .deepseek, credential: .manual),
            state: .fresh(
                reading: Reading(
                    usage: .balance(balance: Balance(amount: 40, currency: "USD", gift: nil)), fetchedAt: now)))
        let cny = AccountEntry(
            account: Account(id: AccountID(rawValue: "cny"), provider: .moonshot, credential: .manual),
            state: .fresh(
                reading: Reading(
                    usage: .balance(balance: Balance(amount: 2, currency: "CNY", gift: nil)), fetchedAt: now)))
        var preferences = UserPreferences()
        preferences.balanceThresholds = ["USD": 5, "CNY": 5]
        let selection = Dashboard.headlineSelection(
            Snapshot(generatedAt: now, accounts: [usd, cny], preferences: preferences), now: now)
        #expect(selection.accountID == cny.account.id)
        #expect(selection.value == .balance(Balance(amount: 2, currency: "CNY", gift: nil)))
        #expect(Dashboard.headlineSelection(Snapshot(generatedAt: now, accounts: []), now: now).accountID == nil)
    }
}
