import Foundation
import Testing

@testable import WaterlineKit

struct ConfiguredSourceRefreshTests {
    @Test func backgroundRotationIsScopedAndDisabledFileIsNotRead() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        let engine = fixture.engine
        try await engine.start()
        try await engine.setOptionalCredentialSource(.deepSeekEnvironment, enabled: true)
        try await engine.setOptionalCredentialSource(.deepSeekClaudeSettings, enabled: true)
        try fixture.write("synthetic-two")
        await engine.checkChangedFileCredentials()
        try await engine.refreshAll(manual: false)
        #expect(await fixture.http.headers == ["Bearer synthetic-env", "Bearer synthetic-one", "Bearer synthetic-two"])
        try await engine.setOptionalCredentialSource(.deepSeekClaudeSettings, enabled: false)
        let reads = fixture.files.reads
        try fixture.write("synthetic-three")
        await engine.checkChangedFileCredentials()
        #expect(fixture.files.reads == reads)
        await engine.stop()
    }

    @Test func repairedSourceCanRefreshWithoutWaitingForOldNormalDeadline() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        try await fixture.engine.start()
        try await fixture.engine.setOptionalCredentialSource(.deepSeekClaudeSettings, enabled: true)
        try Data("broken".utf8).write(to: fixture.config)
        await fixture.engine.checkChangedFileCredentials()
        try fixture.write("synthetic-one")
        await fixture.engine.checkChangedFileCredentials()
        try await fixture.engine.refreshAll(manual: false)
        #expect(await fixture.http.headers.count == 2)
        #expect(await fixture.engine.snapshot().accounts.first?.state.hasCurrentResponse == true)
        await fixture.engine.stop()
    }

    @Test(arguments: [401, 403]) func sourceDisappearanceCannotBypassAuthenticationParking(_ status: Int) async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        await fixture.http.setStatus(status)
        try await fixture.engine.start()
        try await fixture.engine.setOptionalCredentialSource(.deepSeekClaudeSettings, enabled: true)
        try FileManager.default.removeItem(at: fixture.config)
        await fixture.engine.checkChangedFileCredentials()
        try fixture.write("synthetic-one")
        await fixture.engine.checkChangedFileCredentials()
        try await fixture.engine.refreshAll()
        #expect(await fixture.http.headers.count == 1)
        let state = await fixture.engine.snapshot().accounts.first?.state
        #expect(state == .unavailable(error: status == 401 ? .unauthorized : .permissionDenied))
        await fixture.http.setStatus(200)
        try fixture.write("synthetic-new")
        await fixture.engine.checkChangedFileCredentials()
        try await fixture.engine.refreshAll(manual: false)
        #expect(await fixture.http.headers.count == 2)
        #expect(await fixture.engine.snapshot().accounts.first?.state.hasCurrentResponse == true)
        await fixture.engine.stop()
    }
}

private final class Fixture {
    let home: URL
    let config: URL
    let files = TrackingFiles()
    let http = WatchedHTTP()
    let engine: Engine
    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: "config-watch-\(UUID())")
        config = home.appending(path: ".claude/settings.json")
        try FileManager.default.createDirectory(
            at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        engine = Engine(
            dependencies: .init(
                adapters: [DeepSeekAdapter()],
                environment: DiscoveryEnvironment(
                    home: home, processEnvironment: ["DEEPSEEK_API_KEY": "synthetic-env"], fileSystem: files,
                    keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { [http] _ in http },
                store: SnapshotStore(url: home.appending(path: "waterline/snapshot.json")),
                ownedSecrets: FakeOwnedSecrets()))
        try write("synthetic-one")
    }
    func write(_ key: String) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "env": ["ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic", "ANTHROPIC_AUTH_TOKEN": key]
        ])
        try data.write(to: config)
    }
    func clean() { try? FileManager.default.removeItem(at: home) }
}
private final class TrackingFiles: FileSystem, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var reads: Int { lock.withLock { count } }
    func exists(_ url: URL) -> Bool { RealFileSystem().exists(url) }
    func modificationDate(of url: URL) throws -> Date { try RealFileSystem().modificationDate(of: url) }
    func contents(of url: URL) throws -> Data {
        lock.withLock { count += 1 }; return try RealFileSystem().contents(of: url)
    }
    func contents(of url: URL, maximumBytes: Int) throws -> Data {
        lock.withLock { count += 1 }; return try RealFileSystem().contents(of: url, maximumBytes: maximumBytes)
    }
}
private actor WatchedHTTP: HTTPClient {
    var headers: [String] = []
    private var status = 200
    func setStatus(_ status: Int) { self.status = status }
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        headers.append(request.headers["Authorization"] ?? "")
        return HTTPResponse(
            status: status, headers: [:],
            body: Data(#"{"balance_infos":[{"currency":"USD","total_balance":"20"}]}"#.utf8))
    }
}
