import Foundation
import Testing

@testable import WaterlineKit

private actor LocalQuotaFixture: AntigravityServiceReading {
    var identity = AntigravityAccountIdentity(key: "synthetic-first")
    var reads = 0
    var available = true
    func changeAccount() { identity = AntigravityAccountIdentity(key: "synthetic-second") }
    func identities(executable: URL, requestBudget: any HTTPClient) async throws -> [AntigravityAccountIdentity] {
        reads += 1
        guard available else { throw FetchError.transport(detail: "CLI closed") }
        return [identity]
    }
    func usage(
        identity: AntigravityAccountIdentity, executable: URL, requestBudget: any HTTPClient
    ) async throws -> Usage {
        reads += 1
        guard available, identity == self.identity else { throw FetchError.credentialMissing }
        return .windows(
            windows: [
                UsageWindow(
                    label: "Gemini · 5h", usedFraction: 0.2, resetsAt: nil, group: "Gemini", id: "gemini-5h",
                    durationSeconds: 18000)
            ], plan: nil)
    }
}

struct AntigravityAccountFlowTests {
    @Test func optInFetchRestoreAndDisableDoNotNeedASecret() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "agy-flow-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let fixture = LocalQuotaFixture()
        let keys = FakeOwnedSecrets()
        let deps = dependencies(url, fixture: fixture, keys: keys)
        let engine = Engine(dependencies: deps)
        try await engine.start()
        #expect(await fixture.reads == 0)
        #expect(await engine.snapshot().accounts.isEmpty)
        try await engine.setOptionalCredentialSource(.antigravityCLI, enabled: true)
        let first = try #require(await engine.snapshot().accounts.first)
        #expect(first.state.hasCurrentResponse)
        #expect(first.account.credential == .localService(name: "antigravity-cli"))
        #expect(keys.writeCount == 0)
        try await engine.setNotchAccounts([first.account.id])
        await engine.stop()
        let restored = Engine(dependencies: deps)
        try await restored.start()
        try await restored.refreshAll()
        #expect(await restored.snapshot().accounts.count == 1)
        #expect(await restored.snapshot().accounts.first?.account.id == first.account.id)
        #expect(await restored.snapshot().preferences.notchAccountIDs == [first.account.id])
        #expect(await restored.snapshot().accounts.first?.state.hasCurrentResponse == true)
        try await restored.setOptionalCredentialSource(.antigravityCLI, enabled: false)
        let reads = await fixture.reads
        try await restored.refreshAll()
        #expect(await fixture.reads == reads)
        #expect(keys.writeCount == 0)
        await restored.stop()
    }

    @Test func changedLocalAccountDoesNotOverwriteTheOldAccount() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "agy-switch-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let fixture = LocalQuotaFixture()
        let engine = Engine(dependencies: dependencies(url, fixture: fixture, keys: FakeOwnedSecrets()))
        try await engine.start()
        try await engine.setOptionalCredentialSource(.antigravityCLI, enabled: true)
        let first = try #require(await engine.snapshot().accounts.first?.account.id)
        await fixture.changeAccount()
        await engine.checkChangedFileCredentials()
        try await engine.refreshAll()
        let rows = await engine.snapshot().accounts
        #expect(rows.count == 2)
        #expect(rows.first(where: { $0.account.id == first })?.state.hasCurrentResponse == false)
        #expect(rows.first(where: { $0.account.id != first })?.state.hasCurrentResponse == true)
        await engine.stop()
    }

    private func dependencies(_ url: URL, fixture: LocalQuotaFixture, keys: FakeOwnedSecrets) -> Engine.Dependencies {
        .init(
            adapters: [AntigravityAdapter(service: fixture, executable: URL(fileURLWithPath: "/synthetic/agy"))],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false),
            makeHTTPClient: { _ in ForbiddenRemoteRequest() }, store: SnapshotStore(url: url), ownedSecrets: keys)
    }
}

private struct ForbiddenRemoteRequest: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        Issue.record("Local provider must not send through the remote credential client")
        throw FetchError.credentialMissing
    }
}
