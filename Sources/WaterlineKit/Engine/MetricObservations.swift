import Foundation

extension UsageWindow {
    func observed(at date: Date, error: FetchError? = nil) -> UsageWindow {
        UsageWindow(
            label: label, usedFraction: usedFraction, resetsAt: resetsAt, group: group, id: id,
            failureScopes: failureScopes,
            observedAt: observedAt ?? date, error: error ?? self.error, used: used, limit: limit, unit: unit,
            note: note, durationSeconds: durationSeconds, maximumAgeSeconds: maximumAgeSeconds
        )
    }
}

extension Balance {
    func observed(at date: Date, error: FetchError? = nil) -> Balance {
        Balance(
            amount: amount, currency: currency, gift: gift, observedAt: observedAt ?? date, error: error ?? self.error,
            basis: basis)
    }
}

extension Usage {
    /// Only explicit component failures revive a previous observation. Optional omissions do not.
    func accepting(at date: Date, previous: Reading?) -> Usage {
        let failures = componentFailures
        let planFailed = failures.contains {
            $0.id == "grok.subscription-plan" || $0.id == "antigravity.subscription-plan"
        }
        let acceptedPlan = planFailed ? previous?.usage.planLabel : planLabel
        var windows = quotaWindows.map { $0.observed(at: date) }
        var balances = balances.map { $0.observed(at: date) }
        if let previous {
            for old in previous.usage.quotaWindows {
                guard let id = old.id, !windows.contains(where: { $0.id == id }),
                    let failure = failures.first(where: { id == $0.id || old.failureScopes?.contains($0.id) == true })
                else { continue }
                windows.append(old.observed(at: previous.observedAt, error: failure.error))
            }
            for old in previous.usage.balances {
                let id = "balance.\(old.currency)"
                guard !balances.contains(where: { $0.currency == old.currency }),
                    let failure = failures.first(where: { id == $0.id || $0.id == "balance" })
                else { continue }
                balances.append(old.observed(at: previous.observedAt, error: failure.error))
            }
        }
        switch self {
        case .unsupported: return self
        case .balance:
            return .balance(balance: balances[0])
        case .windows: return .windows(windows: windows, plan: acceptedPlan)
        case .both: return .both(windows: windows, balance: balances[0])
        case .metrics: return .metrics(windows: windows, balances: balances, plan: acceptedPlan, failures: failures)
        }
    }
}
