import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeLocalIngestionTests {
    @Test(arguments: [false, true])
    func localQuotaPublishesPersistsAndRetainsOtherWindows(partial: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date(timeIntervalSince1970: 1800000000)
        let adapter = LocalIngestionAdapter(now: now, partial: partial)
        let dependencies = Engine.Dependencies(
            adapters: [adapter],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false),
            makeHTTPClient: { _ in UnusedHTTP() },
            store: SnapshotStore(url: root.appending(path: "snapshot.json")), ownedSecrets: FakeOwnedSecrets(),
            now: { now })
        let engine = Engine(dependencies: dependencies)
        try await engine.start()
        try await engine.refreshAll()
        let observation = ClaudeLocalObservation(
            identity: adapter.identity, sessionID: UUID(),
            quotas: [ClaudeStatuslineQuota(id: "five_hour", usedFraction: 0.4, resetsAt: now.addingTimeInterval(3600))],
            receivedAt: now)
        #expect(try await engine.receiveClaudeObservation(observation))
        let updated = try #require(await engine.snapshot().accounts.first?.state.reading)
        #expect(updated.origin == .local)
        #expect(updated.usage.componentFailures.map(\.id) == (partial ? ["seven_day_unavailable"] : []))
        #expect(updated.usage.quotaWindows.first(where: { $0.id == "five_hour" })?.usedFraction == 0.4)
        #expect(updated.usage.quotaWindows.first(where: { $0.id == "seven_day_extra" })?.usedFraction == 0.2)
        #expect(await engine.snapshot().accounts.first?.schedule?.nextAutomatic == now.addingTimeInterval(300))
        await engine.refreshWhenViewed()
        #expect(await engine.snapshot().accounts.first?.schedule?.nextAutomatic == now.addingTimeInterval(300))
        #expect(try await !engine.receiveClaudeObservation(observation))
        let wrong = ClaudeLocalObservation(
            identity: BillingIdentity(
                region: "api.anthropic.com", account: UUID().uuidString, subject: UUID().uuidString),
            sessionID: observation.sessionID, quotas: observation.quotas, receivedAt: now)
        #expect(try await !engine.receiveClaudeObservation(wrong))
        await engine.stop()
        let restored = Engine(dependencies: dependencies)
        try await restored.start()
        #expect(
            await restored.snapshot().accounts.first?.state.reading?.usage.quotaWindows.first(where: {
                $0.id == "five_hour"
            })?.usedFraction == 0.4)
        await restored.stop()
    }
}

private struct LocalIngestionAdapter: ProviderAdapter {
    let now: Date
    let partial: Bool
    let identity = BillingIdentity(
        region: "api.anthropic.com", account: "00000000-0000-0000-0000-000000000001",
        subject: "00000000-0000-0000-0000-000000000002")
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
        .metrics(
            windows: [
                UsageWindow(
                    label: "5h", usedFraction: 0.3, resetsAt: now.addingTimeInterval(3600), id: "five_hour",
                    observedAt: now.addingTimeInterval(-60)),
                UsageWindow(
                    label: "Extra", usedFraction: 0.2, resetsAt: now.addingTimeInterval(86400), id: "seven_day_extra",
                    observedAt: now.addingTimeInterval(-60)),
            ], balances: [], plan: "Pro",
            failures: partial
                ? [
                    MetricFailure(id: "five_hour", error: .schemaChanged(detail: "five_hour")),
                    MetricFailure(id: "seven_day_unavailable", error: .schemaChanged(detail: "seven_day_unavailable")),
                ] : [])
    }
}
