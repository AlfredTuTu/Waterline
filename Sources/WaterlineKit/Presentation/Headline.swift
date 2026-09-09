import Foundation

public enum DashboardHeadline: Equatable, Sendable {
    case quota(Double)
    case balance(Balance)
    case updated(Date)
    case paused, checking, connect, attention, unsupported, details, awaitingUpdate
}

public struct DashboardHeadlineSelection: Equatable, Sendable {
    public let value: DashboardHeadline
    public let accountID: AccountID?
}

extension Dashboard {
    public static func headline(_ snapshot: Snapshot, now: Date) -> DashboardHeadline {
        headlineSelection(snapshot, now: now).value
    }

    public static func headlineSelection(_ snapshot: Snapshot, now: Date) -> DashboardHeadlineSelection {
        var source: AccountID?
        let value = resolveHeadline(snapshot, now: now, source: &source)
        return DashboardHeadlineSelection(value: value, accountID: source)
    }

    private static func resolveHeadline(_ snapshot: Snapshot, now: Date, source: inout AccountID?) -> DashboardHeadline
    {
        let active = snapshot.accounts.filter {
            $0.isEnabled(in: snapshot.preferences)
        }
        if active.isEmpty {
            if !snapshot.accounts.isEmpty { return .paused }
            return snapshot.sourceFailures.isEmpty ? .connect : .attention
        }
        let current = active.filter { entry in
            entry.state.hasCurrentResponse
                && entry.state.reading.map {
                    $0.isCurrent(at: now, interval: snapshot.preferences.refreshInterval)
                } == true
        }
        let fractions = current.flatMap { entry -> [(AccountID, Double)] in
            guard let reading = entry.state.reading else { return [] }
            return reading.usage.quotaWindows.filter {
                $0.isCurrent(
                    at: now, fallbackObservation: reading.observedAt, interval: snapshot.preferences.refreshInterval)
            }.compactMap(\.usedFraction).map { (entry.account.id, $0) }
        }
        if let highest = fractions.sorted(by: {
            $0.1 == $1.1 ? $0.0.rawValue < $1.0.rawValue : $0.1 > $1.1
        }).first {
            source = highest.0
            return .quota(highest.1)
        }
        if let selection = balanceHeadlineSelection(current, preferences: snapshot.preferences, now: now) {
            source = selection.0.id
            return .balance(selection.1)
        }
        if !snapshot.sourceFailures.isEmpty
            || active.contains(where: { entry in
                switch entry.state {
                case .stale, .unavailable: return true
                case .partial(let reading): return !reading.usage.componentFailures.isEmpty
                default: return false
                }
            })
        {
            return .attention
        }
        let hasPassedReset = active.contains { entry in
            entry.state.reading?.usage.quotaWindows.contains { $0.resetsAt.map { $0 <= now } ?? false } == true
        }
        let hasCurrentMetric = current.contains { entry in
            guard let reading = entry.state.reading else { return false }
            return reading.usage.quotaWindows.contains {
                $0.isCurrent(
                    at: now, fallbackObservation: reading.observedAt,
                    interval: snapshot.preferences.refreshInterval)
            }
                || reading.usage.balances.contains {
                    $0.isCurrent(
                        at: now, fallbackObservation: reading.observedAt, interval: snapshot.preferences.refreshInterval
                    )
                }
        }
        if hasPassedReset && !hasCurrentMetric { return .awaitingUpdate }
        if current.contains(where: { entry in
            guard let usage = entry.state.reading?.usage else { return false }
            if case .unsupported = usage { return false }
            return true
        }) {
            return .details
        }
        if let newest = active.compactMap({ $0.state.reading?.observedAt }).filter({
            now.timeIntervalSince($0) > snapshot.preferences.refreshInterval * 2
        }).max() {
            return .updated(newest)
        }
        if active.contains(where: { entry in
            if case .pending = entry.state { return true }
            return entry.operation != .idle
        }) {
            return .checking
        }
        if active.allSatisfy({ entry in
            if case .unsupported = entry.state.reading?.usage { return true }
            return false
        }) {
            return .unsupported
        }
        return .details
    }
}
