import Foundation

extension Engine {
    /// Accept a validated local callback without un-parking credentials or bypassing provider rate limits.
    @discardableResult
    public func receiveClaudeObservation(_ observation: ClaudeLocalObservation) throws -> Bool {
        guard started, !suspended else { return false }
        let now = dependencies.now()
        guard observation.receivedAt <= now,
            now.timeIntervalSince(observation.receivedAt) <= configuration.preferences.refreshInterval * 2,
            !observation.quotas.isEmpty
        else { return false }
        let matching = accounts.filter {
            $0.provider == .claudeCode && isEnabled($0.id)
                && $0.identity.map { ClaudeLocalLogin.matches(observation.identity, verified: $0) } == true
        }
        guard matching.count == 1, let account = matching.first else { return false }
        let previous = states[account.id]?.reading
        var windows = previous?.usage.quotaWindows ?? []
        var changed = false
        var replaced: Set<String> = []
        for quota in observation.quotas where quota.resetsAt > now {
            guard ["five_hour", "seven_day"].contains(quota.id), quota.usedFraction.isFinite,
                (0...1).contains(quota.usedFraction)
            else { throw FetchError.schemaChanged(detail: "claude.localQuota") }
            let existing = windows.firstIndex { $0.id == quota.id }
            if let existing,
                (windows[existing].observedAt ?? previous?.observedAt ?? .distantPast) >= observation.receivedAt
            {
                continue
            }
            let window = UsageWindow(
                label: quota.id == "five_hour" ? "5h" : "7d",
                usedFraction: quota.usedFraction, resetsAt: quota.resetsAt, id: quota.id,
                observedAt: observation.receivedAt, durationSeconds: quota.id == "five_hour" ? 18000 : 604800)
            if let existing { windows[existing] = window } else { windows.append(window) }
            changed = true
            replaced.insert(quota.id)
        }
        guard changed else { return false }
        invalidate(account.id)
        let usage = Usage.metrics(
            windows: windows, balances: previous?.usage.balances ?? [],
            plan: previous?.usage.planLabel ?? account.plan,
            failures: previous?.usage.componentFailures.filter { !replaced.contains($0.id) } ?? [])
        let reading = Reading(usage: usage, fetchedAt: now, observedAt: observation.receivedAt, origin: .local)
        states[account.id] = usage.componentFailures.isEmpty ? .fresh(reading: reading) : .partial(reading: reading)
        // Local progress buys a quiet interval; the server deadline and credential parking remain intact.
        schedules[account.id, default: RefreshSchedule()].nextAutomatic = max(
            schedules[account.id]?.nextAutomatic ?? .distantPast, now.addingTimeInterval(300))
        try publish()
        restartScheduler()
        return true
    }
}
