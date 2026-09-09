import Foundation
import SQLite3
import Testing

@testable import WaterlineKit

struct CursorRecoveryTests {
    @Test func busyDatabaseRecoversWithoutBeingCalledSchemaChange() throws {
        let fixture = try CursorDatabaseFixture()
        defer { fixture.close() }
        try fixture.execute("BEGIN EXCLUSIVE")
        let clock = ContinuousClock()
        let started = clock.now
        do {
            _ = try SystemCredentialDatabase().cursorAccessToken(at: fixture.url)
            Issue.record("Expected a busy database failure")
        } catch let error as FetchError {
            guard case .transport = error else { Issue.record("A lock is not a schema change"); return }
        }
        #expect(started.duration(to: clock.now) < .seconds(2))
        try fixture.execute("ROLLBACK")
        #expect(try SystemCredentialDatabase().cursorAccessToken(at: fixture.url)?.value == fixture.token)
    }

    @Test func walReaderSeesCommittedRotationOnly() throws {
        let fixture = try CursorDatabaseFixture()
        defer { fixture.close() }
        try fixture.execute("PRAGMA journal_mode=WAL")
        try fixture.execute("PRAGMA wal_autocheckpoint=0")
        try fixture.execute("BEGIN IMMEDIATE")
        try fixture.execute("UPDATE ItemTable SET value='synthetic-rotated'")
        let reader = SystemCredentialDatabase()
        #expect(try reader.cursorAccessToken(at: fixture.url)?.value == fixture.token)
        try fixture.execute("COMMIT")
        let wal = URL(fileURLWithPath: fixture.url.path + "-wal")
        let databaseBytes = try Data(contentsOf: fixture.url)
        let walBytes = try Data(contentsOf: wal)
        #expect(try reader.cursorAccessToken(at: fixture.url)?.value == "synthetic-rotated")
        #expect(try Data(contentsOf: fixture.url) == databaseBytes)
        #expect(try Data(contentsOf: wal) == walBytes)
    }

    @Test func reconnectRotationAndRestartPreserveCursorAccount() async throws {
        let fixture = try CursorDatabaseFixture()
        defer { fixture.close() }
        let storeURL = fixture.home.appending(path: "Waterline/snapshot.json")
        let http = RecoveryCursorHTTP()
        let dependencies = Engine.Dependencies(
            adapters: [CursorAdapter()],
            environment: DiscoveryEnvironment(
                home: fixture.home, processEnvironment: [:],
                fileSystem: RealFileSystem(), keychain: EmptyKeychain(), allowsUserInteraction: false,
                credentialDatabase: SystemCredentialDatabase()),
            makeHTTPClient: { hosts in
                #expect(hosts == ["cursor.com"])
                return http
            }, store: SnapshotStore(url: storeURL), ownedSecrets: FakeOwnedSecrets())
        let engine = Engine(dependencies: dependencies)
        try await engine.start()
        try await engine.refreshAll()
        let id = try #require(await engine.snapshot().accounts.first?.account.id)
        try await engine.renameAccount(id, label: "Work")
        try await engine.setAccountPinned(id, pinned: true)
        let rotated = fixture.token.replacingOccurrences(of: ".signature", with: ".rotated")
        try fixture.execute("UPDATE ItemTable SET value='\(rotated)'")
        try await engine.connect(provider: .cursor)
        #expect(await http.cookies.last?.hasSuffix(".rotated") == true)
        #expect(await engine.snapshot().accounts.count == 1)
        await engine.stop()
        let restored = Engine(dependencies: dependencies)
        try await restored.start()
        let row = try #require(await restored.snapshot().accounts.first)
        #expect(row.account.id == id)
        #expect(row.preferences.label == "Work" && row.preferences.pinned)
        #expect(row.state.reading?.usage.quotaWindows.first?.usedFraction == 0.2)
        await restored.stop()
    }
}

private final class CursorDatabaseFixture {
    let home: URL
    let url: URL
    let token: String
    private var database: OpaquePointer?

    init() throws {
        home = FileManager.default.temporaryDirectory.appending(path: "cursor-recovery-\(UUID())")
        url = home.appending(path: "Library/Application Support/Cursor/User/globalStorage/state.vscdb")
        let claims = Data(#"{"sub":"auth0|test-account"}"#.utf8).base64EncodedString().replacingOccurrences(
            of: "=", with: "")
        token = "header.\(claims).signature"
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &database) == SQLITE_OK else { throw FixtureError.database }
        try execute("CREATE TABLE ItemTable(key TEXT PRIMARY KEY, value TEXT)")
        try execute("INSERT INTO ItemTable VALUES('cursorAuth/accessToken','\(token)')")
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw FixtureError.database }
    }

    func close() {
        sqlite3_close(database)
        database = nil
        try? FileManager.default.removeItem(at: home)
    }
    private enum FixtureError: Error { case database }
}

private actor RecoveryCursorHTTP: HTTPClient {
    var cookies: [String] = []
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        cookies.append(request.headers["Cookie"] ?? "")
        let body =
            request.method == "GET"
            ? #"{"individualUsage":{"plan":{"totalPercentUsed":20}}}"#
            : #"{"hasNonZeroIncludedLimit":false}"#
        return HTTPResponse(status: 200, headers: [:], body: Data(body.utf8))
    }
}
