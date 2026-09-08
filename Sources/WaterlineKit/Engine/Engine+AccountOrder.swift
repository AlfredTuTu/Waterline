import Foundation

extension Engine {
    public func setAccountOrder(_ ids: [AccountID]?) throws {
        guard started else { throw SettingsError.engineNotStarted }
        if let ids {
            let known = Set(configuration.accounts.map(\.account.id))
            guard ids.count == known.count, Set(ids) == known else { throw SettingsError.invalidAccountOrder }
        }
        var next = configuration
        next.preferences.accountOrder = ids
        try saveConfiguration(next)
        try publish()
    }
}
