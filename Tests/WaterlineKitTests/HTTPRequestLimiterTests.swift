import Foundation
import Testing

@testable import WaterlineKit

struct HTTPRequestLimiterTests {
    @Test func localAndRemoteOperationsShareTheSameRequestSlots() async throws {
        let limiter = HTTPRequestLimiter()
        let probe = BlockingTransport()
        let client = LimitedHTTPClient(client: probe, limiter: limiter)
        let request = HTTPRequest(url: URL(string: "https://synthetic.example/usage")!)
        let remote = (0..<4).map { _ in Task { try await client.send(request) } }
        #expect(await eventually { await probe.active == 4 })
        let local = Task { try await client.withRequestPermit { try await probe.send(request) } }
        #expect(await eventually { await limiter.waitingCount == 1 })
        #expect(await probe.total == 4)
        await probe.open()
        for task in remote { _ = try await task.value }
        _ = try await local.value
        #expect(await probe.peak == 4)
        #expect(await probe.total == 5)
    }

    @Test func overlappingProviderRefreshesShareFourRequestSlots() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "limiter-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let probe = BlockingTransport()
        let engine = Engine(
            dependencies: .init(
                adapters: [FirstNetworkAdapter(), SecondNetworkAdapter()],
                environment: DiscoveryEnvironment(
                    home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                    fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in probe }, store: SnapshotStore(url: url), ownedSecrets: FakeOwnedSecrets()))
        try await engine.start()
        let first = Task { try await engine.refreshAll(provider: .codex) }
        let second = Task { try await engine.refreshAll(provider: .cursor) }
        let limiter = await engine.requestLimiter
        let reachedQueue = await eventually { await limiter.waitingCount >= 4 }
        #expect(reachedQueue)
        #expect(await probe.active == 4)
        await probe.open()
        try await first.value
        try await second.value
        #expect(await probe.peak == 4)
        #expect(await probe.total == 10)
        #expect(await engine.snapshot().accounts.allSatisfy { $0.state.hasCurrentResponse })
        await engine.stop()
    }

    @Test(arguments: [false, true])
    func cancelledQueuedRequestNeverReachesTransport(local: Bool) async throws {
        let limiter = HTTPRequestLimiter()
        let probe = BlockingTransport()
        let client = LimitedHTTPClient(client: probe, limiter: limiter)
        let request = HTTPRequest(url: URL(string: "https://synthetic.example/usage")!)
        let first = (0..<4).map { _ in Task { try await client.send(request) } }
        #expect(await eventually { await probe.active == 4 })
        let queued = Task {
            if local { return try await client.withRequestPermit { try await probe.send(request) } }
            return try await client.send(request)
        }
        #expect(await eventually { await limiter.waitingCount == 1 })
        queued.cancel()
        #expect(await eventually { await limiter.waitingCount == 0 })
        await probe.open()
        for task in first { _ = try await task.value }
        await #expect(throws: CancellationError.self) { try await queued.value }
        #expect(await probe.total == 4)
        _ = try await client.send(request)
        #expect(await probe.total == 5)
    }

    private func eventually(_ predicate: () async -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let end = clock.now.advanced(by: .seconds(2))
        while clock.now < end {
            if await predicate() { return true }
            await Task.yield()
        }
        return false
    }
}

private actor BlockingTransport: HTTPClient {
    var active = 0
    var peak = 0
    var total = 0
    private var opened = false
    private var pending: [CheckedContinuation<Void, Never>] = []
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        active += 1
        total += 1
        peak = max(peak, active)
        if !opened { await withCheckedContinuation { pending.append($0) } }
        active -= 1
        return HTTPResponse(status: 200, headers: [:], body: Data())
    }
    func open() {
        opened = true
        for continuation in pending { continuation.resume() }
        pending.removeAll()
    }
}

private func discoveredAccounts(_ provider: Provider) -> [Discovered] {
    (0..<5).map { index in
        Discovered(
            account: Account(
                id: AccountID(rawValue: "\(provider.rawValue)-\(index)"), provider: provider,
                credential: .file(path: "/synthetic/\(provider.rawValue)/\(index)")), secret: Secret("synthetic"))
    }
}
private func networkFetch(_ http: any HTTPClient) async throws -> Usage {
    _ = try await http.send(HTTPRequest(url: URL(string: "https://synthetic.example/usage")!))
    return reading(20)
}
private struct FirstNetworkAdapter: ProviderAdapter {
    static let descriptor = ProviderDescriptor(
        provider: .codex, kind: .balance, docStatus: .community,
        allowedHosts: ["synthetic.example"], consoleURL: URL(string: "https://synthetic.example")!)
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        discoveredAccounts(.codex)
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        try await networkFetch(http)
    }
}
private struct SecondNetworkAdapter: ProviderAdapter {
    static let descriptor = ProviderDescriptor(
        provider: .cursor, kind: .balance, docStatus: .community,
        allowedHosts: ["synthetic.example"], consoleURL: URL(string: "https://synthetic.example")!)
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        discoveredAccounts(.cursor)
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        try await networkFetch(http)
    }
}
