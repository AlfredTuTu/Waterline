import Foundation

extension Dashboard {
    public static func notchAccounts(_ snapshot: Snapshot) -> [AccountEntry] {
        if let ids = snapshot.preferences.notchAccountIDs {
            return Array(ids.compactMap { id in snapshot.accounts.first { $0.account.id == id } }.prefix(1))
        }
        return Array(
            ordered(snapshot.accounts, preferences: snapshot.preferences)
                .filter { $0.isEnabled(in: snapshot.preferences) }.prefix(1))
    }

    public static func overviewAccounts(_ snapshot: Snapshot, frozenIDs: [AccountID]? = nil) -> [AccountEntry] {
        let preferred = ordered(snapshot.accounts, preferences: snapshot.preferences)
        let stable = frozenIDs.map { preservingOrder(preferred, ids: $0) } ?? preferred
        let selected = snapshot.preferences.notchAccountIDs == nil ? [] : notchAccounts(snapshot)
        let selectedIDs = Set(selected.map(\.account.id))
        let remaining = stable.filter {
            !selectedIDs.contains($0.account.id) && $0.isEnabled(in: snapshot.preferences)
        }
        return Array((selected + remaining).prefix(4))
    }

    public static func accountHeadline(
        _ entry: AccountEntry, preferences: UserPreferences, now: Date
    ) -> DashboardHeadline {
        if entry.isEnabled(in: preferences), entry.state.hasCurrentResponse, let reading = entry.state.reading,
            now.timeIntervalSince(reading.observedAt) <= preferences.refreshInterval * 2,
            let window = overviewWindows(
                reading.usage, now: now, fallbackObservation: reading.observedAt,
                interval: preferences.refreshInterval, prioritizeCurrent: false
            ).first
        {
            guard
                window.isCurrent(
                    at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            else {
                if let reset = window.resetsAt, reset <= now { return .awaitingUpdate }
                return .updated(window.observedAt ?? reading.observedAt)
            }
            guard let fraction = window.usedFraction else { return .details }
            return .quota(fraction)
        }
        return headline(Snapshot(generatedAt: now, accounts: [entry], preferences: preferences), now: now)
    }
}
