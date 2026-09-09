import Foundation

public struct BalanceObservation: Codable, Sendable, Hashable {
    public let accountID: AccountID
    public let currency: String
    public let basis: BalanceBasis?
    public let amount: Decimal
    public let observedAt: Date
    public let fetchedAt: Date
    public let availableCurrencies: [String]

    public init(
        accountID: AccountID, currency: String, amount: Decimal, observedAt: Date, fetchedAt: Date? = nil,
        availableCurrencies: [String]? = nil, basis: BalanceBasis? = nil
    ) {
        self.accountID = accountID
        self.currency = currency
        self.amount = amount
        self.basis = basis
        self.observedAt = observedAt
        self.fetchedAt = fetchedAt ?? observedAt
        self.availableCurrencies = availableCurrencies ?? [currency]
    }

    var key: BalanceObservationKey {
        BalanceObservationKey(accountID: accountID, currency: currency, time: observedAt.timeIntervalSince1970)
    }
}

struct BalanceObservationKey: Hashable {
    let accountID: AccountID
    let currency: String
    let time: TimeInterval
}

public struct BalanceEstimate: Codable, Sendable, Hashable {
    public let averageDecreasePerDay: Decimal
    public let estimatedDaysLeft: Decimal?
    public let from: Date
    public let through: Date
}

public enum BalanceHistory {
    public static func estimate(
        _ observations: [BalanceObservation], accountID: AccountID, currency: String, now: Date, latestIsFresh: Bool
    ) -> BalanceEstimate? {
        guard latestIsFresh else { return nil }
        let recent = observations.filter {
            $0.accountID == accountID
                && $0.observedAt >= now.addingTimeInterval(-7 * 86400) && $0.observedAt <= now
        }
        let segmentBreak = recent.filter {
            !$0.availableCurrencies.contains(currency) || ($0.currency == currency && $0.basis == .postedLedger)
        }.map(\.observedAt).max()
        var values = recent.filter {
            $0.currency == currency && $0.basis != .postedLedger
                && (segmentBreak == nil || $0.observedAt > segmentBreak!)
        }.sorted { $0.observedAt < $1.observedAt }
        guard values.count >= 2 else { return nil }
        var segmentStart = 0
        for index in 1..<values.count where values[index].amount > values[index - 1].amount { segmentStart = index }
        values = Array(values.dropFirst(segmentStart))
        guard let first = values.first, let last = values.last, values.count >= 2 else { return nil }
        let elapsed = last.observedAt.timeIntervalSince(first.observedAt)
        guard elapsed >= 86400 else { return nil }
        let decrease = first.amount - last.amount
        guard decrease > 0 else { return nil }
        let daily = decrease * 86400 / Decimal(elapsed)
        return BalanceEstimate(
            averageDecreasePerDay: daily, estimatedDaysLeft: last.amount >= 0 ? last.amount / daily : nil,
            from: first.observedAt, through: last.observedAt)
    }
}
