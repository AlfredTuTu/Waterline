import Foundation
import Testing

@testable import WaterlineKit

struct RecoveryTests {
    @Test func sleepInvalidatesOldRequestAndRecoveryAcceptsOnlyNewResult() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-recovery-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let gate = CompletionGate()
        let subject = engine([GoodAdapter(gate: gate)], at: url)
        try await subject.start()
        let old = Task { try await subject.refreshAll() }
        await gate.waitForFirst()
        await subject.suspendForSleep()
        try await subject.recoverAfterInterruption()
        #expect(amount(await subject.snapshot()) == 20)
        await gate.completeOldRequest()
        try await old.value
        #expect(amount(await subject.snapshot()) == 20)
        try await subject.recoverAfterInterruption()
        #expect(await gate.callCount == 2)
        await subject.stop()
    }

    @Test func suspendedEngineDoesNotStartRequests() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-recovery-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        await subject.suspendForSleep()
        try await subject.refreshAll()
        #expect(amount(await subject.snapshot()) == nil)
        try await subject.recoverAfterInterruption()
        #expect(amount(await subject.snapshot()) == 20)
        await subject.stop()
    }
}

private actor RecoveryCounter {
    var count = 0
    func increment() { count += 1 }
}

private struct LimitedRecoveryAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor { GoodAdapter.descriptor }
    let counter: RecoveryCounter
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "limited-recovery"), provider: .deepseek,
                    credential: .file(path: "/synthetic/limited")), secret: Secret("synthetic-key"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        await counter.increment()
        throw FetchError.rateLimited(retryAfter: 120)
    }
}

extension RecoveryTests {
    @Test func wakeDoesNotBypassServerWait() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-recovery-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let counter = RecoveryCounter()
        let subject = engine([LimitedRecoveryAdapter(counter: counter)], at: url)
        try await subject.start()
        try await subject.refreshAll()
        await subject.suspendForSleep()
        try await subject.recoverAfterInterruption()
        #expect(await counter.count == 1)
        await subject.stop()
    }
}

private actor DiscoveryGate {
    var first: CheckedContinuation<Void, Never>?
    var waiter: CheckedContinuation<Void, Never>?
    var calls = 0
    func discover() async {
        calls += 1
        if calls == 1 {
            await withCheckedContinuation {
                first = $0; waiter?.resume(); waiter = nil
            }
        }
    }
    func waitUntilStarted() async {
        if first != nil { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() { first?.resume(); first = nil }
}

private struct InterruptedDiscoveryAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor { GoodAdapter.descriptor }
    let gate: DiscoveryGate
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        await gate.discover()
        return [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "after-wake"), provider: .deepseek,
                    credential: .file(path: "/synthetic/after-wake")), secret: Secret("synthetic-key"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage { reading(20) }
}

extension RecoveryTests {
    @Test func wakeFinishesInterruptedStartupDiscovery() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-recovery-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let gate = DiscoveryGate()
        let subject = engine([InterruptedDiscoveryAdapter(gate: gate)], at: url)
        let starting = Task { try await subject.start() }
        await gate.waitUntilStarted()
        await subject.suspendForSleep()
        try await subject.recoverAfterInterruption()
        #expect(await subject.snapshot().accounts.count == 1)
        #expect(amount(await subject.snapshot()) == 20)
        await gate.release()
        try await starting.value
        #expect(await subject.snapshot().accounts.count == 1)
        await subject.stop()
    }
}
