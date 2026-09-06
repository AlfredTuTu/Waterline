import Foundation
import Testing

@testable import WaterlineKit

@Suite struct SnapshotCodingTests {
    @Test func `snapshot round-trips through the store encoder`() throws {
        let account = Account(
            id: AccountID(provider: .deepseek, secret: Secret("sk-test")),
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
        #expect(account.id.rawValue == "deepseek:\(Secret("sk-test").fingerprint)")
        #expect(Secret("sk-test").fingerprint.count == 8)
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
