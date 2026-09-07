import Foundation
import Testing

@testable import WaterlineKit

struct DeepSeekSettingsSourceTests {
    @Test func optInPrecedesReadAndUnrelatedSettingsAreIgnored() async throws {
        let files = SettingsFiles(data: settings("https://api.deepseek.com/anthropic", token: "synthetic-config"))
        #expect(
            try await DeepSeekAdapter().discover(in: environment(files, enabled: false), http: UnusedHTTP()).isEmpty)
        #expect(files.reads == 0)
        let result = try await DeepSeekAdapter().discover(in: environment(files, enabled: true), http: UnusedHTTP())
        #expect(result.first?.secret?.value == "synthetic-config")
        #expect(result.first?.account.optionalCredentialSource == .deepSeekClaudeSettings)
        #expect(files.reads == 1)
    }

    @Test(arguments: [
        "http://api.deepseek.com/anthropic", "https://api.deepseek.com.evil.example/anthropic",
        "https://proxy.example/anthropic", "https://api.deepseek.com:444/anthropic", "https://api.deepseek.com/other",
        "https://api.deepseek.com/anthropic?key=invalid", "https://user@api.deepseek.com/anthropic",
    ])
    func unknownRoutingDoesNotCreateADeepSeekAccount(_ base: String) async throws {
        let files = SettingsFiles(data: settings(base, token: 42))
        #expect(try await DeepSeekAdapter().discover(in: environment(files, enabled: true), http: UnusedHTTP()).isEmpty)
    }

    @Test func placeholdersAndMalformedFilesNeverBecomeSecrets() async throws {
        for data in [settings("https://api.deepseek.com/anthropic", token: "$OTHER_KEY"), Data("not-json".utf8)] {
            let result = try await DeepSeekAdapter().discover(
                in: environment(SettingsFiles(data: data), enabled: true), http: UnusedHTTP())
            #expect(result.first?.secret == nil)
            #expect(result.first?.connectionError != nil)
        }
    }

    @Test func settingsRotationPreservesIdentityAndSourceBytes() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: "deepseek-settings-\(UUID())")
        defer { try? FileManager.default.removeItem(at: home) }
        let config = home.appending(path: ".claude/settings.json")
        try FileManager.default.createDirectory(
            at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = settings("https://api.deepseek.com/anthropic", token: "synthetic-old")
        try original.write(to: config)
        let store = SnapshotStore(url: home.appending(path: "waterline/snapshot.json"))
        let engine = Engine(
            dependencies: .init(
                adapters: [DeepSeekAdapter()],
                environment: DiscoveryEnvironment(
                    home: home, processEnvironment: [:], fileSystem: RealFileSystem(), keychain: EmptyKeychain(),
                    allowsUserInteraction: false),
                makeHTTPClient: { _ in SettingsHTTP() }, store: store, ownedSecrets: FakeOwnedSecrets()))
        try await engine.start()
        #expect(await engine.snapshot().accounts.isEmpty)
        try await engine.setOptionalCredentialSource(.deepSeekClaudeSettings, enabled: true)
        let id = try #require(await engine.snapshot().accounts.first?.account.id)
        #expect(try Data(contentsOf: config) == original)
        let replacement = settings("https://api.deepseek.com/anthropic", token: "synthetic-new")
        try replacement.write(to: config)
        try await engine.connectOptionalCredentialSource(.deepSeekClaudeSettings)
        #expect(await engine.snapshot().accounts.first?.account.id == id)
        #expect(try Data(contentsOf: config) == replacement)
        let snapshotData = try Data(contentsOf: store.url)
        #expect(!String(decoding: snapshotData, as: UTF8.self).contains("synthetic-new"))
        await engine.stop()
    }

    @Test func boundedReaderRejectsOversizedAndNonFileInputs() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "bounded-read-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "test.json")
        try Data("12345".utf8).write(to: file)
        #expect(try RealFileSystem().contents(of: file, maximumBytes: 5) == Data("12345".utf8))
        #expect(throws: FileBoundaryError.tooLarge) { try RealFileSystem().contents(of: file, maximumBytes: 4) }
        #expect(throws: FileBoundaryError.notRegularFile) {
            try RealFileSystem().contents(of: directory, maximumBytes: 4)
        }
        #expect(throws: FileBoundaryError.invalidLimit) { try RealFileSystem().contents(of: file, maximumBytes: -1) }
    }

    private func settings(_ base: String, token: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "env": [
                "ANTHROPIC_BASE_URL": base, "ANTHROPIC_AUTH_TOKEN": token,
                "UNRELATED": ["not": "a string"],
            ], "apiKeyHelper": "must-not-execute", "hooks": ["must-not-execute"],
        ])
    }
    private func environment(_ files: SettingsFiles, enabled: Bool) -> DiscoveryEnvironment {
        DiscoveryEnvironment(
            home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: files,
            keychain: EmptyKeychain(), allowsUserInteraction: false,
            enabledCredentialSources: enabled ? [.deepSeekClaudeSettings] : [])
    }
}

private final class SettingsFiles: FileSystem, @unchecked Sendable {
    let data: Data
    private let lock = NSLock()
    private var count = 0
    var reads: Int { lock.withLock { count } }
    init(data: Data) { self.data = data }
    func exists(_ url: URL) -> Bool { true }
    func modificationDate(of url: URL) throws -> Date { .distantPast }
    func contents(of url: URL) throws -> Data { lock.withLock { count += 1 }; return data }
}
private struct SettingsHTTP: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://api.deepseek.com/user/balance")
        return HTTPResponse(
            status: 200, headers: [:], body: Data(#"{"balance_infos":[{"currency":"USD","total_balance":"20"}]}"#.utf8))
    }
}
