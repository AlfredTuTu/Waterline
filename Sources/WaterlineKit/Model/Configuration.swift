import Foundation

public enum SettingsError: Error, Equatable {
    case invalidInterval
    case invalidThresholds
    case invalidLabel
    case accountNotFound
    case engineNotStarted
    case invalidAccountOrder
    case invalidNotchSelection
}

public struct AccountPreferences: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var pinned: Bool
    public var label: String?

    public init(enabled: Bool = true, pinned: Bool = false, label: String? = nil) {
        self.enabled = enabled
        self.pinned = pinned
        self.label = label
    }
}

public struct UserPreferences: Codable, Sendable, Hashable {
    public var refreshInterval: TimeInterval
    public var windowWarning: Double
    public var windowCritical: Double
    public var balanceThresholds: [String: Decimal]
    public var disabledProviders: Set<Provider>
    /// Absent in older configurations means no optional sources are enabled.
    public var enabledCredentialSources: Set<OptionalCredentialSource>?
    /// Nil selects automatically; an empty list explicitly shows no accounts.
    public var notchAccountIDs: [AccountID]?
    public var accountOrder: [AccountID]?

    public init(
        refreshInterval: TimeInterval = 300, windowWarning: Double = 0.7, windowCritical: Double = 0.9,
        balanceThresholds: [String: Decimal] = ["CNY": 50, "USD": 10], disabledProviders: Set<Provider> = [],
        enabledCredentialSources: Set<OptionalCredentialSource>? = nil, notchAccountIDs: [AccountID]? = nil,
        accountOrder: [AccountID]? = nil
    ) {
        self.refreshInterval = refreshInterval
        self.windowWarning = windowWarning
        self.windowCritical = windowCritical
        self.balanceThresholds = balanceThresholds
        self.disabledProviders = disabledProviders
        self.enabledCredentialSources = enabledCredentialSources
        self.notchAccountIDs = notchAccountIDs
        self.accountOrder = accountOrder
    }

    public func validate() throws {
        if let ids = accountOrder, Set(ids).count != ids.count { throw SettingsError.invalidAccountOrder }
        if let ids = notchAccountIDs, ids.count > 2 || Set(ids).count != ids.count {
            throw SettingsError.invalidNotchSelection
        }
        guard refreshInterval.isFinite, (60...3600).contains(refreshInterval) else {
            throw SettingsError.invalidInterval
        }
        guard windowWarning.isFinite, windowCritical.isFinite,
            0 < windowWarning, windowWarning < windowCritical, windowCritical <= 1,
            balanceThresholds.allSatisfy({ key, value in
                key.count == 3 && key.unicodeScalars.allSatisfy { (65...90).contains($0.value) }
                    && !value.isNaN && value > 0
            })
        else { throw SettingsError.invalidThresholds }
    }
}

struct ManagedAccount: Codable, Sendable, Hashable {
    var account: Account
    var preferences: AccountPreferences
    var credentialRevision: String? = nil
}

struct Configuration: Codable, Sendable {
    var schemaVersion = 5
    var preferences = UserPreferences()
    var accounts: [ManagedAccount] = []
    var removed: [Account] = []

    func validate() throws {
        guard (1...5).contains(schemaVersion) else { throw SnapshotStoreError.unsupportedVersion(schemaVersion) }
        try preferences.validate()
        guard Set(accounts.map(\.account.id)).count == accounts.count else {
            throw SettingsError.invalidLabel
        }
        for entry in accounts {
            if let label = entry.preferences.label, label.count > 80 || label.contains(where: \.isNewline) {
                throw SettingsError.invalidLabel
            }
        }
    }
}
