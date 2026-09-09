import Foundation
import Testing

@testable import WaterlineKit

struct CredentialCheckTests {
    @Test func repeatedSignedOutCheckDoesNotRewriteDiscovery() async throws {
        let probe = CredentialProbe(token: "new")
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        await probe.signOut()
        await engine.checkChangedFileCredentials()
        let version = await engine.discoveryVersions[.codex]
        await engine.checkChangedFileCredentials()
        #expect(await engine.discoveryVersions[.codex] == version)
        await engine.stop()
    }

    @Test func switchedAccountOnSamePathDoesNotRepeatedlyReconcileOldAccount() async throws {
        let probe = CredentialProbe(token: "new")
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        await probe.switchAccount()
        await engine.checkChangedFileCredentials()
        #expect(await engine.snapshot().accounts.count == 2)
        let version = await engine.discoveryVersions[.codex]
        await engine.checkChangedFileCredentials()
        #expect(await engine.discoveryVersions[.codex] == version)
        await engine.stop()
    }
    @Test func changedTokenUnparksAccountButUnchangedTokenDoesNot() async throws {
        let probe = CredentialProbe(token: "old")
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        try await engine.refreshAll()
        let id = try #require(await engine.snapshot().accounts.first?.account.id)
        try await engine.renameAccount(id, label: "Work")
        await engine.checkChangedFileCredentials()
        try await engine.refreshAll()
        #expect(await probe.fetches == 1)
        await probe.replace("new")
        await engine.checkChangedFileCredentials()
        try await engine.refreshAll(manual: false)
        let entry = try #require(await engine.snapshot().accounts.first)
        #expect(entry.account.id == id && entry.preferences.label == "Work")
        #expect(entry.state.reading?.usage.balances.first?.amount == 20)
        #expect(await probe.fetches == 2)
        #expect(await probe.discoveries == 3)
        await engine.stop()
    }

    @Test func unchangedCheckDoesNotInvalidateInflightRequest() async throws {
        let gate = CompletionGate()
        let probe = CredentialProbe(token: "new", gate: gate)
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        let refresh = Task { try await engine.refreshAll() }
        await gate.waitForFirst()
        await engine.checkChangedFileCredentials()
        await gate.completeOldRequest()
        try await refresh.value
        #expect(await engine.snapshot().accounts.first?.state.reading?.usage.balances.first?.amount == 10)
        await engine.stop()
    }

    @Test func unreadableSourceStopsUseOfCachedSecret() async throws {
        let probe = CredentialProbe(token: "new")
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        try await engine.refreshAll()
        await probe.failSource()
        await engine.checkChangedFileCredentials()
        try await engine.refreshAll()
        #expect(await probe.fetches == 1)
        #expect(await engine.snapshot().sourceFailures.count == 1)
        await engine.stop()
    }

    @Test func disabledSourcesAreNotPolled() async throws {
        let probe = CredentialProbe(token: "new")
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        try await engine.setSource(.codex, enabled: false)
        await engine.checkChangedFileCredentials()
        #expect(await probe.discoveries == 1)
        await engine.stop()
    }

    @Test func tokenRotationCannotBypassServerDeadline() async throws {
        let probe = CredentialProbe(token: "rate")
        let (engine, url) = makeEngine(probe)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try await engine.start()
        try await engine.refreshAll()
        await probe.replace("new")
        await engine.checkChangedFileCredentials()
        try await engine.refreshAll()
        #expect(await probe.fetches == 1)
        #expect(await engine.snapshot().accounts.first?.schedule?.serverDeadline != nil)
        await engine.stop()
    }

    private func makeEngine(_ probe: CredentialProbe) -> (Engine, URL) {
        let url = FileManager.default.temporaryDirectory.appending(path: "credential-check-\(UUID())/snapshot.json")
        let environment = DiscoveryEnvironment(
            home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
            fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: true)
        return (
            Engine(
                dependencies: .init(
                    adapters: [probe], environment: environment,
                    makeHTTPClient: { _ in UnusedHTTP() }, store: SnapshotStore(url: url),
                    ownedSecrets: FakeOwnedSecrets())), url
        )
    }
}

private actor CredentialProbe: ProviderAdapter {
    static let descriptor = CodexAdapter.descriptor
    var token: String
    let gate: CompletionGate?
    var discoveries = 0
    var fetches = 0
    var sourceFailed = false
    var signedOut = false
    var identity = "fixed-account"
    init(token: String, gate: CompletionGate? = nil) { self.token = token; self.gate = gate }
    func replace(_ value: String) { token = value }
    func failSource() { sourceFailed = true }
    func signOut() { signedOut = true }
    func switchAccount() { identity = "other-account" }
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        #expect(!environment.allowsUserInteraction)
        discoveries += 1
        if sourceFailed { throw FetchError.transport(detail: "Source unavailable") }
        if signedOut { return [] }
        return [
            Discovered(
                account: Account(
                    provider: .codex, credential: .file(path: "/synthetic/auth"),
                    identity: BillingIdentity(region: "synthetic", account: identity)), secret: Secret(token))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        fetches += 1
        if let gate { return await gate.fetch() }
        if secret.value == "old" { throw FetchError.unauthorized }
        if secret.value == "rate" { throw FetchError.rateLimited(retryAfter: 900) }
        return reading(20)
    }
}
