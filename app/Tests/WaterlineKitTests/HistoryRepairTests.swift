import Foundation
import Testing

@testable import WaterlineKit

struct HistoryRepairTests {
    private func location() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "waterline-repair-\(UUID())/history.jsonl")
    }
    private var record: BalanceObservation {
        BalanceObservation(
            accountID: AccountID(rawValue: "synthetic"), currency: "USD", amount: 20,
            observedAt: Date(timeIntervalSince1970: 1_800_000_000))
    }

    @Test func truncatedFragmentIsBackedUpBeforeRestoringCompleteRecords() throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = HistoryStore(url: url)
        try store.append([record])
        var damaged = try Data(contentsOf: url)
        damaged.append(Data(#"{"accountID":"#.utf8))
        try damaged.write(to: url)
        #expect(throws: HistoryError.self) { try store.load(since: .distantPast) }
        #expect(try store.recoverIncompleteTail() != nil)
        #expect(try store.load(since: .distantPast).observations == [record])
        let backups = try FileManager.default.contentsOfDirectory(
            at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("history-incomplete-") }
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == damaged)
    }

    @Test func completeFinalRecordWithoutNewlineIsNotLost() throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = HistoryStore(url: url)
        try store.append([record])
        var data = try Data(contentsOf: url); data.removeLast(); try data.write(to: url)
        _ = try store.recoverIncompleteTail()
        #expect(try store.load(since: .distantPast).observations == [record])
    }

    @Test func malformedMiddleAndUnknownCompleteTailAreNeverDiscarded() throws {
        for suffix in ["invalid\n", #"{"futureSchema":1}"#] {
            let url = location()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let store = HistoryStore(url: url)
            try store.append([record])
            var data = try Data(contentsOf: url); data.append(Data(suffix.utf8)); try data.write(to: url)
            do { _ = try store.recoverIncompleteTail(); Issue.record("Incompatible complete records must fail") } catch
            {}
            #expect(try Data(contentsOf: url) == data)
        }
    }

    @Test func engineRetryRestoresHistoryWithoutAProviderRequest() async throws {
        let url = location()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let snapshotURL = url.deletingLastPathComponent().appending(path: "snapshot.json")
        let first = engine([GoodAdapter(gate: nil)], at: snapshotURL)
        try await first.start(); try await first.refreshAll()
        let before = await first.snapshot()
        await first.stop()
        var data = try Data(contentsOf: url); data.append(Data("broken".utf8)); try data.write(to: url)
        let restored = engine([GoodAdapter(gate: nil)], at: snapshotURL)
        try await restored.start()
        #expect(await restored.snapshot().historyFailed)
        try await restored.retryHistoryPersistence()
        let after = await restored.snapshot()
        #expect(!after.historyFailed)
        #expect(after.historyRepairNotice != nil)
        #expect(after.lastAttemptAt == before.lastAttemptAt)
        let id = try #require(after.accounts.first?.account.id)
        #expect(await restored.balanceHistory(for: id).count == 1)
        await restored.stop()
    }
}
