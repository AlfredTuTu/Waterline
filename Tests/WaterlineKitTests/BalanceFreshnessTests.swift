import Foundation
import Testing

@testable import WaterlineKit

struct BalanceFreshnessTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func staleLowBalanceDoesNotOverrideCurrentQuotaHealth() {
        let snapshot = snapshot(amount: 5, observation: start, now: start.addingTimeInterval(601), window: true)
        #expect(Dashboard.headline(snapshot, now: snapshot.generatedAt) == .quota(0.2))
        #expect(
            Dashboard.health(snapshot.accounts[0], preferences: snapshot.preferences, now: snapshot.generatedAt)
                == .muted)
        #expect(
            Dashboard.balanceHeadline(snapshot.accounts, preferences: snapshot.preferences, now: snapshot.generatedAt)
                == nil)
        let warning = AccountEntry(
            account: Account(provider: .codex, credential: .manual),
            state: .fresh(
                reading: Reading(
                    usage: .windows(windows: [UsageWindow(label: "Week", usedFraction: 0.8, resetsAt: nil)], plan: nil),
                    fetchedAt: snapshot.generatedAt)))
        #expect(
            Dashboard.ordered(snapshot.accounts + [warning], now: snapshot.generatedAt).first?.account.id
                == warning.account.id)
    }

    @Test func failedBalanceIsNotHealthyWithoutAnExplicitFailureList() {
        let balance = Balance(amount: 100, currency: "USD", gift: nil, observedAt: start, error: .permissionDenied)
        let row = AccountEntry(
            account: Account(provider: .deepseek, credential: .manual),
            state: .partial(reading: Reading(usage: .balance(balance: balance), fetchedAt: start)))
        #expect(Dashboard.health(row, preferences: UserPreferences(), now: start) == .muted)
    }

    private func snapshot(amount: Decimal, observation: Date, now: Date, window: Bool = false) -> Snapshot {
        let usage = Usage.metrics(
            windows: window ? [UsageWindow(label: "Quota", usedFraction: 0.2, resetsAt: nil)] : [],
            balances: [Balance(amount: amount, currency: "USD", gift: nil, observedAt: observation)], plan: nil,
            failures: [])
        let entry = AccountEntry(
            account: Account(id: AccountID(rawValue: "balance"), provider: .deepseek, credential: .manual),
            state: .fresh(reading: Reading(usage: usage, fetchedAt: now)))
        return Snapshot(generatedAt: now, accounts: [entry], lastAttemptAt: now)
    }
}
