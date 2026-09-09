import Foundation

extension Engine {
    public func setNotchAccounts(_ ids: [AccountID]?) async throws {
        guard started else { throw SettingsError.engineNotStarted }
        if let ids, ids.count > 1 { throw SettingsError.invalidNotchSelection }
        if let ids, !ids.allSatisfy({ id in accounts.contains { $0.id == id } }) { throw SettingsError.accountNotFound }
        var preferences = configuration.preferences
        preferences.notchAccountIDs = ids
        try await updatePreferences(preferences)
    }

    public func toggleNotchAccount(_ id: AccountID) async throws {
        guard started else { throw SettingsError.engineNotStarted }
        let selected = Dashboard.notchAccounts(snapshot()).first?.account.id
        try await setNotchAccounts(selected == id ? [] : [id])
    }
}
