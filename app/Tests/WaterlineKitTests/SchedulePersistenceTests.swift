import Foundation
import Testing

@testable import WaterlineKit

private actor AttemptCounter {
    var count = 0
    func attempt() { count += 1 }
}

private struct FailingFetchAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor { GoodAdapter.descriptor }
    let counter: AttemptCounter
    let failure: FetchError
    var credential = "synthetic-auth"
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "synthetic-backoff"), provider: .deepseek,
                    credential: .file(path: "/synthetic/auth")), secret: Secret(credential))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        await counter.attempt()
        throw failure
    }
}

struct SchedulePersistenceTests {
    @Test func restartAndEnableToggleCannotBypassServerDeadline() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-backoff-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let counter = AttemptCounter()
        let adapter = FailingFetchAdapter(counter: counter, failure: .rateLimited(retryAfter: 120))
        let first = engine([adapter], at: url, now: now)
        try await first.start(); try await first.refreshAll(); await first.stop()
        let second = engine([adapter], at: url, now: now.addingTimeInterval(60))
        try await second.start()
        try await second.setAccountEnabled(AccountID(rawValue: "synthetic-backoff"), enabled: false)
        try await second.setAccountEnabled(AccountID(rawValue: "synthetic-backoff"), enabled: true)
        try await second.refreshAll()
        #expect(await counter.count == 1)
        await second.stop()
        let third = engine([adapter], at: url, now: now.addingTimeInterval(121))
        try await third.start(); try await third.refreshAll()
        #expect(await counter.count == 2)
        await third.stop()
    }

    @Test func automaticStartupRespectsFallbackAndCredentialChangeRecoversAuthentication() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-backoff-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let counter = AttemptCounter()
        let transport = FailingFetchAdapter(counter: counter, failure: .transport(detail: "offline"))
        let first = engine([transport], at: url, now: now)
        try await first.start(); try await first.refreshAll(); await first.stop()
        let second = engine([transport], at: url, now: now.addingTimeInterval(30))
        try await second.start(); try await second.refreshAll(manual: false)
        #expect(await counter.count == 1)
        await second.stop()
        let unauthorized = FailingFetchAdapter(counter: counter, failure: .unauthorized)
        let third = engine([unauthorized], at: url, now: now.addingTimeInterval(61))
        try await third.start(); try await third.refreshAll(); await third.stop()
        #expect(await counter.count == 2)
        var changed = unauthorized
        changed.credential = "synthetic-changed"
        let fourth = engine([changed], at: url, now: now.addingTimeInterval(62))
        try await fourth.start(); try await fourth.refreshAll(manual: false)
        #expect(await counter.count == 3)
        await fourth.stop()
    }

    @Test func unauthorizedStaysParkedAcrossRestartUntilConnect() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-backoff-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let counter = AttemptCounter()
        let adapter = FailingFetchAdapter(counter: counter, failure: .unauthorized)
        let first = engine([adapter], at: url)
        try await first.start(); try await first.refreshAll(); await first.stop()
        let second = engine([adapter], at: url)
        try await second.start(); try await second.refreshAll()
        #expect(await counter.count == 1)
        try await second.connect(provider: .deepseek)
        #expect(await counter.count == 2)
        await second.stop()
    }
}
