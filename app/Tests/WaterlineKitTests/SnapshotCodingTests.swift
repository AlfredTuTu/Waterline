import Foundation
import Testing

@testable import WaterlineKit

@Suite struct SnapshotCodingTests {
    @Test func `snapshot round-trips through the store encoder`() throws {
        let account = Account(
            id: AccountID(rawValue: "synthetic-stable-account"),
            provider: .deepseek,
            credential: .env(name: "DEEPSEEK_API_KEY", sourceFile: "~/.zshrc")
        )
        let reading = Reading(
            usage: .balance(balance: Balance(amount: 465.46, currency: "CNY", gift: nil)),
            fetchedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let snapshot = Snapshot(
            generatedAt: Date(timeIntervalSince1970: 1_800_000_100),
            accounts: [
                AccountEntry(account: account, state: .fresh(reading: reading)),
                AccountEntry(account: account, state: .stale(reading: reading, error: .rateLimited(retryAfter: 30))),
                AccountEntry(account: account, state: .unavailable(error: .keychainLocked)),
                AccountEntry(account: account, state: .pending),
            ]
        )
        let data = try SnapshotStore.encoder.encode(snapshot)
        #expect(try SnapshotStore.decoder.decode(Snapshot.self, from: data) == snapshot)
        #expect(account.id.rawValue == "synthetic-stable-account")
        #expect(Secret("sk-test").fingerprint.count == 8)
    }

    @Test func futureSchemaIsNeverOverwritten() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "waterline-schema-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "snapshot.json")
        let original = Data(#"{"schemaVersion":999}"#.utf8)
        try original.write(to: url)
        let store = SnapshotStore(url: url)
        #expect(throws: SnapshotStoreError.unsupportedVersion(999)) { try store.load() }
        #expect(throws: SnapshotStoreError.unsupportedVersion(999)) {
            try store.save(Snapshot(generatedAt: Date(), accounts: []))
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func legacySnapshotIsBackedUpBeforeUpgrade() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "waterline-legacy-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "snapshot.json")
        let original = Data(#"{"generatedAt":"2026-09-06T00:00:00Z","accounts":[]}"#.utf8)
        try original.write(to: url)
        let store = SnapshotStore(url: url)
        #expect(try store.load()?.schemaVersion == 0)
        try store.save(Snapshot(generatedAt: Date(timeIntervalSince1970: 1_800_000_000), accounts: []))
        #expect(try store.load()?.schemaVersion == Snapshot.currentVersion)
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("snapshot-legacy-") }
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == original)
    }

    @Test func `store writes and reads the same snapshot`() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline \(UUID().uuidString)/snapshot.json")
        let store = SnapshotStore(url: url)
        #expect(try store.load() == nil)
        let snapshot = Snapshot(generatedAt: Date(timeIntervalSince1970: 1_800_000_000), accounts: [])
        try store.save(snapshot)
        #expect(try store.load() == snapshot)
    }
}
