import Foundation
import Testing

@testable import WaterlineKit

struct ThresholdAlertsTests {
    let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func balancesCrossAtCurrencyThresholdButPostedLedgerDoesNotAlert() {
        func reading(_ amount: Decimal, at offset: Double, basis: BalanceBasis? = nil) -> Snapshot {
            let date = epoch.addingTimeInterval(offset)
            let usage = Usage.balance(balance: Balance(amount: amount, currency: "USD", gift: nil, basis: basis))
            let row = AccountEntry(
                account: Account(id: AccountID(rawValue: "balance"), provider: .deepseek, credential: .manual),
                state: .fresh(reading: Reading(usage: usage, fetchedAt: date)))
            return Snapshot(generatedAt: date, accounts: [row], lastAttemptAt: date)
        }
        var ledger = ThresholdAlerts()
        ledger.enabled = true
        _ = ledger.evaluate(reading(11, at: 0))
        #expect(ledger.evaluate(reading(10, at: 1)).count == 1)
        var posted = ThresholdAlerts()
        posted.enabled = true
        _ = posted.evaluate(reading(11, at: 0, basis: .postedLedger))
        #expect(posted.evaluate(reading(0, at: 1, basis: .postedLedger)).isEmpty)
    }

    @Test func firstObservationAndRepeatedSnapshotDoNotNotify() {
        var ledger = ThresholdAlerts()
        ledger.enabled = true
        #expect(ledger.evaluate(snapshot(0.8, time: 0)).isEmpty)
        #expect(ledger.evaluate(snapshot(0.8, time: 0)).isEmpty)
        #expect(ledger.evaluate(snapshot(0.9, time: 1)).count == 1)
        #expect(ledger.evaluate(snapshot(0.9, time: 1)).isEmpty)
    }

    @Test func rateLimitSurvivesSerializationAndRequiresAnotherCrossing() throws {
        var ledger = ThresholdAlerts()
        ledger.enabled = true
        _ = ledger.evaluate(snapshot(0.6, time: 0))
        #expect(ledger.evaluate(snapshot(0.7, time: 1)).count == 1)
        let encoded = try JSONEncoder().encode(ledger)
        ledger = try JSONDecoder().decode(ThresholdAlerts.self, from: encoded)
        _ = ledger.evaluate(snapshot(0.5, time: 100))
        #expect(ledger.evaluate(snapshot(0.9, time: 3599)).isEmpty)
        #expect(ledger.evaluate(snapshot(0.9, time: 3601)).isEmpty)
        _ = ledger.evaluate(snapshot(0.5, time: 3602))
        #expect(ledger.evaluate(snapshot(0.7, time: 3603)).count == 1)
    }

    @Test func oldDisabledAndPolicyChangedDataDoNotTrigger() {
        var ledger = ThresholdAlerts()
        ledger.enabled = true
        _ = ledger.evaluate(snapshot(0.6, time: 10))
        #expect(ledger.evaluate(snapshot(0.9, time: 9)).isEmpty)
        #expect(ledger.evaluate(snapshot(0.9, time: 11, stale: true)).isEmpty)
        var preferences = UserPreferences()
        preferences.windowWarning = 0.5
        #expect(ledger.evaluate(snapshot(0.6, time: 12, preferences: preferences)).isEmpty)
        ledger.enabled = false
        #expect(ledger.evaluate(snapshot(0.95, time: 13, preferences: preferences)).isEmpty)
        ledger.enabled = true
        #expect(ledger.evaluate(snapshot(0.95, time: 14, preferences: preferences)).isEmpty)
    }

    @Test func independentMetricCrossingNotHiddenByHigherExistingMetric() {
        var ledger = ThresholdAlerts()
        ledger.enabled = true
        _ = ledger.evaluate(snapshot(0.95, time: 0, second: 0.2))
        let alerts = ledger.evaluate(snapshot(0.95, time: 1, second: 0.8))
        #expect(alerts.count == 1)
        #expect(alerts.first?.body.contains("Other") == true)
    }

    @Test func fileRestoresAndCorruptFileCannotBeOverwritten() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "alerts-\(UUID())/alerts.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ThresholdAlertStore(url: url)
        var value = ThresholdAlerts()
        value.enabled = true
        _ = value.evaluate(snapshot(0.2, time: 0))
        try store.save(value)
        #expect(try store.load() == value)
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: url)
        #expect(throws: (any Error).self) { try store.save(ThresholdAlerts()) }
        #expect(try Data(contentsOf: url) == corrupt)
    }

    private func snapshot(
        _ fraction: Double, time: TimeInterval, stale: Bool = false,
        preferences: UserPreferences = UserPreferences(), second: Double? = nil
    ) -> Snapshot {
        let date = epoch.addingTimeInterval(time)
        var windows = [UsageWindow(label: "Week", usedFraction: fraction, resetsAt: nil, id: "week", observedAt: date)]
        if let second {
            windows.append(
                UsageWindow(label: "Other", usedFraction: second, resetsAt: nil, id: "other", observedAt: date))
        }
        let reading = Reading(usage: .windows(windows: windows, plan: nil), fetchedAt: date)
        let entry = AccountEntry(
            account: Account(id: AccountID(rawValue: "synthetic-account"), provider: .codex, credential: .manual),
            state: stale ? .stale(reading: reading, error: .unauthorized) : .fresh(reading: reading))
        return Snapshot(generatedAt: date, accounts: [entry], preferences: preferences, lastAttemptAt: date)
    }
}
