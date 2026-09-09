import Foundation
import Testing

@testable import WaterlineKit

struct NativeProviderScopeTests {
    @Test func productionRegistryContainsOnlyTheFiveNativeProviders() {
        #expect(Registry.activeProviders == [.codex, .claudeCode, .cursor, .grok, .antigravity])
        #expect(Registry.adapters.allSatisfy { !type(of: $0).descriptor.supportsManualKey })
    }

    @Test func deferredRecordsRemainStoredWithoutFetchingOrTouchingTheirKeys() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "native-scope-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deferred = Account(id: AccountID(rawValue: "saved-api"), provider: .deepseek, credential: .manual)
        let retired = Account(id: AccountID(rawValue: "removed-api"), provider: .deepseek, credential: .manual)
        let cached = AccountEntry(
            account: deferred,
            state: .fresh(
                reading: Reading(
                    usage: .balance(balance: Balance(amount: 20, currency: "USD", gift: nil)), fetchedAt: now)))
        var config = Configuration()
        config.accounts = [ManagedAccount(account: deferred, preferences: AccountPreferences(label: "Preserved"))]
        config.removed = [retired]
        config.preferences.accountOrder = [deferred.id]
        try ConfigurationStore(url: directory.appending(path: "configuration.json")).save(config)
        let store = SnapshotStore(url: directory.appending(path: "snapshot.json"))
        try store.save(Snapshot(generatedAt: now, accounts: [cached]))
        let engine = Engine(
            dependencies: .init(
                adapters: [NativeScopeAdapter()],
                environment: DiscoveryEnvironment(
                    home: directory, processEnvironment: [:], fileSystem: EmptyFiles(),
                    keychain: EmptyKeychain(), allowsUserInteraction: false),
                makeHTTPClient: { _ in UnusedHTTP() }, store: store, ownedSecrets: NoDeferredSecretAccess(),
                now: { now }))
        try await engine.start()
        try await engine.refreshAll()
        #expect(await engine.isEnabled(deferred.id) == false)
        let raw = await engine.snapshot()
        let visible = raw.includingProviders(Registry.activeProviders)
        #expect(raw.accounts.contains { $0.account == deferred })
        #expect(visible.accounts.map(\.account.provider) == [.codex])
        let nativeID = try #require(visible.accounts.first?.account.id)
        let beforeOrder = raw.preferences.accountOrder
        try await engine.setAccountOrder([nativeID], visibleProviders: Registry.activeProviders)
        let afterOrder = await engine.snapshot().preferences.accountOrder
        #expect(afterOrder?.contains(deferred.id) == true)
        #expect(afterOrder == beforeOrder)
        #expect(raw.accounts.first { $0.account.id == deferred.id }?.state.reading == cached.state.reading)
        #expect(try store.load()?.accounts.contains { $0.account == deferred } == true)
        await #expect(throws: ManualKeyError.unsupportedProvider) {
            try await engine.replaceManualKey(deferred.id, key: Secret("synthetic-unused"))
        }
        await engine.stop()
    }
}

private struct NativeScopeAdapter: ProviderAdapter {
    static let descriptor = ProviderDescriptor(
        provider: .codex, kind: .window, docStatus: .community,
        allowedHosts: [], consoleURL: URL(string: "https://synthetic.example")!)
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "native-account"), provider: .codex,
                    credential: .file(path: "/synthetic/native")), secret: Secret("synthetic"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        .windows(windows: [UsageWindow(label: "5h", usedFraction: 0.2, resetsAt: nil)], plan: nil)
    }
}

private struct NoDeferredSecretAccess: OwnedSecretStoring {
    func read(_ id: AccountID, interactive: Bool) throws -> Secret {
        Issue.record("Deferred key must not be read"); throw FetchError.credentialMissing
    }
    func save(_ secret: Secret, for id: AccountID) throws {
        Issue.record("Deferred key must not be rewritten"); throw FetchError.keychainLocked
    }
    func delete(_ id: AccountID) throws {
        Issue.record("Deferred key must not be deleted"); throw FetchError.keychainLocked
    }
}
