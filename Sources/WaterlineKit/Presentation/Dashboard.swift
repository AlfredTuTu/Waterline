import Foundation

/// Ordering uses comparable quota fractions or currency-specific health, never raw mixed currencies.
public enum Dashboard {
    public static func preservingOrder(_ entries: [AccountEntry], ids: [AccountID]) -> [AccountEntry] {
        let byID = Dictionary(entries.map { ($0.account.id, $0) }, uniquingKeysWith: { first, _ in first })
        var seen: Set<AccountID> = []
        return (ids + entries.map(\.account.id)).compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return byID[id]
        }
    }

    public static func ordered(
        _ entries: [AccountEntry], preferences: UserPreferences = UserPreferences(), now: Date = Date()
    ) -> [AccountEntry] {
        if let order = preferences.accountOrder { return preservingOrder(entries, ids: order) }
        return entries.sorted {
            let left = priority($0, preferences: preferences, now: now)
            let right = priority($1, preferences: preferences, now: now)
            if $0.isEnabled(in: preferences) && $1.isEnabled(in: preferences)
                && $0.preferences.pinned != $1.preferences.pinned
            {
                return $0.preferences.pinned
            }
            if left != right { return left > right }
            if $0.account.provider != $1.account.provider {
                return $0.account.provider.displayName < $1.account.provider.displayName
            }
            return $0.account.id.rawValue < $1.account.id.rawValue
        }
    }

    /// Keep provider groups together and place shorter known windows first within each group.
    public static func detailWindowGroups(_ usage: Usage) -> [[UsageWindow]] {
        var groups: [String] = []
        var windows: [String: [UsageWindow]] = [:]
        for window in usage.quotaWindows {
            let group = window.group ?? "primary"
            if windows[group] == nil { groups.append(group) }
            windows[group, default: []].append(window)
        }
        return groups.map { group in
            (windows[group] ?? []).enumerated().sorted { a, b in
                let left = a.element.cadenceSeconds ?? .infinity
                let right = b.element.cadenceSeconds ?? .infinity
                return left == right ? a.offset < b.offset : left < right
            }.map(\.element)
        }
    }

    public static func overviewWindows(
        _ usage: Usage, now: Date = Date(), fallbackObservation: Date? = nil,
        interval: TimeInterval = 300, prioritizeCurrent: Bool = true
    ) -> [UsageWindow] {
        let windows = usage.quotaWindows
        let primary = windows.filter { $0.group == nil || $0.group == "primary" }
        let candidates = primary.isEmpty ? windows : primary
        let durations = candidates.compactMap(\.cadenceSeconds)
        let completeCadence = durations.count == candidates.count
        let mixedCadence = !durations.isEmpty && !completeCadence
        return candidates.enumerated().sorted { lhs, rhs in
            let leftCurrent = lhs.element.isCurrent(
                at: now, fallbackObservation: fallbackObservation ?? now, interval: interval)
            let rightCurrent = rhs.element.isCurrent(
                at: now, fallbackObservation: fallbackObservation ?? now, interval: interval)
            if prioritizeCurrent && leftCurrent != rightCurrent { return leftCurrent }
            if completeCadence, let left = lhs.element.cadenceSeconds, let right = rhs.element.cadenceSeconds,
                left != right
            {
                return left < right
            }
            if mixedCadence { return lhs.offset < rhs.offset }
            let left = lhs.element.usedFraction ?? -1
            let right = rhs.element.usedFraction ?? -1
            return left == right ? lhs.offset < rhs.offset : left > right
        }.prefix(2).map(\.element)
    }

    public static func usageAmount(_ window: UsageWindow, locale: Locale = .current) -> String? {
        let used = window.used.map { $0.formatted(.number.locale(locale)) }
        let limit = window.limit.map { $0.formatted(.number.locale(locale)) }
        let suffix = window.unit.map { " \($0)" } ?? ""
        switch (used, limit) {
        case (.some(let used), .some(let limit)): return "\(used) / \(limit)\(suffix)"
        case (.some(let used), nil): return "\(used)\(suffix)"
        case (nil, .some(let limit)): return "Limit: \(limit)\(suffix)"
        case (nil, nil): return nil
        }
    }

    private static func priority(_ entry: AccountEntry, preferences: UserPreferences, now: Date) -> Int {
        guard entry.isEnabled(in: preferences) else {
            return 0
        }
        guard let reading = entry.state.reading, entry.state.hasCurrentResponse,
            now.timeIntervalSince(reading.observedAt) <= preferences.refreshInterval * 2
        else { return 2 }
        if let fraction = reading.usage.quotaWindows.filter({
            $0.isCurrent(
                at: now, fallbackObservation: reading.observedAt,
                interval: preferences.refreshInterval)
        }).compactMap(\.usedFraction).max() {
            if fraction >= preferences.windowCritical { return 4 }
            if fraction >= preferences.windowWarning { return 3 }
        }
        for balance in reading.usage.balances where balance.error == nil && balance.basis != .postedLedger {
            guard
                balance.isCurrent(
                    at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            else { continue }
            let threshold = preferences.balanceThresholds[balance.currency]
            if let threshold, balance.amount <= threshold { return 4 }
        }
        if !reading.usage.componentFailures.isEmpty
            || reading.usage.balances.contains(where: {
                !$0.isCurrent(at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            })
            || reading.usage.quotaWindows.contains(where: {
                !$0.isCurrent(at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            })
        {
            return 2
        }
        return 1
    }
}

public enum AccountHealth: Sendable { case muted, okay, warning, critical }

extension Dashboard {
    public static func health(_ entry: AccountEntry, preferences: UserPreferences, now: Date = Date()) -> AccountHealth
    {
        guard entry.isEnabled(in: preferences),
            let reading = entry.state.reading, entry.state.hasCurrentResponse,
            now.timeIntervalSince(reading.observedAt) <= preferences.refreshInterval * 2
        else { return .muted }
        let fraction = reading.usage.quotaWindows.filter {
            $0.isCurrent(at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
        }.compactMap(\.usedFraction).max()
        if let fraction, fraction >= preferences.windowCritical { return .critical }
        if reading.usage.balances.contains(where: { balance in
            balance.isCurrent(at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
                && balance.basis != .postedLedger
                && (preferences.balanceThresholds[balance.currency].map { balance.amount <= $0 } ?? false)
        }) {
            return .critical
        }
        if let fraction, fraction >= preferences.windowWarning { return .warning }
        if !reading.usage.componentFailures.isEmpty
            || reading.usage.quotaWindows.contains(where: {
                !$0.isCurrent(at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            })
            || reading.usage.balances.contains(where: {
                !$0.isCurrent(at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            })
        {
            return .muted
        }
        return fraction != nil
            || reading.usage.balances.contains {
                preferences.balanceThresholds[$0.currency] != nil && $0.basis != .postedLedger
            }
            ? .okay : .muted
    }
}

extension Dashboard {
    public static func balanceHeadline(
        _ entries: [AccountEntry], preferences: UserPreferences, now: Date = Date()
    ) -> Balance? {
        balanceHeadlineSelection(entries, preferences: preferences, now: now)?.1
    }

    static func balanceHeadlineSelection(
        _ entries: [AccountEntry], preferences: UserPreferences, now: Date
    ) -> (Account, Balance)? {
        let candidates = entries.flatMap { entry -> [(Account, Balance)] in
            guard entry.isEnabled(in: preferences),
                entry.state.hasCurrentResponse, let reading = entry.state.reading
            else { return [] }
            return reading.usage.balances.filter {
                $0.basis != .postedLedger
                    && $0.isCurrent(
                        at: now, fallbackObservation: reading.observedAt, interval: preferences.refreshInterval)
            }.map {
                (entry.account, $0)
            }
        }
        func rank(_ balance: Balance) -> Int {
            guard let threshold = preferences.balanceThresholds[balance.currency] else { return 2 }
            return balance.amount <= threshold ? 0 : 1
        }
        return candidates.sorted { lhs, rhs in
            let left = rank(lhs.1), right = rank(rhs.1)
            if left != right { return left < right }
            if lhs.0.provider != rhs.0.provider { return lhs.0.provider.displayName < rhs.0.provider.displayName }
            if lhs.0.id != rhs.0.id { return lhs.0.id.rawValue < rhs.0.id.rawValue }
            return lhs.1.currency < rhs.1.currency
        }.first
    }
}
