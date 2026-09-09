import Foundation
import Testing

@testable import WaterlineKit

struct BalanceHistoryTests {
    let id = AccountID(rawValue: "synthetic-history")
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    func observation(_ amount: Decimal, seconds: Double, currency: String = "USD") -> BalanceObservation {
        BalanceObservation(
            accountID: id, currency: currency, amount: amount, observedAt: start.addingTimeInterval(seconds))
    }
    @Test func exactDayProducesLabeledEstimateInputs() {
        let values = [observation(100, seconds: 0), observation(90, seconds: 86400)]
        let result = BalanceHistory.estimate(
            values, accountID: id, currency: "USD", now: start.addingTimeInterval(86400), latestIsFresh: true)
        #expect(result?.averageDecreasePerDay == 10)
        #expect(result?.estimatedDaysLeft == 9)
        #expect(
            BalanceHistory.estimate(
                values, accountID: id, currency: "USD", now: start.addingTimeInterval(86400), latestIsFresh: false)
                == nil)
    }
    @Test func shortSpanFlatBalanceAndTopUpDoNotInventForecasts() {
        for values in [
            [observation(100, seconds: 0), observation(90, seconds: 86399)],
            [observation(100, seconds: 0), observation(100, seconds: 86400)],
            [observation(100, seconds: 0), observation(90, seconds: 86400), observation(120, seconds: 90000)],
        ] {
            #expect(
                BalanceHistory.estimate(
                    values, accountID: id, currency: "USD", now: start.addingTimeInterval(90000), latestIsFresh: true)
                    == nil)
        }
    }
    @Test func currencySwitchStartsANewSegment() {
        let values = [
            observation(100, seconds: 0), observation(90, seconds: 86400),
            observation(20, seconds: 90000, currency: "CNY"), observation(80, seconds: 100000),
        ]
        #expect(
            BalanceHistory.estimate(
                values, accountID: id, currency: "USD", now: start.addingTimeInterval(100000), latestIsFresh: true)
                == nil)
    }
    @Test func sevenDayWindowExcludesOlderValuesAndTopUpCanBuildNewHistory() {
        let old = [observation(100, seconds: 0), observation(10, seconds: 8 * 86400)]
        #expect(
            BalanceHistory.estimate(
                old, accountID: id, currency: "USD", now: start.addingTimeInterval(8 * 86400), latestIsFresh: true)
                == nil)
        let toppedUp = [
            observation(100, seconds: 0), observation(90, seconds: 86400), observation(120, seconds: 90000),
            observation(110, seconds: 176400),
        ]
        #expect(
            BalanceHistory.estimate(
                toppedUp, accountID: id, currency: "USD", now: start.addingTimeInterval(176400), latestIsFresh: true)?
                .estimatedDaysLeft == 11)
    }

    @Test func simultaneousCurrenciesDoNotResetEachOther() {
        let values = [
            BalanceObservation(
                accountID: id, currency: "USD", amount: 100, observedAt: start, availableCurrencies: ["USD", "CNY"]),
            BalanceObservation(
                accountID: id, currency: "CNY", amount: 200, observedAt: start, availableCurrencies: ["USD", "CNY"]),
            BalanceObservation(
                accountID: id, currency: "USD", amount: 90, observedAt: start.addingTimeInterval(86400),
                availableCurrencies: ["USD", "CNY"]),
        ]
        #expect(
            BalanceHistory.estimate(
                values, accountID: id, currency: "USD", now: start.addingTimeInterval(86400), latestIsFresh: true)?
                .estimatedDaysLeft == 9)
    }

    @Test func debtHasNoDaysRemaining() {
        let values = [observation(10, seconds: 0), observation(-10, seconds: 86400)]
        let result = BalanceHistory.estimate(
            values, accountID: id, currency: "USD", now: start.addingTimeInterval(86400), latestIsFresh: true)
        #expect(result?.averageDecreasePerDay == 20)
        #expect(result?.estimatedDaysLeft == nil)
    }

    @Test func postedCreditInterruptsAvailableBalanceEstimates() {
        let posted = BalanceObservation(
            accountID: id, currency: "USD", amount: 80, observedAt: start.addingTimeInterval(2 * 86400),
            basis: .postedLedger)
        let before = [observation(100, seconds: 0), observation(90, seconds: 86400), posted]
        #expect(
            BalanceHistory.estimate(
                before, accountID: id, currency: "USD", now: posted.observedAt, latestIsFresh: true) == nil)
        let resumed = before + [observation(70, seconds: 3 * 86400)]
        #expect(
            BalanceHistory.estimate(
                resumed, accountID: id, currency: "USD", now: start.addingTimeInterval(3 * 86400),
                latestIsFresh: true) == nil)
        let complete = resumed + [observation(60, seconds: 4 * 86400)]
        let estimate = BalanceHistory.estimate(
            complete, accountID: id, currency: "USD", now: start.addingTimeInterval(4 * 86400), latestIsFresh: true)
        #expect(estimate?.averageDecreasePerDay == 10)
        #expect(estimate?.from == start.addingTimeInterval(3 * 86400))
        #expect(estimate?.estimatedDaysLeft == 6)
    }

    @Test func otherCurrencyPostedCreditDoesNotInterruptAvailableBalance() {
        let values = [
            observation(100, seconds: 0),
            BalanceObservation(
                accountID: id, currency: "CNY", amount: 200, observedAt: start.addingTimeInterval(40000),
                availableCurrencies: ["USD", "CNY"], basis: .postedLedger),
            observation(90, seconds: 86400),
        ]
        #expect(
            BalanceHistory.estimate(
                values, accountID: id, currency: "USD", now: start.addingTimeInterval(86400), latestIsFresh: true)?
                .averageDecreasePerDay == 10)
    }
    @Test func journalPreservesSubsecondsAndRejectsDamagedTail() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-history-\(UUID())/history.jsonl")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = HistoryStore(url: url)
        let values = [observation(100, seconds: 0.123), observation(90, seconds: 86400.456)]
        try store.append(values)
        let loaded = try store.load(since: start.addingTimeInterval(-1)).observations
        #expect(loaded.count == 2)
        #expect(abs(loaded[0].observedAt.timeIntervalSince(values[0].observedAt)) < 0.000001)
        let file = try FileHandle(forWritingTo: url); try file.seekToEnd();
        try file.write(contentsOf: Data("broken".utf8)); try file.close()
        #expect(throws: HistoryError.self) { try store.load(since: start) }
    }
}
