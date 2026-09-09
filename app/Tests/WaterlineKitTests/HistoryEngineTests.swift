import Foundation
import Testing

@testable import WaterlineKit

private final class HistoryClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = Date(timeIntervalSince1970: 1_800_000_000)
    var now: Date { lock.withLock { value } }
    func advance(_ interval: TimeInterval) { lock.withLock { value = value.addingTimeInterval(interval) } }
}

struct HistoryEngineTests {
    private func dependencies(_ url: URL, clock: HistoryClock) -> Engine.Dependencies {
        .init(
            adapters: [GoodAdapter(gate: nil)],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in UnusedHTTP() },
            store: SnapshotStore(url: url), now: { clock.now })
    }

    @Test func retainedHistoryPeriodsSurviveRelaunchAndRespectBounds() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-periods-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = HistoryClock()
        let deps = dependencies(url, clock: clock)
        let engine = Engine(dependencies: deps)
        try await engine.start()
        try await engine.refreshAll()
        let id = try #require(await engine.snapshot().accounts.first?.account.id)
        await engine.stop()
        let records = [0, 7, 8, 30, 31, 90, 91, -1].map { days in
            BalanceObservation(
                accountID: id, currency: "USD", amount: Decimal(days + 100),
                observedAt: clock.now.addingTimeInterval(-Double(days) * 86400))
        }
        try HistoryStore(url: url.deletingLastPathComponent().appending(path: "history.jsonl")).compact(records)
        let restored = Engine(dependencies: deps)
        try await restored.start()
        #expect(await restored.balanceHistory(for: id).count == 2)
        #expect(await restored.balanceHistory(for: id, period: .month).count == 4)
        #expect(await restored.balanceHistory(for: id, period: .quarter).count == 6)
        #expect(await restored.balanceHistory(for: AccountID(), period: .quarter).isEmpty)
        await restored.stop()
    }

    @Test func incompatibleJournalRetryReportsDataFailureWithoutOverwritingOriginal() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-history-incompatible-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = HistoryClock()
        let deps = dependencies(url, clock: clock)
        let engine = Engine(dependencies: deps)
        try await engine.start()
        try await engine.refreshAll()
        await engine.stop()
        let journal = url.deletingLastPathComponent().appending(path: "history.jsonl")
        var invalid = try Data(contentsOf: journal)
        invalid.append(Data("invalid complete record\n".utf8))
        try invalid.write(to: journal)
        let restored = Engine(dependencies: deps)
        try await restored.start()
        do {
            try await restored.retryHistoryPersistence()
            Issue.record("Incompatible complete records must remain an error")
        } catch HistoryError.malformedRecord {
        }
        #expect(try Data(contentsOf: journal) == invalid)
        #expect(await restored.snapshot().historyFailed)
        #expect(amount(await restored.snapshot()) == 20)
        await restored.stop()
    }

    @Test func unchangedBalanceRecordsDistinctTimesButPublicationDoesNotDuplicate() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-history-engine-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = HistoryClock()
        let deps = dependencies(url, clock: clock)
        let subject = Engine(dependencies: deps)
        try await subject.start()
        try await subject.refreshAll()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        try await subject.setAccountPinned(id, pinned: true)
        try await subject.refreshAll()
        #expect(await subject.balanceHistory(for: id).count == 1)
        clock.advance(86400)
        try await subject.refreshAll()
        #expect(await subject.balanceHistory(for: id).count == 2)
        await subject.stop()
        let restored = Engine(dependencies: deps)
        try await restored.start()
        #expect(await restored.balanceHistory(for: id).count == 2)
        await restored.stop()
    }

    @Test func historyFailureKeepsCurrentReadingAndReplaysPendingRecords() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-history-engine-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = HistoryClock()
        let subject = Engine(dependencies: dependencies(url, clock: clock))
        try await subject.start()
        let journal = url.deletingLastPathComponent().appending(path: "history.jsonl")
        try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: false)
        try await subject.refreshAll()
        #expect(amount(await subject.snapshot()) == 20)
        #expect(await subject.snapshot().historyFailed)
        try FileManager.default.removeItem(at: journal)
        clock.advance(1)
        try await subject.refreshAll()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        #expect(!((await subject.snapshot()).historyFailed))
        #expect(await subject.balanceHistory(for: id).count == 2)
        await subject.stop()
    }

    @Test func storageRetryDoesNotNeedAnotherProviderRequest() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-history-retry-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = HistoryClock()
        let subject = Engine(dependencies: dependencies(url, clock: clock))
        try await subject.start()
        let journal = url.deletingLastPathComponent().appending(path: "history.jsonl")
        try FileManager.default.createDirectory(at: journal, withIntermediateDirectories: false)
        try await subject.refreshAll()
        let before = await subject.snapshot()
        let id = try #require(before.accounts.first?.account.id)
        await #expect(throws: HistoryError.self) { try await subject.retryHistoryPersistence() }
        try FileManager.default.removeItem(at: journal)
        clock.advance(600)
        try await subject.retryHistoryPersistence()
        let after = await subject.snapshot()
        #expect(!after.historyFailed)
        #expect(after.lastAttemptAt == before.lastAttemptAt)
        #expect(await subject.balanceHistory(for: id).count == 1)
        #expect(
            await subject.balanceHistory(for: id).first?.observedAt == before.accounts.first?.state.reading?.observedAt)
        await subject.stop()
    }

    @Test func recordsOlderThanNinetyDaysAreRemovedAtStartup() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-history-engine-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let clock = HistoryClock()
        let journal = HistoryStore(url: url.deletingLastPathComponent().appending(path: "history.jsonl"))
        try journal.append([
            BalanceObservation(
                accountID: AccountID(rawValue: "synthetic-deepseek"), currency: "USD", amount: 20,
                observedAt: clock.now.addingTimeInterval(-91 * 86400))
        ])
        let subject = Engine(dependencies: dependencies(url, clock: clock))
        try await subject.start()
        #expect(try Data(contentsOf: journal.url).isEmpty)
        await subject.stop()
    }
}
