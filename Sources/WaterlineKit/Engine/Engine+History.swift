import Foundation

extension Engine {
    func loadHistory() {
        do {
            let loaded = try historyStore.load(since: dependencies.now().addingTimeInterval(-90 * 86400))
            historyRecords = loaded.observations
            if loaded.discardedOldRecords { try historyStore.compact(historyRecords) }
            historyKeys = Set(historyRecords.map(\.key))
            historyLoaded = true
            historyLoadError = nil
            historyFailed = false
            historyTailIncomplete = false
        } catch {
            historyLoadError =
                (error as? HistoryError) ?? (error is DecodingError ? .malformedRecord : .persistenceFailed)
            historyFailed = true
            historyLoaded = false
            if case HistoryError.incompleteTail = error {
                historyTailIncomplete = true
            } else {
                historyTailIncomplete = false
            }
        }
    }

    func recordHistory(_ state: AccountState, accountID: AccountID) {
        guard state.hasCurrentResponse, let reading = state.reading else { return }
        let currencies = reading.usage.balances.map(\.currency).sorted()
        for balance in reading.usage.balances where balance.error == nil {
            let record = BalanceObservation(
                accountID: accountID, currency: balance.currency, amount: balance.amount,
                observedAt: balance.observedAt ?? reading.observedAt, fetchedAt: reading.fetchedAt,
                availableCurrencies: currencies, basis: balance.basis)
            if !historyKeys.contains(record.key), !historyPending.contains(where: { $0.key == record.key }) {
                historyPending.append(record)
            }
        }
        flushHistory()
    }

    public func retryHistoryPersistence() throws {
        guard started else { throw SettingsError.engineNotStarted }
        if historyTailIncomplete { historyRepairNotice = try historyStore.recoverIncompleteTail() }
        if !historyLoaded { loadHistory() }
        flushHistory()
        try publish()
        if historyFailed { throw historyLoadError ?? HistoryError.persistenceFailed }
    }

    private func flushHistory() {
        guard !historyPending.isEmpty else { return }
        if !historyLoaded { loadHistory() }
        guard historyLoaded else { return }
        let pending = historyPending.filter { !historyKeys.contains($0.key) }
        let cutoff = dependencies.now().addingTimeInterval(-90 * 86400)
        let retained = historyRecords.filter { $0.observedAt >= cutoff }
        do {
            if retained.count != historyRecords.count {
                try historyStore.compact(retained + pending)
            } else {
                try historyStore.append(pending)
            }
            historyRecords = retained + pending
            historyKeys = Set(historyRecords.map(\.key))
            historyPending.removeAll()
            historyFailed = false
        } catch { historyFailed = true }
    }

    public func balanceHistory(for accountID: AccountID, period: HistoryPeriod = .week) -> [BalanceObservation] {
        let now = dependencies.now()
        return historyRecords.filter {
            $0.accountID == accountID && $0.observedAt <= now
                && $0.observedAt >= dependencies.now().addingTimeInterval(-Double(period.rawValue) * 86400)
        }
        .sorted { $0.observedAt < $1.observedAt }
    }
}
