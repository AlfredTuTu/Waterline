import Foundation

/// Per-account deadlines. A manual action cannot bypass a server deadline or expired authentication.
public struct RefreshSchedule: Codable, Sendable, Hashable {
    public internal(set) var nextAutomatic: Date = .distantPast
    public internal(set) var serverDeadline: Date?
    public internal(set) var parked = false
    public internal(set) var authenticationParked = false
    private var failures = 0

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case nextAutomatic, serverDeadline, parked, failures, authenticationParked
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        nextAutomatic = try values.decode(Date.self, forKey: .nextAutomatic)
        serverDeadline = try values.decodeIfPresent(Date.self, forKey: .serverDeadline)
        parked = try values.decode(Bool.self, forKey: .parked)
        authenticationParked = try values.decodeIfPresent(Bool.self, forKey: .authenticationParked) ?? parked
        failures = try values.decode(Int.self, forKey: .failures)
        guard (0...6).contains(failures) else { throw FetchError.schemaChanged(detail: "schedule.failures") }
    }

    func eligible(at now: Date, manual: Bool, resetAt: Date? = nil) -> Bool {
        !parked && (serverDeadline.map { now >= $0 } ?? true)
            && (manual || nextAutomaticDate(resetAt: resetAt).map { now >= $0 } == true)
    }

    func nextAutomaticDate(resetAt: Date? = nil) -> Date? {
        guard !parked else { return nil }
        var next = nextAutomatic
        if failures == 0, let resetAt { next = min(next, resetAt) }
        if let serverDeadline { next = max(next, serverDeadline) }
        return next
    }

    mutating func succeeded(at now: Date, interval: TimeInterval) {
        failures = 0
        parked = false
        authenticationParked = false
        serverDeadline = nil
        nextAutomatic = now.addingTimeInterval(interval)
    }

    mutating func requestSooner(at now: Date, lastFetchedAt: Date?, minimumInterval: TimeInterval) {
        guard failures == 0, !parked else { return }
        let earliest = lastFetchedAt?.addingTimeInterval(minimumInterval) ?? now
        nextAutomatic = min(nextAutomatic, max(now, earliest))
    }

    mutating func failed(_ error: FetchError, at now: Date) {
        failures = min(6, failures + 1)
        let fallback = min(1800, 60 * pow(2, Double(min(failures - 1, 5))))
        nextAutomatic = now.addingTimeInterval(fallback)
        switch error {
        case .unauthorized, .permissionDenied:
            authenticationParked = true
            parked = true
        case .credentialMissing, .keychainLocked:
            parked = true
        case .rateLimited(let delay):
            serverDeadline = delay.map { now.addingTimeInterval($0) }
            if let serverDeadline { nextAutomatic = max(nextAutomatic, serverDeadline) }
        case .schemaChanged, .transport, .localServiceUnavailable:
            break
        }
    }

    mutating func partiallySucceeded(at now: Date, interval: TimeInterval, errors: [FetchError]) {
        succeeded(at: now, interval: interval)
        let retryDelays = errors.compactMap { error -> TimeInterval? in
            guard case .rateLimited(let delay) = error else { return nil }
            return delay ?? 60
        }
        if let delay = retryDelays.max() {
            serverDeadline = now.addingTimeInterval(delay)
            nextAutomatic = max(nextAutomatic, now.addingTimeInterval(delay))
        }
    }
}
