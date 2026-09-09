import Foundation
import Testing

@testable import WaterlineKit

struct EmptyFiles: FileSystem {
    func contents(of url: URL) throws -> Data { throw FetchError.credentialMissing }
    func modificationDate(of url: URL) throws -> Date { throw FetchError.credentialMissing }
    func exists(_ url: URL) -> Bool { false }
}
struct EmptyKeychain: KeychainReading {
    func items(service: String) throws -> [KeychainItem] { [] }
    func secret(for item: KeychainItem, allowsUserInteraction: Bool) throws -> Secret {
        throw FetchError.credentialMissing
    }
}
struct UnusedHTTP: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        fatalError("No network requests are allowed in these probes")
    }
}
func reading(_ amount: Int) -> Usage { .balance(balance: Balance(amount: Decimal(amount), currency: "USD", gift: nil)) }
actor CompletionGate {
    var callCount = 0
    var first: CheckedContinuation<Usage, Never>?
    var started: CheckedContinuation<Void, Never>?
    func fetch() async -> Usage {
        callCount += 1
        if callCount == 1 {
            return await withCheckedContinuation { continuation in
                first = continuation
                started?.resume()
                started = nil
            }
        }
        return reading(20)
    }
    func waitForFirst() async {
        if first != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func completeOldRequest() {
        first?.resume(returning: reading(10))
        first = nil
    }
}
struct GoodAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            provider: .deepseek, kind: .balance, docStatus: .official, allowedHosts: [],
            consoleURL: URL(string: "https://example.invalid")!)
    }
    let gate: CompletionGate?
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        let secret = Secret("SYNTHETIC_AUDIT_CREDENTIAL")
        let account = Account(
            id: AccountID(rawValue: "synthetic-deepseek"), provider: .deepseek,
            credential: .file(path: "/synthetic/account"))
        return [Discovered(account: account, secret: secret)]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        if let gate { return await gate.fetch() }
        return reading(20)
    }
}
struct FailingDiscovery: ProviderAdapter {
    static var descriptor: ProviderDescriptor {
        ProviderDescriptor(
            provider: .cursor, kind: .window, docStatus: .community, allowedHosts: [],
            consoleURL: URL(string: "https://example.invalid")!)
    }
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        throw FetchError.schemaChanged(detail: "synthetic source")
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        fatalError("No fetch expected")
    }
}
func engine(
    _ adapters: [any ProviderAdapter], at url: URL, now: Date = Date(timeIntervalSince1970: 1_800_000_000)
) -> Engine {
    Engine(
        dependencies: Engine.Dependencies(
            adapters: adapters,
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in UnusedHTTP() },
            store: SnapshotStore(url: url), now: { now }))
}
func amount(_ snapshot: Snapshot) -> Decimal? {
    guard let usage = snapshot.accounts.first?.state.reading?.usage else { return nil }
    if case .balance(let balance) = usage { return balance.amount }
    return nil
}

struct EngineRegressionTests {
    func temporaryStore() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "waterline-tests-\(UUID())/snapshot.json")
    }

    @Test func repeatedStartDoesNotDuplicateAccounts() async throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        try await subject.start()
        #expect(await subject.snapshot().accounts.count == 1)
    }

    @Test func discoveryFailureDoesNotHideHealthySource() async throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([FailingDiscovery(), GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        #expect(await subject.snapshot().accounts.count == 1)
        #expect(await subject.snapshot().sourceFailures.first?.provider == .cursor)
    }

    @Test func lateResultCannotOverwriteNewerRefresh() async throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let gate = CompletionGate()
        let subject = engine([GoodAdapter(gate: gate)], at: url)
        try await subject.start()
        let old = Task { try await subject.refreshAll() }
        await gate.waitForFirst()
        try await subject.refreshAll(superseding: true)
        #expect(amount(await subject.snapshot()) == 20)
        await gate.completeOldRequest()
        try await old.value
        #expect(amount(await subject.snapshot()) == 20)
    }

    @Test func subscribersReceiveCurrentStateAndStorageFailure() async throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        let stream = await subject.updates
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.accounts.count == 1)
        // Replace the destination with a directory to produce a real, isolated filesystem failure.
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        do {
            try await subject.refreshAll()
            Issue.record("A failed write must not report success")
        } catch {}
        let update = await iterator.next()
        #expect(update?.storageFailed == true)
        #expect(update.flatMap(amount) == 20)
        #expect(await subject.storageFailed)
    }

    @Test func writerOwnershipBlocksSecondEngineUntilStop() async throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = engine([GoodAdapter(gate: nil)], at: url)
        let second = engine([GoodAdapter(gate: nil)], at: url)
        try await first.start()
        await #expect(throws: WriterLockError.busy) { try await second.start() }
        #expect(try SnapshotStore(url: url).load()?.accounts.count == 1)
        await first.stop()
        try await second.start()
        #expect(await second.snapshot().accounts.count == 1)
        await second.stop()
    }

    @Test func stopInvalidatesLateResult() async throws {
        let url = temporaryStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let gate = CompletionGate()
        let subject = engine([GoodAdapter(gate: gate)], at: url)
        try await subject.start()
        let refresh = Task { try await subject.refreshAll() }
        await gate.waitForFirst()
        await subject.stop()
        await gate.completeOldRequest()
        try await refresh.value
        #expect(amount(await subject.snapshot()) == nil)
        #expect(try SnapshotStore(url: url).load().flatMap(amount) == nil)
    }

    @Test func secretDescriptionsAreRedacted() {
        let secret = Secret("SYNTHETIC_AUDIT_CREDENTIAL")
        #expect(!String(describing: secret).contains(secret.value))
        #expect(!String(reflecting: secret).contains(secret.value))
        var dumped = ""
        dump(secret, to: &dumped)
        #expect(!dumped.contains(secret.value))
    }
}
