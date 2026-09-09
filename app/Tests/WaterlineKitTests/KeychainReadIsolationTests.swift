import Foundation
import Testing

@testable import WaterlineKit

private final class WaitingKeyStore: OwnedSecretStoring, @unchecked Sendable {
    private let condition = NSCondition()
    private let backing = FakeOwnedSecrets()
    private var entered = false
    private var released = false
    private var observers: [CheckedContinuation<Void, Never>] = []

    func read(_ id: AccountID, interactive: Bool) throws -> Secret {
        if interactive {
            condition.lock()
            entered = true
            let ready = observers
            observers.removeAll()
            for observer in ready { observer.resume() }
            while !released { condition.wait() }
            condition.unlock()
        }
        return try backing.read(id, interactive: interactive)
    }
    func save(_ secret: Secret, for id: AccountID) throws { try backing.save(secret, for: id) }
    func delete(_ id: AccountID) throws { try backing.delete(id) }
    func waitUntilReading() async {
        await withCheckedContinuation { continuation in
            condition.lock()
            if entered {
                condition.unlock(); continuation.resume()
            } else {
                observers.append(continuation); condition.unlock()
            }
        }
    }
    func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
}

private actor SnapshotSignal {
    var completed = false
    func finish() { completed = true }
}

struct KeychainReadIsolationTests {
    @Test(arguments: ["none", "stop", "sleep"])
    func pendingAuthorizationDoesNotBlockEngineSnapshot(interruption: String) async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "keychain-isolation-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let keys = WaitingKeyStore()
        defer { keys.release() }
        let subject = Engine(
            dependencies: .init(
                adapters: [DeepSeekAdapter()],
                environment: DiscoveryEnvironment(
                    home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                    keychain: EmptyKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in BalanceHTTPFixture() }, store: SnapshotStore(url: url), ownedSecrets: keys))
        try await subject.start()
        let id = try await subject.addManualAccount(provider: .deepseek, key: Secret("synthetic-isolation"))
        let connection = Task { try await subject.reconnectManualAccount(id) }
        await keys.waitUntilReading()
        let signal = SnapshotSignal()
        let snapshot = Task {
            _ = await subject.snapshot(); await signal.finish()
        }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while clock.now < deadline, await !signal.completed { await Task.yield() }
        #expect(await signal.completed)
        if interruption == "stop" { await subject.stop() }
        if interruption == "sleep" { await subject.suspendForSleep() }
        keys.release()
        await snapshot.value
        if interruption != "none" {
            await #expect(throws: CancellationError.self) { try await connection.value }
            #expect(await subject.operations.isEmpty)
            await subject.stop()
        } else {
            try await connection.value
            await subject.stop()
        }
    }
}
