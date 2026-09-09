import Foundation
import Testing

@testable import WaterlineKit

struct DeepSeekOpenCodeTests {
    @Test func sourceRequiresOptInAndReadsOnlyTheNamedAPIEntry() async throws {
        let files = OpenCodeFiles()
        let off = environment(files, enabled: false)
        #expect(try await DeepSeekAdapter().discover(in: off, http: UnusedHTTP()).isEmpty)
        #expect(files.readCount == 0)
        let rows = try await DeepSeekAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(rows.count == 1)
        #expect(rows[0].secret?.value == "synthetic-source-key")
        #expect(rows[0].account.optionalCredentialSource == .deepSeekOpenCode)
    }

    @Test func overridesAndMalformedKeysNeverBecomeRequests() async throws {
        let files = OpenCodeFiles()
        files.config = Data(#"{"provider":{"deepseek":{"options":{"baseURL":"https://proxy.example"}}}}"#.utf8)
        var rows = try await DeepSeekAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(rows.first?.secret == nil)
        #expect(rows.first?.connectionError != nil)
        files.config = Data("{ /* JSONC */ \"provider\": {}, }".utf8)
        rows = try await DeepSeekAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(rows.first?.secret != nil)
        files.auth = Data(#"{"deepseek":{"type":"api","key":"$PLACEHOLDER"}}"#.utf8)
        rows = try await DeepSeekAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(rows.first?.secret == nil)
        files.auth = Data(#"{"deepseek":{"type":"oauth","access":"ignored"}}"#.utf8)
        #expect(try await DeepSeekAdapter().discover(in: environment(files), http: UnusedHTTP()).isEmpty)
    }

    @Test func bindingRetainsManualKeyIdentityHistoryAndFollowsRotationAfterRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "opencode-source-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let files = OpenCodeFiles()
        let keys = FakeOwnedSecrets()
        let http = OpenCodeBalanceHTTP()
        let dependencies = Engine.Dependencies(
            adapters: [DeepSeekAdapter()], environment: environment(files, enabled: false),
            makeHTTPClient: { _ in http }, store: SnapshotStore(url: root.appending(path: "snapshot.json")),
            ownedSecrets: keys, now: { Date(timeIntervalSince1970: 1_800_000_000) })
        let engine = Engine(dependencies: dependencies)
        try await engine.start()
        let id = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-source-key"))
        try await engine.renameAccount(id, label: "My source")
        try await engine.setAccountOrder([id])
        try await engine.setNotchAccounts([id])
        let originalHistory = await engine.historyRecords
        let originalJournal = try Data(contentsOf: root.appending(path: "history.jsonl"))
        let writes = keys.writeCount
        try await engine.setOptionalCredentialSource(.deepSeekOpenCode, enabled: true)
        var snapshot = await engine.snapshot()
        #expect(snapshot.accounts.count == 1)
        #expect(snapshot.accounts[0].account.id == id)
        #expect(snapshot.accounts[0].account.optionalCredentialSource == .deepSeekOpenCode)
        #expect(snapshot.accounts[0].preferences.label == "My source")
        #expect(keys.contains(id))
        #expect(keys.writeCount == writes)
        await engine.stop()
        let restarted = Engine(dependencies: dependencies)
        try await restarted.start()
        files.auth = Data(#"{"deepseek":{"type":"api","key":"synthetic-rotated"}}"#.utf8)
        await restarted.checkChangedFileCredentials()
        try await restarted.refreshAll()
        snapshot = await restarted.snapshot()
        #expect(snapshot.accounts.count == 1 && snapshot.accounts[0].account.id == id)
        #expect(snapshot.accounts[0].state.hasCurrentResponse)
        #expect(snapshot.preferences.notchAccountIDs == [id])
        #expect(snapshot.preferences.accountOrder == [id])
        #expect(await http.lastAuthorization == "Bearer synthetic-rotated")
        let history = await restarted.historyRecords
        #expect(!originalHistory.isEmpty)
        #expect(originalHistory.allSatisfy { history.contains($0) })
        #expect(try Data(contentsOf: root.appending(path: "history.jsonl")).starts(with: originalJournal))
        #expect(keys.contains(id) && keys.writeCount == writes)
        #expect(
            !String(decoding: try Data(contentsOf: dependencies.store.url), as: UTF8.self).contains("synthetic-rotated")
        )
        files.auth = Data("{}".utf8)
        await restarted.checkChangedFileCredentials()
        #expect(
            await restarted.snapshot().accounts[0].state
                == .stale(
                    reading: try #require(snapshot.accounts[0].state.reading), error: .credentialMissing))
        #expect(keys.contains(id))
        #expect(keys.interactiveReadIDs.isEmpty)
        try await restarted.removeAccount(id)
        #expect(!keys.contains(id))
        await restarted.stop()
    }

    private func environment(_ files: OpenCodeFiles, enabled: Bool = true) -> DiscoveryEnvironment {
        DiscoveryEnvironment(
            home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
            fileSystem: files, keychain: EmptyKeychain(), allowsUserInteraction: false,
            enabledCredentialSources: enabled ? [.deepSeekOpenCode] : [])
    }
}

private final class OpenCodeFiles: FileSystem, @unchecked Sendable {
    private let lock = NSLock()
    private var authData = Data(#"{"deepseek":{"type":"api","key":"synthetic-source-key"},"unrelated":42}"#.utf8)
    private var configData: Data?
    private var reads = 0
    var readCount: Int { lock.withLock { reads } }
    var auth: Data {
        get { lock.withLock { authData } }
        set { lock.withLock { authData = newValue } }
    }
    var config: Data? {
        get { lock.withLock { configData } }
        set { lock.withLock { configData = newValue } }
    }
    func exists(_ url: URL) -> Bool {
        url.path.hasSuffix("/auth.json") || (url.path.hasSuffix("/opencode.jsonc") && config != nil)
    }
    func contents(of url: URL) throws -> Data {
        lock.withLock { reads += 1 }
        if url.path.hasSuffix("/auth.json") { return auth }
        if let config { return config }
        throw FetchError.credentialMissing
    }
    func modificationDate(of url: URL) throws -> Date { Date() }
}

private actor OpenCodeBalanceHTTP: HTTPClient {
    var lastAuthorization: String?
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://api.deepseek.com/user/balance")
        lastAuthorization = request.headers["Authorization"]
        return HTTPResponse(
            status: 200, headers: [:], body: Data(#"{"balance_infos":[{"currency":"USD","total_balance":"20"}]}"#.utf8))
    }
}
