import Foundation
import Testing

@testable import WaterlineKit

struct QuotaResetTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func resetExpiresReadingWithoutReplacingUsageWithZero() {
        let window = UsageWindow(
            label: "5h", usedFraction: 0.8, resetsAt: start.addingTimeInterval(60), observedAt: start)
        #expect(window.isCurrent(at: start.addingTimeInterval(59), fallbackObservation: start, interval: 300))
        #expect(!window.isCurrent(at: start.addingTimeInterval(60), fallbackObservation: start, interval: 300))
        #expect(window.usedFraction == 0.8)
    }

    @Test func resetDeadlineHonoursFailuresAndServerWaits() {
        let reset = start.addingTimeInterval(10)
        var schedule = RefreshSchedule()
        schedule.succeeded(at: start, interval: 300)
        #expect(schedule.nextAutomaticDate(resetAt: reset) == reset)
        #expect(schedule.eligible(at: reset, manual: false, resetAt: reset))
        schedule.failed(.transport(detail: "Offline"), at: start)
        #expect(schedule.nextAutomaticDate(resetAt: reset) == start.addingTimeInterval(60))
        schedule.failed(.rateLimited(retryAfter: 900), at: start)
        #expect(schedule.nextAutomaticDate(resetAt: reset) == start.addingTimeInterval(900))
        schedule.failed(.unauthorized, at: start)
        #expect(schedule.nextAutomaticDate(resetAt: reset) == nil)
    }

    @Test func engineRefreshesAtResetButDoesNotSpinOnUnchangedPastReset() async throws {
        let clock = ResetClock(start)
        let adapter = ResetAdapter(reset: start.addingTimeInterval(60))
        let url = FileManager.default.temporaryDirectory.appending(path: "quota-reset-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = Engine(
            dependencies: .init(
                adapters: [adapter],
                environment: DiscoveryEnvironment(
                    home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                    fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in UnusedHTTP() }, store: SnapshotStore(url: url), ownedSecrets: FakeOwnedSecrets(),
                now: { clock.now }))
        try await engine.start()
        try await engine.refreshAll(manual: false)
        clock.advance(61)
        let snapshot = await engine.snapshot()
        if case .expired = snapshot.accounts.first?.state {} else { Issue.record("Reset must expire the quota") }
        #expect(Dashboard.headline(snapshot, now: clock.now) == .awaitingUpdate)
        try await engine.refreshAll(manual: false)
        #expect(await adapter.fetches == 2)
        try await engine.refreshAll(manual: false)
        #expect(await adapter.fetches == 2)
        #expect(await engine.snapshot().accounts.first?.state.reading?.usage.quotaWindows.first?.usedFraction == 0.8)
        await engine.stop()
    }

    @Test func expiredComponentDoesNotMaskValidWindowOrTriggerAlert() {
        func snapshot(_ fraction: Double, at date: Date) -> Snapshot {
            let usage = Usage.windows(
                windows: [
                    UsageWindow(
                        label: "5h", usedFraction: fraction, resetsAt: start.addingTimeInterval(60), id: "short"),
                    UsageWindow(label: "Week", usedFraction: 0.2, resetsAt: start.addingTimeInterval(3600), id: "week"),
                ], plan: nil)
            let row = AccountEntry(
                account: Account(id: AccountID(rawValue: "fixed"), provider: .codex, credential: .manual),
                state: .fresh(reading: Reading(usage: usage, fetchedAt: date)))
            return Snapshot(generatedAt: date, accounts: [row], lastAttemptAt: date)
        }
        var alerts = ThresholdAlerts()
        alerts.enabled = true
        _ = alerts.evaluate(snapshot(0.5, at: start))
        let later = snapshot(0.95, at: start.addingTimeInterval(61))
        #expect(alerts.evaluate(later).isEmpty)
        #expect(Dashboard.headline(later, now: later.generatedAt) == .quota(0.2))
        #expect(Dashboard.health(later.accounts[0], preferences: later.preferences, now: later.generatedAt) == .muted)
    }
}

private final class ResetClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    init(_ date: Date) { self.date = date }
    var now: Date { lock.withLock { date } }
    func advance(_ seconds: TimeInterval) { lock.withLock { date = date.addingTimeInterval(seconds) } }
}

private actor ResetAdapter: ProviderAdapter {
    static let descriptor = ProviderDescriptor(
        provider: .deepseek, kind: .window, docStatus: .community,
        allowedHosts: [], consoleURL: URL(string: "https://synthetic.example")!)
    let reset: Date
    var fetches = 0
    init(reset: Date) { self.reset = reset }
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(provider: .deepseek, credential: .file(path: "/synthetic/auth")),
                secret: Secret("synthetic"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        fetches += 1
        return .windows(windows: [UsageWindow(label: "5h", usedFraction: 0.8, resetsAt: reset)], plan: nil)
    }
}
