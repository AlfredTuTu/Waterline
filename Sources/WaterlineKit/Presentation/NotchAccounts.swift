import Foundation

extension Dashboard {
    public static func movingAccount(_ source: AccountID, onto target: AccountID, in ids: [AccountID]) -> [AccountID]? {
        guard let from = ids.firstIndex(of: source), let to = ids.firstIndex(of: target) else { return nil }
        var result = ids
        result.remove(at: from)
        result.insert(source, at: to)
        return result
    }

    /// The compact headline has no running countdown. Only freshness and reset boundaries change it without new data.
    public static func notchHeadlineUpdateDates(_ snapshot: Snapshot, after now: Date) -> [Date] {
        let age = snapshot.preferences.refreshInterval * 2
        let deadlines = notchAccounts(snapshot).flatMap { entry -> [Date] in
            guard let reading = entry.state.reading else { return [] }
            var dates = [reading.observedAt.addingTimeInterval(age + 0.001)]
            for window in reading.usage.quotaWindows {
                dates.append(
                    (window.observedAt ?? reading.observedAt).addingTimeInterval(
                        (window.maximumAgeSeconds ?? age) + 0.001))
                if let reset = window.resetsAt { dates.append(reset) }
            }
            for balance in reading.usage.balances {
                dates.append((balance.observedAt ?? reading.observedAt).addingTimeInterval(age + 0.001))
            }
            return dates
        }
        return [now] + Set(deadlines.filter { $0 > now }).sorted()
    }

    public static func notchAccounts(_ snapshot: Snapshot) -> [AccountEntry] {
        if let ids = snapshot.preferences.notchAccountIDs {
            return Array(ids.compactMap { id in snapshot.accounts.first { $0.account.id == id } }.prefix(1))
        }
        return Array(
            overviewAccounts(snapshot)
                .filter { $0.isEnabled(in: snapshot.preferences) }.prefix(1))
    }

    public static func overviewAccounts(_ snapshot: Snapshot, frozenIDs: [AccountID]? = nil) -> [AccountEntry] {
        preservingOrder(snapshot.accounts, ids: snapshot.preferences.accountOrder ?? [])
    }

    public static func accountHeadline(
        _ entry: AccountEntry, preferences: UserPreferences, now: Date
    ) -> DashboardHeadline {
        if entry.isEnabled(in: preferences), entry.state.hasCurrentResponse, let reading = entry.state.reading,
            reading.isCurrent(at: now, interval: preferences.refreshInterval),
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
