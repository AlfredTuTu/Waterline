import Foundation
import Testing

@testable import WaterlineKit

struct ZhipuSourceTests {
    @Test func optInPrecedesAllFileAccess() async throws {
        let files = ZhipuSettingsFiles(data: Data("malformed".utf8))
        #expect(try await ZhipuAdapter().discover(in: environment(files, enabled: false), http: UnusedHTTP()).isEmpty)
        #expect(files.accesses == 0)
    }

    @Test(arguments: [
        "https://open.bigmodel.cn/api/anthropic", "https://open.bigmodel.cn/api/anthropic/",
        "https://api.z.ai/api/anthropic", "https://api.z.ai/api/anthropic/",
        "https://api.z.ai:443/api/anthropic",
    ])
    func officialRouteDeterminesCredentialScopeAndQuotaHost(_ base: String) async throws {
        let host = try #require(URL(string: base)?.host)
        let region = host == "api.z.ai" ? "global" : "cn"
        let files = ZhipuSettingsFiles(data: settings(base, token: "synthetic-zhipu"))
        let result = try await ZhipuAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(result.count == 1)
        let discovered = try #require(result.first)
        #expect(discovered.account.provider == .zhipu)
        #expect(discovered.account.region == region)
        #expect(discovered.account.identity == nil)
        #expect(discovered.account.optionalCredentialSource == .zhipuClaudeSettings)
        #expect(
            discovered.account.credential
                == .configuration(
                    source: .zhipuClaudeSettings, path: "/synthetic/.claude/settings.json", key: "ANTHROPIC_AUTH_TOKEN")
        )
        #expect(discovered.connectionError == nil)
        let secret = try #require(discovered.secret)
        let http = ZhipuSourceHTTP(expectedHost: host, expectedToken: secret.value)
        let usage = try await ZhipuAdapter().fetch(discovered.account, secret: secret, http: http)
        #expect(usage.quotaWindows.first?.usedFraction == 0.25)
        #expect(http.requests == 1)
    }

    @Test(arguments: [
        "http://api.z.ai/api/anthropic", "https://api.z.ai.evil.example/api/anthropic",
        "https://proxy.example/api/anthropic", "https://api.z.ai:444/api/anthropic",
        "https://api.z.ai/api/other", "https://api.z.ai/api/anthropic?key=value",
        "https://api.z.ai/api/anthropic#fragment", "https://user@api.z.ai/api/anthropic",
        "https://user:password@open.bigmodel.cn/api/anthropic", "https://api.deepseek.com/anthropic",
    ])
    func foreignRoutesAreRejectedBeforeTokenDecoding(_ base: String) async throws {
        let files = ZhipuSettingsFiles(data: settings(base, token: ["not": "a string"]))
        #expect(try await ZhipuAdapter().discover(in: environment(files), http: UnusedHTTP()).isEmpty)
    }

    @Test func missingTokenKeepsKnownRegionalAccount() async throws {
        let files = ZhipuSettingsFiles(data: settings("https://api.z.ai/api/anthropic", token: nil))
        let result = try await ZhipuAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(result.count == 1)
        #expect(result.first?.account.region == "global")
        #expect(result.first?.secret == nil)
        #expect(result.first?.connectionError == .credentialMissing)
    }

    @Test(arguments: ["", "two words", "tab\tkey", "line\nkey", "control\u{0001}", String(repeating: "é", count: 4097)])
    func invalidTokenNeverBecomesSecret(_ token: String) async throws {
        let files = ZhipuSettingsFiles(data: settings("https://open.bigmodel.cn/api/anthropic", token: token))
        let result = try await ZhipuAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(result.count == 1)
        #expect(result.first?.account.region == "cn")
        #expect(result.first?.secret == nil)
        guard case .schemaChanged = result.first?.connectionError else {
            Issue.record("Expected invalid token to produce schemaChanged")
            return
        }
    }

    @Test func malformedRoutingFailsSourceWithoutInventingAccount() async {
        for raw in ["not-json", "[]", #"{"env":42}"#, #"{"env":{"ANTHROPIC_BASE_URL":42}}"#] {
            let files = ZhipuSettingsFiles(data: Data(raw.utf8))
            await #expect(throws: FetchError.self) {
                try await ZhipuAdapter().discover(in: environment(files), http: UnusedHTTP())
            }
        }
    }

    @Test func knownRouteWithMalformedTokenTypeRetainsRegionalErrorAccount() async throws {
        let files = ZhipuSettingsFiles(data: settings("https://api.z.ai/api/anthropic", token: 42))
        let result = try await ZhipuAdapter().discover(in: environment(files), http: UnusedHTTP())
        #expect(result.count == 1)
        #expect(result.first?.account.region == "global")
        #expect(result.first?.secret == nil)
        guard case .schemaChanged = result.first?.connectionError else {
            Issue.record("Expected malformed token type to produce schemaChanged")
            return
        }
    }

    @Test func switchingRegionsPreservesDistinctAccountsAndRestoresIDs() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "zhipu-source-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SnapshotStore(url: directory.appending(path: "snapshot.json"))
        let files = ZhipuSettingsFiles(data: settings("https://open.bigmodel.cn/api/anthropic", token: "synthetic-cn"))
        let dependencies = Engine.Dependencies(
            adapters: [ZhipuAdapter()], environment: environment(files, enabled: false),
            makeHTTPClient: { _ in ZhipuSourceHTTP() }, store: store, ownedSecrets: FakeOwnedSecrets())
        let engine = Engine(dependencies: dependencies)
        try await engine.start()
        #expect(await engine.snapshot().accounts.isEmpty)
        try await engine.setOptionalCredentialSource(.zhipuClaudeSettings, enabled: true)
        let cnID = try #require(await engine.snapshot().accounts.first?.account.id)
        files.replace(settings("https://api.z.ai/api/anthropic", token: "synthetic-global"))
        try await engine.connectOptionalCredentialSource(.zhipuClaudeSettings)
        let switched = await engine.snapshot()
        #expect(switched.accounts.count == 2)
        let globalID = try #require(switched.accounts.first { $0.account.region == "global" }?.account.id)
        #expect(globalID != cnID)
        #expect(switched.accounts.first { $0.account.region == "cn" }?.account.id == cnID)
        files.replace(settings("https://open.bigmodel.cn/api/anthropic", token: "synthetic-cn-rotated"))
        try await engine.connectOptionalCredentialSource(.zhipuClaudeSettings)
        #expect(await engine.snapshot().accounts.count == 2)
        #expect(await engine.snapshot().accounts.first { $0.account.region == "cn" }?.account.id == cnID)
        await engine.stop()
        let restored = Engine(dependencies: dependencies)
        try await restored.start()
        let snapshot = await restored.snapshot()
        #expect(snapshot.accounts.count == 2)
        #expect(snapshot.accounts.first { $0.account.region == "cn" }?.account.id == cnID)
        #expect(snapshot.accounts.first { $0.account.region == "global" }?.account.id == globalID)
        #expect(!String(decoding: try Data(contentsOf: store.url), as: UTF8.self).contains("synthetic-cn-rotated"))
        await restored.stop()
    }

    private func settings(_ base: String, token: Any?) -> Data {
        var env: [String: Any] = ["ANTHROPIC_BASE_URL": base, "UNRELATED": ["ignored": true]]
        if let token { env["ANTHROPIC_AUTH_TOKEN"] = token }
        return try! JSONSerialization.data(withJSONObject: ["env": env, "apiKeyHelper": "must-not-execute"])
    }

    private func environment(_ files: ZhipuSettingsFiles, enabled: Bool = true) -> DiscoveryEnvironment {
        DiscoveryEnvironment(
            home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: files,
            keychain: EmptyKeychain(), allowsUserInteraction: false,
            enabledCredentialSources: enabled ? [.zhipuClaudeSettings] : [])
    }
}

