import Foundation
import Testing

@testable import WaterlineKit

struct OptionalCredentialSourceTests {
    @Test func disablingOptionalSourceDuringReconnectDoesNotStrandManualAccount() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let adapter = DelayedSourceAdapter()
        let engine = makeEngine(
            at: url, key: "synthetic-env", http: SourceHTTP(), secrets: SourceSecrets(), adapter: adapter)
        try await engine.start()
        let manual = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-manual"))
        try await engine.setOptionalCredentialSource(.deepSeekEnvironment, enabled: true)
        await adapter.holdNext()
        let reconnect = Task { try await engine.connect(provider: .deepseek) }
        await adapter.waitUntilHeld()
        try await engine.setOptionalCredentialSource(.deepSeekEnvironment, enabled: false)
        let snapshot = await engine.snapshot()
        #expect(snapshot.accounts.first { $0.account.id == manual }?.operation == .idle)
        await adapter.release()
        try await reconnect.value
        #expect(await engine.snapshot().accounts.first { $0.account.id == manual }?.state.hasCurrentResponse == true)
        await engine.stop()
    }
    @Test func discoveryRequiresExplicitOptInAndRejectsMalformedKey() async throws {
        let adapter = DeepSeekAdapter()
        #expect(
            try await adapter.discover(in: environment("synthetic-env", enabled: false), http: UnusedHTTP()).isEmpty)
        let valid = try await adapter.discover(in: environment("synthetic-env", enabled: true), http: UnusedHTTP())
        #expect(valid.first?.account.optionalCredentialSource == .deepSeekEnvironment)
        #expect(valid.first?.secret?.value == "synthetic-env")
        let invalid = try await adapter.discover(in: environment("bad\nkey", enabled: true), http: UnusedHTTP())
        #expect(invalid.first?.secret == nil)
        #expect(invalid.first?.connectionError == .schemaChanged(detail: "environment.DEEPSEEK_API_KEY"))
    }

    @Test func optInDisableRemovalAndReconnectAreScoped() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let http = SourceHTTP()
        let secrets = SourceSecrets()
        let engine = makeEngine(at: url, key: "synthetic-env", http: http, secrets: secrets)
        try await engine.start()
        #expect(await engine.snapshot().accounts.isEmpty)
        let manualID = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-manual"))
        try await engine.setOptionalCredentialSource(.deepSeekEnvironment, enabled: true)
        let snapshot = await engine.snapshot()
        let environmentID = try #require(
            snapshot.accounts.first { $0.account.optionalCredentialSource != nil }?.account.id)
        #expect(snapshot.accounts.first { $0.account.id == manualID }?.state.hasCurrentResponse == true)
        #expect(secrets.reads == 0)
        try await engine.setOptionalCredentialSource(.deepSeekEnvironment, enabled: false)
        try await engine.refreshAll()
        #expect(await http.headers == ["Bearer synthetic-manual", "Bearer synthetic-env", "Bearer synthetic-manual"])
        let disabled = await engine.snapshot()
        #expect(
            disabled.accounts.first { $0.account.id == environmentID }?.isEnabled(in: disabled.preferences) == false)
        #expect(Dashboard.balanceHeadline(disabled.accounts, preferences: disabled.preferences)?.amount == 100)
        try await engine.removeAccount(environmentID)
        try await engine.setOptionalCredentialSource(.deepSeekEnvironment, enabled: true)
        #expect(await engine.snapshot().accounts.count == 1)
        try await engine.connectOptionalCredentialSource(.deepSeekEnvironment)
        #expect(await engine.snapshot().accounts.contains { $0.account.id == environmentID })
        #expect(secrets.reads == 0)
        await engine.stop()
    }

    @Test func restartRestoresOptInAndRotationKeepsLocalIdentityWithoutPersistingKey() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = makeEngine(at: url, key: "synthetic-env-old", http: SourceHTTP(), secrets: SourceSecrets())
        try await first.start()
        try await first.setOptionalCredentialSource(.deepSeekEnvironment, enabled: true)
        let id = try #require(await first.snapshot().accounts.first?.account.id)
        try await first.renameAccount(id, label: "Environment account")
        await first.stop()
        let second = makeEngine(at: url, key: "synthetic-env-new", http: SourceHTTP(), secrets: SourceSecrets())
        try await second.start()
        try await second.refreshAll()
        let row = try #require(await second.snapshot().accounts.first)
        #expect(row.account.id == id && row.preferences.label == "Environment account")
        #expect(row.state.hasCurrentResponse)
        for file in try FileManager.default.contentsOfDirectory(
            at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        {
            let contents = try Data(contentsOf: file)
            #expect(!String(decoding: contents, as: UTF8.self).contains("synthetic-env-"))
        }
        await second.stop()
    }

    @Test func legacyPreferencesAndUnknownEnvironmentSourcesStayOff() throws {
        let old = Data(
            #"{"refreshInterval":300,"windowWarning":0.7,"windowCritical":0.9,"balanceThresholds":{"USD":10},"disabledProviders":[]}"#
                .utf8)
        let preferences = try JSONDecoder().decode(UserPreferences.self, from: old)
        let account = Account(provider: .deepseek, credential: .env(name: "DEEPSEEK_API_KEY", sourceFile: "process"))
        #expect(!preferences.allowsSource(for: account))
        var enabled = preferences
        enabled.enabledCredentialSources = [.deepSeekEnvironment]
        #expect(enabled.allowsSource(for: account))
        #expect(
            !enabled.allowsSource(
                for: Account(provider: .deepseek, credential: .env(name: "OTHER_KEY", sourceFile: "process"))))
    }

    private func path() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "optional-source-\(UUID())/snapshot.json")
    }
    private func environment(_ key: String, enabled: Bool = false) -> DiscoveryEnvironment {
        DiscoveryEnvironment(
            home: URL(fileURLWithPath: "/synthetic"), processEnvironment: ["DEEPSEEK_API_KEY": key],
            fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false,
            enabledCredentialSources: enabled ? [.deepSeekEnvironment] : [])
    }
    private func makeEngine(
        at url: URL, key: String, http: SourceHTTP, secrets: SourceSecrets,
        adapter: any ProviderAdapter = DeepSeekAdapter()
    ) -> Engine {
        Engine(
            dependencies: .init(
                adapters: [adapter], environment: environment(key),
                makeHTTPClient: { hosts in
                    #expect(hosts == ["api.deepseek.com"]); return http
                },
                store: SnapshotStore(url: url), ownedSecrets: secrets))
    }
}

