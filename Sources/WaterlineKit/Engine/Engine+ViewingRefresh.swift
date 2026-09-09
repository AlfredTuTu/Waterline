import Foundation

extension Engine {
    public func setUserActive(_ active: Bool) {
        guard !Task.isCancelled, userActive != active else { return }
        userActive = active
        if active { requestSoonerRefresh(minimumInterval: 60, windowsOnly: true) }
    }

    public func refreshWhenViewed() {
        guard started, !suspended else { return }
        requestSoonerRefresh(minimumInterval: 15)
    }

    private func requestSoonerRefresh(minimumInterval: TimeInterval, windowsOnly: Bool = false) {
        let now = dependencies.now()
        for account in accounts where isEnabled(account.id) {
            if windowsOnly, let adapter = adapters[account.provider], type(of: adapter).descriptor.kind == .balance {
                continue
            }
            var schedule = schedules[account.id, default: RefreshSchedule()]
            schedule.requestSooner(
                at: now, lastFetchedAt: states[account.id]?.reading?.fetchedAt,
                minimumInterval: account.provider == .claudeCode ? max(300, minimumInterval) : minimumInterval)
            schedules[account.id] = schedule
        }
        restartScheduler()
    }
}
