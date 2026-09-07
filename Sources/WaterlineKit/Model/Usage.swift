import Foundation

/// One rolling quota window as the provider reports it.
public struct UsageWindow: Codable, Sendable, Hashable {
    /// Provider's own name for the window, e.g. "5h", "7d", "monthly".
    public let label: String
    public let note: String?
    public let used: Decimal?
    public let limit: Decimal?
    public let unit: String?
    public let group: String?
    public let id: String?
    public let failureScopes: [String]?
    public let observedAt: Date?
    public let error: FetchError?
    /// 0...1
    public let usedFraction: Double?
    public let resetsAt: Date?
    /// Reported quota cadence, independent of time remaining until reset.
    public let durationSeconds: TimeInterval?

    public var cadenceSeconds: TimeInterval? {
        if let durationSeconds, durationSeconds.isFinite, durationSeconds > 0 { return durationSeconds }
        // These stable provider IDs preserve ordering for snapshots written before cadence was stored.
        if id == "five_hour" { return 5 * 3600 }
        if id?.hasPrefix("seven_day") == true { return 7 * 86400 }
        return nil
    }

    public func isCurrent(at now: Date, fallbackObservation: Date, interval: TimeInterval) -> Bool {
        error == nil && now.timeIntervalSince(observedAt ?? fallbackObservation) <= interval * 2
            && (resetsAt.map { $0 > now } ?? true)
    }

    public init(
        label: String, usedFraction: Double?, resetsAt: Date?, group: String? = nil, id: String? = nil,
        failureScopes: [String]? = nil, observedAt: Date? = nil, error: FetchError? = nil, used: Decimal? = nil,
        limit: Decimal? = nil, unit: String? = nil, note: String? = nil, durationSeconds: TimeInterval? = nil
    ) {
        self.label = label
        self.note = note
        self.used = used
        self.limit = limit
        self.unit = unit
        self.group = group
        self.id = id
        self.failureScopes = failureScopes
        self.observedAt = observedAt
        self.error = error
        self.usedFraction = usedFraction
        self.resetsAt = resetsAt
        self.durationSeconds = durationSeconds
    }
}

public enum BalanceBasis: String, Codable, Sendable { case available, postedLedger }

public struct Balance: Codable, Sendable, Hashable {
    public let amount: Decimal
    public let basis: BalanceBasis?
    /// ISO 4217, e.g. "CNY", "USD".
    public let currency: String
    /// Granted/voucher portion when the provider reports it separately.
    public let gift: Decimal?
    public let observedAt: Date?
    public let error: FetchError?

    public func isCurrent(at now: Date, fallbackObservation: Date, interval: TimeInterval) -> Bool {
        error == nil && now.timeIntervalSince(observedAt ?? fallbackObservation) <= interval * 2
    }

    public init(
        amount: Decimal, currency: String, gift: Decimal?, observedAt: Date? = nil, error: FetchError? = nil,
        basis: BalanceBasis? = nil
    ) {
        self.amount = amount
        self.basis = basis
        self.currency = currency
        self.gift = gift
        self.observedAt = observedAt
        self.error = error
    }
}

/// What an adapter returns. Only fields the provider actually reported; nothing is estimated here.
public enum Usage: Codable, Sendable, Hashable {
    case metrics(windows: [UsageWindow], balances: [Balance], plan: String?, failures: [MetricFailure])
    case windows(windows: [UsageWindow], plan: String?)
    case balance(balance: Balance)
    case both(windows: [UsageWindow], balance: Balance)
    /// The provider has no usage or balance API.
    case unsupported(reason: String)
}

public struct MetricFailure: Codable, Sendable, Hashable {
    public let id: String
    public let error: FetchError

    public init(id: String, error: FetchError) {
        self.id = id
        self.error = error
    }
}

extension Usage {
    public var unsupportedReason: String? {
        if case .unsupported(let reason) = self { return reason }
        return nil
    }

    public var quotaWindows: [UsageWindow] {
        switch self {
        case .windows(let windows, _), .both(let windows, _), .metrics(let windows, _, _, _): windows
        case .balance, .unsupported: []
        }
    }

    public var balances: [Balance] {
        switch self {
        case .balance(let balance), .both(_, let balance): [balance]
        case .metrics(_, let balances, _, _): balances
        case .windows, .unsupported: []
        }
    }

    public var componentFailures: [MetricFailure] {
        if case .metrics(_, _, _, let failures) = self { return failures }
        return []
    }
}

extension Usage {
    public var planLabel: String? {
        switch self {
        case .windows(_, let plan), .metrics(_, _, let plan, _): plan
        case .balance, .both, .unsupported: nil
        }
    }
}
