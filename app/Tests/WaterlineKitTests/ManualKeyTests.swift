import Foundation
import Testing

@testable import WaterlineKit

final class FakeOwnedSecrets: OwnedSecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [AccountID: Secret] = [:]
    private var reads: [(AccountID, Bool)] = []
    var interactiveReadIDs: [AccountID] { lock.withLock { reads.filter { $0.1 }.map { $0.0 } } }
    private var deletionFails = false
    private var writes = 0
    private var writingFails = false
    func setWriteFailure(_ value: Bool) { lock.withLock { writingFails = value } }
    func setDeletionFailure(_ value: Bool) { lock.withLock { deletionFails = value } }
    var writeCount: Int { lock.withLock { writes } }
    func contains(_ id: AccountID) -> Bool { lock.withLock { values[id] != nil } }
    func read(_ id: AccountID, interactive: Bool) throws -> Secret {
        try lock.withLock {
            reads.append((id, interactive))
            guard let value = values[id] else { throw FetchError.credentialMissing }
            return value
        }
    }
    func save(_ secret: Secret, for id: AccountID) throws {
        try lock.withLock {
            if writingFails { throw FetchError.keychainLocked }
            values[id] = secret; writes += 1
        }
    }
    func delete(_ id: AccountID) throws {
        try lock.withLock {
            if deletionFails { throw FetchError.keychainLocked }
            values[id] = nil
        }
    }
}

struct BalanceHTTPFixture: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://api.deepseek.com/user/balance")
        #expect(request.method == "GET")
        #expect(request.headers["Authorization"]?.hasPrefix("Bearer synthetic-") == true)
        return HTTPResponse(
            status: 200, headers: [:], body: Data(#"{"balance_infos":[{"currency":"CNY","total_balance":"12"}]}"#.utf8))
    }
}

struct ManualKeyTests {
    @Test func reconnectCompletionAfterStopDoesNotRestoreOperationState() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "reconnect-stop-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let transport = ReconnectDelayedHTTP()
        let keys = FakeOwnedSecrets()
        var deps = dependencies(url, store: keys)
        deps.makeHTTPClient = { _ in transport }
        let subject = Engine(dependencies: deps)
        try await subject.start()
        let id = try await subject.addManualAccount(provider: .deepseek, key: Secret("synthetic-key"))
        await transport.holdNext()
        let pending = Task { try await subject.reconnectManualAccount(id) }
        await transport.waitForBlocked()
        await subject.stop()
        await transport.release()
        try await pending.value
        #expect(await subject.operations.isEmpty)
    }

    @Test func manualReconnectReadsOnlyChosenAccountWithoutRewritingKey() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "manual-reconnect-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let subject = Engine(dependencies: dependencies(url, store: store))
        try await subject.start()
        let first = try await subject.addManualAccount(provider: .deepseek, key: Secret("synthetic-first"))
        _ = try await subject.addManualAccount(provider: .deepseek, key: Secret("synthetic-second"))
        let writes = store.writeCount
        try await subject.reconnectManualAccount(first)
        #expect(store.interactiveReadIDs == [first])
        #expect(store.writeCount == writes)
        #expect(
            await subject.snapshot().accounts.first(where: { $0.account.id == first })?.state.hasCurrentResponse == true
        )
        await subject.stop()
    }

    func dependencies(_ url: URL, store: FakeOwnedSecrets) -> Engine.Dependencies {
        .init(
            adapters: [DeepSeekAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in BalanceHTTPFixture() },
            store: SnapshotStore(url: url), ownedSecrets: store)
    }

    @Test func addRotateRestoreAndRemoveStayWithinOwnedStore() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-manual-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let deps = dependencies(url, store: store)
        let engine = Engine(dependencies: deps)
        let id = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-first"), label: "Work")
        try await engine.setAccountPinned(id, pinned: true)
        try await engine.replaceManualKey(id, key: Secret("synthetic-replacement"))
        let secondID = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-second"))
        let config = try String(
            contentsOf: url.deletingLastPathComponent().appending(path: "configuration.json"), encoding: .utf8)
        #expect(!config.contains("synthetic-first") && !config.contains("synthetic-replacement"))
        #expect(try !String(contentsOf: url, encoding: .utf8).contains("synthetic-replacement"))
        await engine.stop()
        let restored = Engine(dependencies: deps)
        try await restored.start()
        try await restored.refreshAll()
        let snapshot = await restored.snapshot()
        #expect(snapshot.accounts.count == 2)
        #expect(Set(snapshot.accounts.map(\.account.id)) == [id, secondID])
        #expect(snapshot.accounts.first { $0.account.id == id }?.preferences.pinned == true)
        #expect(snapshot.accounts.first { $0.account.id == id }?.preferences.label == "Work")
        #expect(snapshot.accounts.allSatisfy { $0.state.reading?.usage.balances.first?.amount == 12 })
        try await restored.removeAccount(id)
        #expect(!store.contains(id))
        #expect(store.contains(secondID))
        await restored.stop()
    }

    @Test func cliAddUsesInjectedStdinAndNeverPrintsTheKey() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-manual-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let deps = dependencies(url, store: store)
        let missing = await WaterlineCLI.run(["account", "add", "deepseek", "--stdin"], dependencies: deps)
        #expect(missing.exitCode == 64)
        #expect(store.writeCount == 0)
        let result = await WaterlineCLI.run(
            ["account", "add", "deepseek", "--stdin", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-cli-key"))
        #expect(result.exitCode == 0)
        #expect(!result.output.contains("synthetic-cli-key") && !result.error.contains("synthetic-cli-key"))
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.accounts.first?.state.reading?.usage.balances.first?.amount == 12)
    }

    @Test func rejectedReplacementKeyReturnsFailureWithoutLosingIdentity() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-manual-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        var deps = dependencies(url, store: store)
        let engine = Engine(dependencies: deps)
        let id = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-first"))
        await engine.stop()
        deps.makeHTTPClient = { _ in UnauthorizedHTTPFixture() }
        let result = await WaterlineCLI.run(
            ["account", "key", id.rawValue, "--stdin", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-rejected"))
        #expect(result.exitCode == 2)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.accounts.first?.account.id == id)
        #expect(snapshot.accounts.first?.state.reading?.usage.balances.first?.amount == 12)
        #expect(!result.output.contains("synthetic-rejected"))
    }

    @Test func blankKeyAndConfigFailureNeverWriteASecret() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-manual-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let engine = Engine(dependencies: dependencies(url, store: store))
        await #expect(throws: ManualKeyError.self) {
            try await engine.addManualAccount(provider: .deepseek, key: Secret("  "))
        }
        #expect(store.writeCount == 0)
        try await engine.start()
        let config = url.deletingLastPathComponent().appending(path: "configuration.json")
        try FileManager.default.removeItem(at: config)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: false)
        do {
            _ = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-valid"));
            Issue.record("Expected config failure")
        } catch {}
        #expect(store.writeCount == 0)
        await engine.stop()
    }

    @Test func failedKeyWriteLeavesRecoverableMetadataWithoutASecret() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-manual-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        store.setWriteFailure(true)
        let engine = Engine(dependencies: dependencies(url, store: store))
        await #expect(throws: ManualKeyError.self) {
            try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-key"))
        }
        let id = try #require(await engine.snapshot().accounts.first?.account.id)
        #expect(!store.contains(id))
        #expect(await engine.snapshot().accounts.count == 1)
        store.setWriteFailure(false)
        try await engine.replaceManualKey(id, key: Secret("synthetic-retry"))
        #expect(await engine.snapshot().accounts.first?.account.id == id)
        #expect(await engine.snapshot().accounts.first?.state.reading?.usage.balances.first?.amount == 12)
        await engine.stop()
    }

    @Test func failedKeyDeletionIsVisibleAndRetriedOnRestart() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-manual-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let deps = dependencies(url, store: store)
        let engine = Engine(dependencies: deps)
        let id = try await engine.addManualAccount(provider: .deepseek, key: Secret("synthetic-key"))
        store.setDeletionFailure(true)
        await #expect(throws: ManualKeyError.self) { try await engine.removeAccount(id) }
        #expect(await engine.snapshot().pendingSecretCleanup == 1)
        #expect(store.contains(id))
        await engine.stop()
        store.setDeletionFailure(false)
        let restored = Engine(dependencies: deps)
        try await restored.start()
        #expect(!store.contains(id))
        #expect(await restored.snapshot().pendingSecretCleanup == 0)
        #expect(await restored.snapshot().accounts.isEmpty)
        await restored.stop()
    }
}

