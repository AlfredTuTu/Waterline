import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeDesktopUsageTests {
    let now = Date(timeIntervalSince1970: 1800000000)
    let user = UUID().uuidString
    let org = UUID().uuidString
    var identity: BillingIdentity { BillingIdentity(region: "api.anthropic.com", account: org, subject: user) }

    func parse(
        age: Double = 600, userOverride: String? = nil, organization: String? = nil, percent: Double = 0
    ) throws -> ClaudeDesktopObservation? {
        let history = try JSONSerialization.data(withJSONObject: [
            "version": 2,
            "samples": [
                [
                    "t": (now.timeIntervalSince1970 - age) * 1000, "org": organization ?? org,
                    "u": ["fh": percent, "sd": 33],
                ]
            ],
        ])
        let config = try JSONSerialization.data(withJSONObject: [
            "lastKnownAccountUuid": userOverride ?? user, "oauth:tokenCache": "must-not-be-retained",
        ])
        return try ClaudeDesktopUsage.parse(history: history, configuration: config, matching: identity, now: now)
    }

    @Test func desktopTimestampAndMissingResetRemainAccurate() throws {
        let observation = try #require(try parse())
        #expect(observation.observedAt == now.addingTimeInterval(-600))
        #expect(observation.windows.map(\.usedFraction) == [0, 0.33])
        #expect(observation.windows.allSatisfy { $0.resetsAt == nil })
        let usage = Usage.windows(windows: observation.windows, plan: nil).accepting(at: now, previous: nil)
        let restored = try JSONDecoder().decode(Usage.self, from: JSONEncoder().encode(usage))
        let reading = Reading(usage: restored, fetchedAt: now, observedAt: observation.observedAt, origin: .local)
        #expect(reading.isCurrent(at: now, interval: 60))
        #expect(!reading.isCurrent(at: now.addingTimeInterval(1201), interval: 60))
        #expect(restored.quotaWindows.first?.observedAt == observation.observedAt)
    }

    @Test func wrongAccountOldFutureAndInvalidPercentAreNotFreshUsage() throws {
        #expect(try parse(userOverride: UUID().uuidString) == nil)
        #expect(try parse(organization: UUID().uuidString) == nil)
        #expect(try parse(age: 1801) == nil)
        #expect(try parse(age: -1) == nil)
        #expect(throws: FetchError.self) { try parse(percent: 101) }
        #expect(throws: FetchError.self) {
            try ClaudeDesktopUsage.parse(
                history: Data(#"{"version":1,"samples":[]}"#.utf8),
                configuration: JSONSerialization.data(withJSONObject: ["lastKnownAccountUuid": user]),
                matching: identity, now: now)
        }
    }
}