private final class ZhipuSettingsFiles: FileSystem, @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data
    private var count = 0
    var accesses: Int { lock.withLock { count } }
    init(data: Data) { self.data = data }
    func replace(_ data: Data) { lock.withLock { self.data = data } }
    func exists(_ url: URL) -> Bool { lock.withLock { count += 1 }; return true }
    func modificationDate(of url: URL) throws -> Date { .distantPast }
    func contents(of url: URL) throws -> Data {
        #expect(url.path == "/synthetic/.claude/settings.json")
        return lock.withLock {
            count += 1; return data
        }
    }
}

private final class ZhipuSourceHTTP: HTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requests: Int { lock.withLock { count } }
    let expectedHost: String?
    let expectedToken: String?
    init(expectedHost: String? = nil, expectedToken: String? = nil) {
        self.expectedHost = expectedHost
        self.expectedToken = expectedToken
    }
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { count += 1 }
        #expect(request.url.scheme == "https")
        #expect(["open.bigmodel.cn", "api.z.ai"].contains(request.url.host ?? ""))
        if let expectedHost { #expect(request.url.host == expectedHost) }
        if let expectedToken { #expect(request.headers["Authorization"] == "Bearer \(expectedToken)") }
        if expectedToken == nil {
            let authorization = request.headers["Authorization"]
            if authorization == "Bearer synthetic-global" {
                #expect(request.url.host == "api.z.ai")
            } else {
                #expect(["Bearer synthetic-cn", "Bearer synthetic-cn-rotated"].contains(authorization ?? ""))
                #expect(request.url.host == "open.bigmodel.cn")
            }
        }
        #expect(request.url.path == "/api/monitor/usage/quota/limit")
        #expect(request.url.query == nil)
        return HTTPResponse(
            status: 200, headers: [:],
            body: Data(
                #"{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25}]}}"#
                    .utf8))
    }
}
