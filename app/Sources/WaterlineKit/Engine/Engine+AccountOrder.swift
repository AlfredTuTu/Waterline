import Foundation

extension Engine {
    public func setAccountOrder(_ ids: [AccountID]?, visibleProviders: Set<Provider>? = nil) throws {
        guard started else { throw SettingsError.engineNotStarted }
        if let ids {
            let known = Set(
                configuration.accounts.filter { visibleProviders?.contains($0.account.provider) ?? true }.map(
                    \.account.id))
            guard ids.count == known.count, Set(ids) == known else { throw SettingsError.invalidAccountOrder }
        }
        var next = configuration
        if let ids, let visibleProviders {
            let ordered = Dashboard.preservingOrder(
                snapshot().accounts, ids: configuration.preferences.accountOrder ?? [])
            let visible = ordered.filter { visibleProviders.contains($0.account.provider) }.map(\.account.id)
            let replacements = Dictionary(uniqueKeysWithValues: zip(visible, ids))
            next.preferences.accountOrder = ordered.map { replacements[$0.account.id] ?? $0.account.id }
        } else {
            next.preferences.accountOrder = ids
        }
        try saveConfiguration(next)
        try publish()
    }
}
