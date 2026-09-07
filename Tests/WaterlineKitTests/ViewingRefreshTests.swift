import Foundation
import Testing

@testable import WaterlineKit

private final class ViewingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.withLock { value } }
    func advance(_ seconds: TimeInterval) { lock.withLock { value.addTimeInterval(seconds) } }
}

struct ViewingRefreshTests {
    private func subject(_ url: URL, clock: ViewingClock) -> Engine {
        Engine(
            dependencies: .init(
                adapters: [ViewingWindowAdapter()],
                environment: DiscoveryEnvironment(
                    home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                    fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in UnusedHTTP() }, store: SnapshotStore(url: url), now: { clock.now }))
    }

    @Test func viewingAdvancesHealthyRefreshAndCoalescesRepeatedPeeks() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-view-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = ViewingClock()
        let subject = self.subject(url, clock: clock)
        try await subject.start(); try await subject.refreshAll()
        let initial = await subject.snapshot().lastAttemptAt
        clock.advance(30)
        try await subject.refreshAll(manual: false)
        #expect(await subject.snapshot().lastAttemptAt == initial)
        await subject.refreshWhenViewed()
        try await subject.refreshAll(manual: false)
        #expect(await subject.snapshot().lastAttemptAt == clock.now)
        let refreshed = clock.now
        clock.advance(1)
        await subject.refreshWhenViewed()
        try await subject.refreshAll(manual: false)
        #expect(await subject.snapshot().lastAttemptAt == refreshed)
        clock.advance(14)
        try await subject.refreshAll(manual: false)
        #expect(await subject.snapshot().lastAttemptAt == clock.now)
        await subject.stop()
    }

    @Test func activeComputerUsesMinuteCadenceAndIdleReturnsToConfiguredCadence() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-active-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = ViewingClock()
        let engine = self.subject(url, clock: clock)
        try await engine.start(); try await engine.refreshAll()
        let initial = clock.now
        await engine.setUserActive(true)
        clock.advance(59); try await engine.refreshAll(manual: false)
        #expect(await engine.snapshot().lastAttemptAt == initial)
        clock.advance(1); try await engine.refreshAll(manual: false)
        #expect(await engine.snapshot().accounts.first?.schedule?.nextAutomatic == clock.now.addingTimeInterval(60))
        await engine.setUserActive(false)
        clock.advance(60); try await engine.refreshAll(manual: false)
        #expect(await engine.snapshot().accounts.first?.schedule?.nextAutomatic == clock.now.addingTimeInterval(300))
        await engine.stop()
    }

    @Test func viewingDoesNotBypassBackoffServerDeadlineOrAuthenticationPause() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var failed = RefreshSchedule()
        failed.failed(.transport(detail: "offline"), at: now)
        let deadline = failed.nextAutomatic
        failed.requestSooner(at: now, lastFetchedAt: nil, minimumInterval: 15)
        #expect(failed.nextAutomatic == deadline)
        var limited = RefreshSchedule()
        limited.partiallySucceeded(at: now, interval: 300, errors: [.rateLimited(retryAfter: 120)])
        limited.requestSooner(at: now, lastFetchedAt: nil, minimumInterval: 15)
        #expect(!limited.eligible(at: now.addingTimeInterval(119), manual: false))
        var parked = RefreshSchedule()
        parked.failed(.unauthorized, at: now)
        parked.requestSooner(at: now.addingTimeInterval(1000), lastFetchedAt: nil, minimumInterval: 15)
        #expect(!parked.eligible(at: now.addingTimeInterval(1000), manual: false))
    }
}

private struct ViewingWindowAdapter: ProviderAdapter {
    static let descriptor = ProviderDescriptor(
        provider: .codex, kind: .window, docStatus: .community,
        allowedHosts: [], consoleURL: URL(string: "https://example.invalid")!)
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "viewing-window"), provider: .codex,
                    credential: .file(path: "/synthetic/window")), secret: Secret("test-only"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        .windows(windows: [UsageWindow(label: "5h", usedFraction: 0.4, resetsAt: nil)], plan: nil)
    }
}
