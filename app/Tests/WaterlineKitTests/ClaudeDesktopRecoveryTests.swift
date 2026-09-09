import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeDesktopRecoveryTests {
    @Test func failedRemoteFallbackDoesNotInvalidateCurrentDesktopUsage() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1800000000)
        let adapter = DesktopFallbackAdapter(now: now)
        let engine = Engine(
            dependencies: .init(
                adapters: [adapter],
                environment: DiscoveryEnvironment(
                    home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                    fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in UnusedHTTP() }, store: SnapshotStore(url: root.appending(path: "snapshot.json")),
                ownedSecrets: FakeOwnedSecrets(), now: { now }))
        try await engine.start()
        try await engine.refreshAll()
        let desktop = ClaudeDesktopObservation(
            identity: adapter.identity, observedAt: now.addingTimeInterval(-600),
            windows: [
                UsageWindow(
                    label: "5h", usedFraction: 0, resetsAt: nil, id: "five_hour",
                    observedAt: now.addingTimeInterval(-600), durationSeconds: 18000, maximumAgeSeconds: 1800)
            ])
        #expect(try await engine.receiveClaudeDesktopObservation(desktop))
        let id = try #require(await engine.snapshot().accounts.first?.account.id)
        try await engine.refreshAccount(id)
        let entry = try #require(await engine.snapshot().accounts.first)
        #expect(entry.state.hasCurrentResponse)
        #expect(entry.state.reading?.usage.quotaWindows.first?.usedFraction == 0)
        #expect(entry.state.reading?.usage.quotaWindows.first?.resetsAt == nil)
        #expect(entry.schedule?.authenticationParked == true)
        #expect(entry.schedule?.parked == true)
        #expect(try await !engine.receiveClaudeDesktopObservation(desktop))
        #expect(entry.state.reading?.isCurrent(at: now.addingTimeInterval(1201), interval: 60) == false)
        await engine.stop()
    }
}

private actor DesktopFallbackAdapter: ProviderAdapter {
    let now: Date
    let identity = BillingIdentity(
        region: "api.anthropic.com", account: "00000000-0000-0000-0000-000000000001",
        subject: "00000000-0000-0000-0000-000000000002")
    var fetchCount = 0
    init(now: Date) { self.now = now }
    static let descriptor = ProviderDescriptor(
        provider: .claudeCode, kind: .window, docStatus: .official,
        allowedHosts: [], consoleURL: URL(string: "https://example.invalid")!)
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    provider: .claudeCode, credential: .file(path: "/synthetic/login"), identity: identity),
                secret: Secret("synthetic"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        fetchCount += 1
        if fetchCount > 1 { throw FetchError.unauthorized }
        return .windows(
            windows: [
                UsageWindow(
                    label: "5h", usedFraction: 0.38, resetsAt: now.addingTimeInterval(-100), id: "five_hour",
                    observedAt: now.addingTimeInterval(-900))
            ], plan: "Pro")
    }
}
