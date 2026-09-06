import Foundation

public struct Reading: Codable, Sendable, Hashable {
    public let usage: Usage
    public let fetchedAt: Date

    public init(usage: Usage, fetchedAt: Date) {
        self.usage = usage
        self.fetchedAt = fetchedAt
    }
}

/// Why a fetch failed. Adapters throw these at their boundary; the engine never inspects raw errors.
public enum FetchError: Error, Codable, Sendable, Hashable {
    case credentialMissing
    /// Reading the secret would have shown a Keychain prompt; only a user-initiated connect may do that.
    case keychainLocked
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case schemaChanged(detail: String)
    case transport(detail: String)
}

/// Freshness is the engine's concern, not the adapter's.
public enum AccountState: Codable, Sendable, Hashable {
    case pending
    case fresh(reading: Reading)
    /// Last good reading plus the latest failure. Shown greyed with its age; never as zero.
    case stale(reading: Reading, error: FetchError)
    /// Never succeeded. Only the reason is shown.
    case unavailable(error: FetchError)

    public var reading: Reading? {
        switch self {
        case .fresh(let reading), .stale(let reading, _): reading
        case .pending, .unavailable: nil
        }
    }
}

public struct AccountEntry: Codable, Sendable, Hashable {
    public let account: Account
    public let state: AccountState

    public init(account: Account, state: AccountState) {
        self.account = account
        self.state = state
    }
}

/// The integration surface: what the app writes to disk and the CLI reads.
public struct Snapshot: Codable, Sendable, Hashable {
    public let generatedAt: Date
    public let accounts: [AccountEntry]

    public init(generatedAt: Date, accounts: [AccountEntry]) {
        self.generatedAt = generatedAt
        self.accounts = accounts
    }
}
