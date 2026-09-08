import Foundation
import Testing

@testable import WaterlineKit

struct RefreshScheduleTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func authenticationPauseSurvivesCodingAndMissingSource() throws {
        var schedule = RefreshSchedule()
        schedule.failed(.unauthorized, at: now)
        schedule.failed(.credentialMissing, at: now)
        let data = try JSONEncoder().encode(schedule)
        let restored = try JSONDecoder().decode(RefreshSchedule.self, from: data)
        #expect(restored.authenticationParked && restored.parked)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "authenticationParked")
        let old = try JSONDecoder().decode(RefreshSchedule.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(old.authenticationParked)
        schedule.succeeded(at: now, interval: 300)
        #expect(!schedule.authenticationParked && !schedule.parked)
    }

    @Test func partialFailureHonoursLongestRetryWithoutParkingValidUsage() {
        var schedule = RefreshSchedule()
        schedule.partiallySucceeded(
            at: now, interval: 300,
            errors: [.permissionDenied, .rateLimited(retryAfter: 900), .rateLimited(retryAfter: 60)])
        #expect(!schedule.parked)
        #expect(!schedule.eligible(at: now.addingTimeInterval(899), manual: true))
        #expect(schedule.eligible(at: now.addingTimeInterval(900), manual: false))
        schedule.partiallySucceeded(at: now, interval: 300, errors: [.permissionDenied])
        #expect(!schedule.parked)
        #expect(schedule.eligible(at: now.addingTimeInterval(300), manual: false))
    }

    @Test func manualRespectsServerDeadline() {
        var schedule = RefreshSchedule()
        schedule.failed(.rateLimited(retryAfter: 120), at: now)
        #expect(!schedule.eligible(at: now.addingTimeInterval(119), manual: true))
        #expect(schedule.eligible(at: now.addingTimeInterval(120), manual: true))
    }

    @Test func repeatedPartialRateLimitsBackOffAcrossRestartAndRecover() throws {
        var schedule = RefreshSchedule()
        var attempt = now
        for delay in [60.0, 120, 240, 480, 960, 1800, 1800] {
            schedule.partiallySucceeded(at: attempt, interval: 60, errors: [.rateLimited(retryAfter: 0)])
            schedule = try JSONDecoder().decode(RefreshSchedule.self, from: JSONEncoder().encode(schedule))
            #expect(!schedule.parked)
            #expect(!schedule.eligible(at: attempt.addingTimeInterval(delay - 1), manual: true))
            attempt = attempt.addingTimeInterval(delay)
            #expect(schedule.eligible(at: attempt, manual: false))
        }
        schedule.succeeded(at: attempt, interval: 60)
        schedule.partiallySucceeded(at: attempt, interval: 60, errors: [.rateLimited(retryAfter: nil)])
        #expect(schedule.serverDeadline == attempt.addingTimeInterval(60))
    }

    @Test func fallbackBackoffAndSuccessRecovery() {
        var schedule = RefreshSchedule()
        schedule.failed(.transport(detail: "Offline"), at: now)
        #expect(!schedule.eligible(at: now.addingTimeInterval(59), manual: false))
        #expect(schedule.eligible(at: now.addingTimeInterval(60), manual: false))
        #expect(schedule.eligible(at: now, manual: true))
        schedule.failed(.transport(detail: "Offline"), at: now)
        #expect(schedule.nextAutomatic == now.addingTimeInterval(120))
        schedule.succeeded(at: now, interval: 300)
        schedule.failed(.transport(detail: "Offline"), at: now)
        #expect(schedule.nextAutomatic == now.addingTimeInterval(60))
    }

    @Test(arguments: [nil, 0, 1] as [TimeInterval?])
    func rateLimitFallbackAlsoGatesManualRefresh(delay: TimeInterval?) throws {
        var schedule = RefreshSchedule()
        schedule.failed(.rateLimited(retryAfter: delay), at: now)
        let restored = try JSONDecoder().decode(
            RefreshSchedule.self, from: JSONEncoder().encode(schedule))
        #expect(!restored.eligible(at: now.addingTimeInterval(59), manual: true))
        #expect(restored.eligible(at: now.addingTimeInterval(60), manual: true))
        schedule.failed(.rateLimited(retryAfter: delay), at: now.addingTimeInterval(60))
        #expect(!schedule.eligible(at: now.addingTimeInterval(179), manual: true))
        #expect(schedule.eligible(at: now.addingTimeInterval(180), manual: true))
    }

    @Test(arguments: [nil, 0] as [TimeInterval?])
    func partialRateLimitHasMinimumRetryDelay(delay: TimeInterval?) {
        var schedule = RefreshSchedule()
        schedule.partiallySucceeded(at: now, interval: 60, errors: [.rateLimited(retryAfter: delay)])
        #expect(!schedule.eligible(at: now.addingTimeInterval(59), manual: true))
        #expect(schedule.eligible(at: now.addingTimeInterval(60), manual: false))
    }

    @Test func unauthorizedParksManualAndAutomaticRequests() {
        var schedule = RefreshSchedule()
        schedule.failed(.unauthorized, at: now)
        #expect(!schedule.eligible(at: now.addingTimeInterval(10000), manual: true))
        #expect(!schedule.eligible(at: now.addingTimeInterval(10000), manual: false))
        schedule = RefreshSchedule()
        #expect(schedule.eligible(at: now, manual: true))
    }

    @Test func retryAfterDateAndMalformedHeader() throws {
        let response = HTTPResponse(
            status: 429, headers: ["Retry-After": "Tue, 15 Jan 2027 08:02:00 GMT"], body: Data())
        do { try response.validateStatus(now: now) } catch FetchError.rateLimited(let delay) { #expect(delay != nil) }
        let invalid = HTTPResponse(status: 429, headers: ["Retry-After": "invalid"], body: Data())
        #expect(throws: FetchError.rateLimited(retryAfter: nil)) { try invalid.validateStatus(now: now) }
    }
}