private final class SourceSecrets: OwnedSecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    private var values: [AccountID: Secret] = [:]
    var reads: Int { lock.withLock { count } }
    func read(_ id: AccountID, interactive: Bool) throws -> Secret {
        lock.withLock { count += 1 }
        return try lock.withLock {
            guard let value = values[id] else { throw FetchError.keychainLocked }
            return value
        }
    }
    func save(_ secret: Secret, for id: AccountID) throws { lock.withLock { values[id] = secret } }
    func delete(_ id: AccountID) throws { throw FetchError.credentialMissing }
}
private actor SourceHTTP: HTTPClient {
    var headers: [String] = []
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://api.deepseek.com/user/balance")
        let authorization = request.headers["Authorization"] ?? ""
        headers.append(authorization)
        let amount = authorization.contains("synthetic-env") ? "5" : "100"
        let body = "{\"balance_infos\":[{\"currency\":\"USD\",\"total_balance\":\"\(amount)\"}]}"
        return HTTPResponse(status: 200, headers: [:], body: Data(body.utf8))
    }
}

private actor DelayedSourceAdapter: ProviderAdapter {
    static let descriptor = DeepSeekAdapter.descriptor
    private var hold = false
    private var held: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    func holdNext() { hold = true }
    func waitUntilHeld() async {
        if held != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func release() { held?.resume(); held = nil }
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        if hold {
            hold = false
            await withCheckedContinuation { continuation in
                held = continuation
                observer?.resume()
                observer = nil
            }
        }
        return try await DeepSeekAdapter().discover(in: environment, http: http)
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        try await DeepSeekAdapter().fetch(account, secret: secret, http: http)
    }
}
