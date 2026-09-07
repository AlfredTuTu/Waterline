import Foundation

public struct ThresholdAlert: Sendable {
    public let accountID: AccountID
    public let title: String
    public let metricNames: [String]
    public var body: String { metricNames.joined(separator: ", ") + " reached a usage threshold." }
}

/// Persisted crossing baselines and attempt times; no credentials or raw provider data.
public struct ThresholdAlerts: Codable, Equatable, Sendable {
    public var enabled = false
    private var schemaVersion = 1
    private var accounts: [String: AccountBaseline] = [:]
    private var policy: Policy?

    public init() {}

    public func validate() throws {
        guard schemaVersion == 1 else { throw SnapshotStoreError.unsupportedVersion(schemaVersion) }
    }

    public mutating func evaluate(_ snapshot: Snapshot) -> [ThresholdAlert] {
        let nextPolicy = Policy(preferences: snapshot.preferences)
        let policyChanged = policy != nextPolicy
        policy = nextPolicy
        let ids = Set(snapshot.accounts.map { $0.account.id.rawValue })
        accounts = accounts.filter { ids.contains($0.key) }
        if policyChanged {
            for id in accounts.keys { accounts[id]?.metrics = [:] }
        }
        var alerts: [ThresholdAlert] = []
        for entry in snapshot.accounts {
            guard entry.isEnabled(in: snapshot.preferences),
                entry.state.hasCurrentResponse, let reading = entry.state.reading
            else { continue }
            let id = entry.account.id.rawValue
            var baseline = accounts[id] ?? AccountBaseline()
            var crossed: [String] = []
            var metrics: [(String, String, Int, Date)] = []
            for (index, window) in reading.usage.quotaWindows.enumerated() where window.error == nil {
                guard
                    window.isCurrent(
                        at: snapshot.generatedAt, fallbackObservation: reading.observedAt,
                        interval: snapshot.preferences.refreshInterval)
                else { continue }
                guard let fraction = window.usedFraction else { continue }
                let severity = fraction >= nextPolicy.critical ? 2 : fraction >= nextPolicy.warning ? 1 : 0
                metrics.append(
                    (
                        "quota:" + (window.id ?? "\(index):\(window.label)"), window.label,
                        severity, window.observedAt ?? reading.observedAt
                    ))
            }
            for balance in reading.usage.balances where balance.error == nil && balance.basis != .postedLedger {
                guard
                    balance.isCurrent(
                        at: snapshot.generatedAt, fallbackObservation: reading.observedAt,
                        interval: snapshot.preferences.refreshInterval)
                else { continue }
                guard let threshold = nextPolicy.balances[balance.currency] else { continue }
                metrics.append(
                    (
                        "balance:" + balance.currency, balance.currency + " balance",
                        balance.amount <= threshold ? 2 : 0, balance.observedAt ?? reading.observedAt
                    ))
            }
            for (key, label, severity, observedAt) in metrics {
                let previous = baseline.metrics[key]
                guard previous.map({ observedAt > $0.observedAt }) ?? true else { continue }
                if !policyChanged, let previous, severity > previous.severity, severity > 0 { crossed.append(label) }
                baseline.metrics[key] = MetricBaseline(severity: severity, observedAt: observedAt)
            }
            if enabled, !crossed.isEmpty,
                baseline.lastAttempt.map({ snapshot.generatedAt.timeIntervalSince($0) >= 3600 }) ?? true
            {
                baseline.lastAttempt = snapshot.generatedAt
                alerts.append(
                    ThresholdAlert(
                        accountID: entry.account.id,
                        title: entry.preferences.label ?? entry.account.provider.displayName,
                        metricNames: crossed))
            }
            accounts[id] = baseline
        }
        return alerts
    }

    private struct AccountBaseline: Codable, Equatable, Sendable {
        var metrics: [String: MetricBaseline] = [:]
        var lastAttempt: Date?
    }
    private struct MetricBaseline: Codable, Equatable, Sendable { let severity: Int; let observedAt: Date }
    private struct Policy: Codable, Equatable, Sendable {
        let warning: Double
        let critical: Double
        let balances: [String: Decimal]
        init(preferences: UserPreferences) {
            warning = preferences.windowWarning
            critical = preferences.windowCritical
            balances = preferences.balanceThresholds
        }
    }
}

public struct ThresholdAlertStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> ThresholdAlerts {
        guard FileManager.default.fileExists(atPath: url.path) else { return ThresholdAlerts() }
        let value = try SnapshotStore.decoder.decode(ThresholdAlerts.self, from: Data(contentsOf: url))
        try value.validate()
        return value
    }
    public func save(_ value: ThresholdAlerts) throws {
        _ = try load()
        try value.validate()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try SnapshotStore.encoder.encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
