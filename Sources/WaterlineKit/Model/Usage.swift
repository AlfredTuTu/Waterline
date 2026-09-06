import Foundation

/// One rolling quota window as the provider reports it.
public struct UsageWindow: Codable, Sendable, Hashable {
    /// Provider's own name for the window, e.g. "5h", "7d", "monthly".
    public let label: String
    /// 0...1
    public let usedFraction: Double
    public let resetsAt: Date

    public init(label: String, usedFraction: Double, resetsAt: Date) {
        self.label = label
        self.usedFraction = usedFraction
        self.resetsAt = resetsAt
    }
}

public struct Balance: Codable, Sendable, Hashable {
    public let amount: Decimal
    /// ISO 4217, e.g. "CNY", "USD".
    public let currency: String
    /// Granted/voucher portion when the provider reports it separately.
    public let gift: Decimal?

    public init(amount: Decimal, currency: String, gift: Decimal?) {
        self.amount = amount
        self.currency = currency
        self.gift = gift
    }
}

/// What an adapter returns. Only fields the provider actually reported; nothing is estimated here.
public enum Usage: Codable, Sendable, Hashable {
    case windows(windows: [UsageWindow], plan: String?)
    case balance(balance: Balance)
    case both(windows: [UsageWindow], balance: Balance)
    /// The provider has no usage or balance API.
    case unsupported(reason: String)
}