private struct UnauthorizedHTTPFixture: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        HTTPResponse(status: 401, headers: [:], body: Data())
    }
}

private actor KeyVersionHTTP: HTTPClient {
    var rejected = 0
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if request.headers["Authorization"] == "Bearer synthetic-bad" {
            rejected += 1
            return HTTPResponse(status: 401, headers: [:], body: Data())
        }
        return HTTPResponse(
            status: 200, headers: [:], body: Data(#"{"balance_infos":[{"currency":"CNY","total_balance":"12"}]}"#.utf8))
    }
}

extension ManualKeyTests {
    @Test func rejectedNewKeyDoesNotLookChangedAgainOnRestart() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-key-version-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let http = KeyVersionHTTP()
        var deps = dependencies(url, store: store)
        deps.makeHTTPClient = { _ in http }
        let first = Engine(dependencies: deps)
        let id = try await first.addManualAccount(provider: .deepseek, key: Secret("synthetic-good"))
        await first.stop()
        let second = Engine(dependencies: deps)
        try await second.start()
        try await second.replaceManualKey(id, key: Secret("synthetic-bad"))
        await second.stop()
        let third = Engine(dependencies: deps)
        try await third.start(); try await third.refreshAll()
        #expect(await http.rejected == 1)
        await third.stop()
    }
}

private actor ReconnectDelayedHTTP: HTTPClient {
    var hold = false
    var pending: CheckedContinuation<Void, Never>?
    var waiting: [CheckedContinuation<Void, Never>] = []
    func holdNext() { hold = true }
    func waitForBlocked() async {
        if pending != nil { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func release() { pending?.resume(); pending = nil }
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if hold {
            hold = false
            await withCheckedContinuation {
                pending = $0
                for waiter in waiting { waiter.resume() }
                waiting.removeAll()
            }
        }
        return HTTPResponse(
            status: 200, headers: [:], body: Data(#"{"balance_infos":[{"currency":"CNY","total_balance":"12"}]}"#.utf8))
    }
}
