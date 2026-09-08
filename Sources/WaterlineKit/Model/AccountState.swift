import Foundation

public struct Reading: Codable, Sendable, Hashable {
    public let usage: Usage
    public let fetchedAt: Date
    public let observedAt: Date
    public let origin: ObservationOrigin

    public init(usage: Usage, fetchedAt: Date, observedAt: Date? = nil, origin: ObservationOrigin = .live) {
        self.usage = usage
        self.fetchedAt = fetchedAt
        self.observedAt = observedAt ?? fetchedAt
        self.origin = origin
    }

    enum CodingKeys: String, CodingKey { case usage, fetchedAt, observedAt, origin }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        usage = try values.decode(Usage.self, forKey: .usage)
        fetchedAt = try values.decode(Date.self, forKey: .fetchedAt)
        observedAt = try values.decodeIfPresent(Date.self, forKey: .observedAt) ?? fetchedAt
        origin = try values.decodeIfPresent(ObservationOrigin.self, forKey: .origin) ?? .legacy
    }

}

public enum ObservationOrigin: String, Codable, Sendable { case live, local, legacy, verification }

/// Why a fetch failed. Adapters throw these at their boundary; the engine never inspects raw errors.
public enum FetchError: Error, Codable, Sendable, Hashable {
    case credentialMissing
    case localServiceUnavailable
    /// Reading the secret would have shown a Keychain prompt; only a user-initiated connect may do that.
    case keychainLocked
    case unauthorized
    case permissionDenied
    case rateLimited(retryAfter: TimeInterval?)
    case schemaChanged(detail: String)
    case transport(detail: String)
}

/// Freshness is the engine's concern, not the adapter's.
public enum AccountState: Codable, Sendable, Hashable {
    case pending
    case fresh(reading: Reading)
    case partial(reading: Reading)
    case expired(reading: Reading)
    /// Last good reading plus the latest failure. Shown greyed with its age; never as zero.
    case stale(reading: Reading, error: FetchError)
    /// Never succeeded. Only the reason is shown.
    case unavailable(error: FetchError)

    public var reading: Reading? {
        switch self {
        case .fresh(let reading), .partial(let reading), .expired(let reading), .stale(let reading, _): reading
        case .pending, .unavailable: nil
        }
    }
}

public enum AccountOperation: String, Codable, Sendable { case idle, refreshing, connecting }

public struct AccountEntry: Codable, Sendable, Hashable {
    public let account: Account
    public let state: AccountState
    public let preferences: AccountPreferences
    public let schedule: RefreshSchedule?
    public let operation: AccountOperation

    public init(
        account: Account, state: AccountState, preferences: AccountPreferences = AccountPreferences(),
        operation: AccountOperation = .idle, schedule: RefreshSchedule? = nil
    ) {
        self.account = account
        self.state = state
        self.preferences = preferences
        self.operation = operation
        self.schedule = schedule
    }

    enum CodingKeys: String, CodingKey { case account, state, preferences, operation, schedule }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        account = try values.decode(Account.self, forKey: .account)
        state = try values.decode(AccountState.self, forKey: .state)
        preferences = try values.decodeIfPresent(AccountPreferences.self, forKey: .preferences) ?? AccountPreferences()
        operation = try values.decodeIfPresent(AccountOperation.self, forKey: .operation) ?? .idle
        schedule = try values.decodeIfPresent(RefreshSchedule.self, forKey: .schedule)
    }

}

/// The integration surface: what the app writes to disk and the CLI reads.
public struct SourceFailure: Codable, Sendable, Hashable {
    public let provider: Provider
    public let error: FetchError

    public init(provider: Provider, error: FetchError) {
        self.provider = provider
        self.error = error
    }
}

public struct Snapshot: Codable, Sendable, Hashable {
    public static let currentVersion = 13
    public let schemaVersion: Int
    public let generatedAt: Date
    public let accounts: [AccountEntry]
    public let sourceFailures: [SourceFailure]
    public let storageFailed: Bool
    public let preferences: UserPreferences
    public let lastAttemptAt: Date?
    public let pendingSecretCleanup: Int
    public let historyRepairNotice: String?
    public let historyFailed: Bool

    public init(
        generatedAt: Date, accounts: [AccountEntry], sourceFailures: [SourceFailure] = [],
        storageFailed: Bool = false, preferences: UserPreferences = UserPreferences(), lastAttemptAt: Date? = nil,
        pendingSecretCleanup: Int = 0, historyFailed: Bool = false, historyRepairNotice: String? = nil
    ) {
        schemaVersion = Self.currentVersion
        self.generatedAt = generatedAt
        self.accounts = accounts
        self.sourceFailures = sourceFailures
        self.storageFailed = storageFailed
        self.preferences = preferences
        self.lastAttemptAt = lastAttemptAt
        self.pendingSecretCleanup = pendingSecretCleanup
        self.historyFailed = historyFailed
        self.historyRepairNotice = historyRepairNotice
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, accounts, sourceFailures, storageFailed, preferences, lastAttemptAt,
            pendingSecretCleanup, historyFailed, historyRepairNotice
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        guard (0...Self.currentVersion).contains(schemaVersion) else {
            throw SnapshotStoreError.unsupportedVersion(schemaVersion)
        }
        generatedAt = try values.decode(Date.self, forKey: .generatedAt)
        accounts = try values.decode([AccountEntry].self, forKey: .accounts)
        sourceFailures = try values.decodeIfPresent([SourceFailure].self, forKey: .sourceFailures) ?? []
        storageFailed = try values.decodeIfPresent(Bool.self, forKey: .storageFailed) ?? false
        preferences = try values.decodeIfPresent(UserPreferences.self, forKey: .preferences) ?? UserPreferences()
        lastAttemptAt = try values.decodeIfPresent(Date.self, forKey: .lastAttemptAt)
        pendingSecretCleanup = try values.decodeIfPresent(Int.self, forKey: .pendingSecretCleanup) ?? 0
        historyFailed = try values.decodeIfPresent(Bool.self, forKey: .historyFailed) ?? false
        historyRepairNotice = try values.decodeIfPresent(String.self, forKey: .historyRepairNotice)
    }
}

extension AccountState {
    public var hasCurrentResponse: Bool {
        switch self {
        case .fresh, .partial: true;
        default: false
        }
    }
}

extension FetchError {
    public var message: String {
        switch self {
        case .credentialMissing: "Saved login not found"
        case .keychainLocked: "Permission needed to read the saved login"
        case .unauthorized: "Sign in again to reconnect"
        case .permissionDenied: "Access permission is required"
        case .rateLimited: "Provider asked us to wait before refreshing"
        case .schemaChanged: "Usage format changed"
        case .localServiceUnavailable: "Open Antigravity CLI with this account to refresh."
        case .transport: "Could not reach the provider"
        }
    }

    public var needsConnect: Bool {
        switch self {
        case .credentialMissing, .keychainLocked, .unauthorized, .permissionDenied: true;
        default: false
        }
    }
}
