import Foundation

public struct ClaudeDesktopObservation: Sendable {
    public let identity: BillingIdentity
    public let observedAt: Date
    public let windows: [UsageWindow]
}

public enum ClaudeDesktopUsage {
    public static func parse(
        history: Data, configuration: Data, matching identity: BillingIdentity, now: Date
    ) throws -> ClaudeDesktopObservation? {
        guard history.count <= 8_388_608, configuration.count <= 4_194_304 else { throw FileBoundaryError.tooLarge }
        struct Configuration: Decodable { let lastKnownAccountUuid: String? }
        struct Sample: Decodable { let t: Double; let org: String?; let u: [String: Double] }
        struct History: Decodable { let version: Int; let samples: [Sample] }
        let config = try JSONDecoder().decode(Configuration.self, from: configuration)
        guard let user = config.lastKnownAccountUuid, let subject = identity.subject,
            let userID = UUID(uuidString: user), userID == UUID(uuidString: subject),
            identity.region == "api.anthropic.com",
            let organization = UUID(uuidString: identity.account)
        else { return nil }
        let decoded = try JSONDecoder().decode(History.self, from: history)
        guard decoded.version == 2, decoded.samples.count <= 100_000 else {
            throw FetchError.schemaChanged(detail: "claude.desktop.history.version/count")
        }
        guard let sample = decoded.samples.max(by: { $0.t < $1.t }),
            sample.org.flatMap(UUID.init(uuidString:)) == organization
        else { return nil }
        let date = Date(timeIntervalSince1970: sample.t / 1000)
        guard sample.t.isFinite, date <= now, now.timeIntervalSince(date) <= 1800 else { return nil }
        var windows: [UsageWindow] = []
        for (key, id, label, duration) in [("fh", "five_hour", "5h", 18000.0), ("sd", "seven_day", "7d", 604800.0)] {
            guard let percent = sample.u[key] else { continue }
            guard percent.isFinite, (0...100).contains(percent) else {
                throw FetchError.schemaChanged(detail: "claude.desktop.history.u.\(key)")
            }
            windows.append(
                UsageWindow(
                    label: label, usedFraction: percent / 100, resetsAt: nil,
                    group: "primary", id: id, observedAt: date, durationSeconds: duration, maximumAgeSeconds: 1800))
        }
        guard !windows.isEmpty else { return nil }
        return ClaudeDesktopObservation(identity: identity, observedAt: date, windows: windows)
    }
}
