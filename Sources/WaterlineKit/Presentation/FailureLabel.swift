import Foundation

extension Usage {
    public func label(for failure: MetricFailure) -> String {
        var seen: Set<String> = []
        let labels = quotaWindows.filter { $0.id == failure.id || $0.failureScopes?.contains(failure.id) == true }
            .map(\.label).filter { seen.insert($0).inserted }
        if !labels.isEmpty { return labels.joined(separator: " / ") }
        if failure.id.hasPrefix("balance.") {
            let currency = String(failure.id.dropFirst("balance.".count))
            if currency.count == 3 && currency.utf8.allSatisfy({ (65...90).contains($0) }) { return currency }
            return "Balance"
        }
        return [
            "five_hour": "5h", "seven_day": "7d", "grok-bot": "Grok Bot",
            "legacy-requests": "Request quota", "rate_limit": "Main quota",
            "additional_rate_limits": "Additional quotas", "balance": "Balance",
            "individualUsage.plan": "Included quota", "individualUsage.onDemand": "On-demand usage",
            "individualUsage.overall": "Personal cap", "teamUsage.pooled": "Team pool",
            "teamUsage.onDemand": "Team on-demand",
        ][failure.id] ?? "Usage"
    }
}
