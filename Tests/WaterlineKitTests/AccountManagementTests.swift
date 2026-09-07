import Foundation
import Testing

@testable import WaterlineKit

struct AccountManagementTests {
    private func path() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "waterline-account-tests-\(UUID())/snapshot.json")
    }

    @Test func notchSelectionSurvivesRestartAndRemoval() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        try await subject.setNotchAccounts([id])
        await subject.stop()
        let restored = engine([GoodAdapter(gate: nil)], at: url)
        try await restored.start()
        #expect(await restored.snapshot().preferences.notchAccountIDs == [id])
        #expect(Dashboard.notchAccounts(await restored.snapshot()).map(\.account.id) == [id])
        try await restored.removeAccount(id)
        #expect(await restored.snapshot().preferences.notchAccountIDs == [])
        #expect(Dashboard.notchAccounts(await restored.snapshot()).isEmpty)
        await restored.stop()
    }

    @Test func deselectingLastNotchAccountStaysEmptyAfterRestart() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        try await subject.toggleNotchAccount(id)
        #expect(await subject.snapshot().preferences.notchAccountIDs == [])
        #expect(Dashboard.notchAccounts(await subject.snapshot()).isEmpty)
        await subject.stop()
        let restored = engine([GoodAdapter(gate: nil)], at: url)
        try await restored.start()
        #expect(Dashboard.notchAccounts(await restored.snapshot()).isEmpty)
        try await restored.setNotchAccounts(nil)
        #expect(Dashboard.notchAccounts(await restored.snapshot()).map(\.account.id) == [id])
        await restored.stop()
    }

    @Test func notchSelectionRejectsDuplicatesAndOverflow() throws {
        let id = AccountID()
        #expect(throws: SettingsError.invalidNotchSelection) {
            try UserPreferences(notchAccountIDs: [id, id]).validate()
        }
        #expect(throws: SettingsError.invalidNotchSelection) {
            try UserPreferences(notchAccountIDs: [id, AccountID(), AccountID()]).validate()
        }
        try UserPreferences(notchAccountIDs: []).validate()
    }

    @Test func disableInvalidatesInFlightAndSurvivesRestart() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let gate = CompletionGate()
        let subject = engine([GoodAdapter(gate: gate)], at: url)
        try await subject.start()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        let pending = Task { try await subject.refreshAll() }
        await gate.waitForFirst()
        try await subject.updateAccount(
            id, preferences: AccountPreferences(enabled: false, pinned: true, label: "Work"))
        await gate.completeOldRequest()
        try await pending.value
        #expect(amount(await subject.snapshot()) == nil)
        await subject.stop()
        let restored = engine([GoodAdapter(gate: nil)], at: url)
        try await restored.start()
        try await restored.refreshAll()
        let row = try #require(await restored.snapshot().accounts.first)
        #expect(!row.preferences.enabled)
        #expect(row.preferences.pinned)
        #expect(row.preferences.label == "Work")
        #expect(row.state.reading == nil)
        try await restored.updateAccount(
            id, preferences: AccountPreferences(enabled: true, pinned: true, label: "Work"))
        try await restored.refreshAll()
        #expect(amount(await restored.snapshot()) == 20)
        await restored.stop()
    }

    @Test func removalSurvivesRediscoveryUntilExplicitConnect() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        try await subject.removeAccount(id)
        await subject.stop()
        let restored = engine([GoodAdapter(gate: nil)], at: url)
        try await restored.start()
        #expect(await restored.snapshot().accounts.isEmpty)
        try await restored.connect(provider: .deepseek)
        #expect(await restored.snapshot().accounts.count == 1)
        #expect(amount(await restored.snapshot()) == 20)
        await restored.stop()
    }

    @Test func configurationFailureDoesNotApplyAccountChange() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        let id = try #require(await subject.snapshot().accounts.first?.account.id)
        let config = url.deletingLastPathComponent().appending(path: "configuration.json")
        try FileManager.default.removeItem(at: config)
        try FileManager.default.createDirectory(at: config, withIntermediateDirectories: false)
        do {
            try await subject.updateAccount(id, preferences: AccountPreferences(enabled: false))
            Issue.record("Configuration write must fail")
        } catch {}
        #expect(await subject.snapshot().accounts.first?.preferences.enabled == true)
        #expect(await subject.snapshot().storageFailed)
        await subject.stop()
    }

    @Test func credentialRotationPreservesIdentityAndPreferences() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = engine([IdentityAdapter(credential: "synthetic-old")], at: url)
        try await first.start()
        try await first.refreshAll()
        let id = try #require(await first.snapshot().accounts.first?.account.id)
        try await first.setAccountPinned(id, pinned: true)
        try await first.renameAccount(id, label: "Research")
        await first.stop()
        let second = engine([IdentityAdapter(credential: "synthetic-rotated")], at: url)
        try await second.start()
        let row = try #require(await second.snapshot().accounts.first)
        #expect(row.account.id == id)
        #expect(row.preferences.pinned)
        #expect(row.preferences.label == "Research")
        #expect(row.state.reading != nil)
        try await second.removeAccount(id)
        try await second.connect(provider: .deepseek)
        #expect(await second.snapshot().accounts.first?.account.id == id)
        await second.stop()
    }

    @Test func oldCachedReadingExpiresWithoutChangingObservationTime() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = engine([GoodAdapter(gate: nil)], at: url)
        try await first.start()
        try await first.refreshAll()
        let original = try #require(await first.snapshot().accounts.first?.state.reading)
        await first.stop()
        let second = engine([GoodAdapter(gate: nil)], at: url, now: original.observedAt.addingTimeInterval(601))
        try await second.start()
        let state = try #require(await second.snapshot().accounts.first?.state)
        #expect(state == .expired(reading: original))
        try await second.refreshAll()
        #expect(
            await second.snapshot().accounts.first?.state.reading?.observedAt
                == original.observedAt.addingTimeInterval(601))
        await second.stop()
    }

    @Test func connectingOneProviderDoesNotRefreshAnotherProvider() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let counter = FetchCounter()
        let subject = engine([GoodAdapter(gate: nil), OtherProviderAdapter(counter: counter)], at: url)
        try await subject.start()
        try await subject.connect(provider: .deepseek)
        #expect(await counter.count == 0)
        #expect(amount(await subject.snapshot()) == 20)
        await subject.stop()
    }

    @Test func temporarySourceLockPreservesKnownIdentityForRecovery() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = engine([IdentityAdapter(credential: "synthetic-first")], at: url)
        try await first.start()
        let original = try #require(await first.snapshot().accounts.first?.account)
        await first.stop()
        let locked = engine([LockedIdentityAdapter()], at: url)
        try await locked.start()
        #expect(await locked.snapshot().accounts.first?.account.identity == original.identity)
        await locked.stop()
        let recovered = engine([IdentityAdapter(credential: "synthetic-new")], at: url)
        try await recovered.start()
        #expect(await recovered.snapshot().accounts.count == 1)
        #expect(await recovered.snapshot().accounts.first?.account.id == original.id)
        await recovered.stop()
    }

    @Test func provisionalAccountBecomesIdentifiedWithoutCreatingAnotherRow() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let locked = engine([LockedIdentityAdapter()], at: url)
        try await locked.start()
        let id = try #require(await locked.snapshot().accounts.first?.account.id)
        try await locked.renameAccount(id, label: "My account")
        try await locked.setAccountPinned(id, pinned: true)
        await locked.stop()
        let connected = engine([IdentityAdapter(credential: "synthetic-connected")], at: url)
        try await connected.start()
        let rows = await connected.snapshot().accounts
        #expect(rows.count == 1)
        let row = try #require(rows.first)
        #expect(row.account.id == id)
        #expect(row.account.identity != nil)
        #expect(row.preferences.label == "My account")
        #expect(row.preferences.pinned)
        await connected.stop()
    }

    @Test func obsoleteEmptyPlaceholderIsReconciledWithKnownSameSource() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let reference = CredentialRef.file(path: "/synthetic/auth")
        let placeholder = Account(provider: .deepseek, credential: reference)
        let known = Account(
            provider: .deepseek, credential: reference,
            identity: BillingIdentity(region: "synthetic", account: "billing-account"))
        var config = Configuration()
        config.accounts = [placeholder, known].map { ManagedAccount(account: $0, preferences: AccountPreferences()) }
        let store = ConfigurationStore(url: url.deletingLastPathComponent().appending(path: "configuration.json"))
        try store.save(config)
        let subject = engine([LockedIdentityAdapter()], at: url)
        try await subject.start()
        let rows = await subject.snapshot().accounts
        #expect(rows.count == 1)
        #expect(rows.first?.account.id == known.id)
        #expect(rows.first?.state == .unavailable(error: .keychainLocked))
        #expect(try store.load()?.removed.isEmpty == true)
        await subject.stop()
        let restored = engine([IdentityAdapter(credential: "synthetic-return")], at: url)
        try await restored.start()
        #expect(await restored.snapshot().accounts.count == 1)
        #expect(await restored.snapshot().accounts.first?.account.id == known.id)
        await restored.stop()
    }

    @Test func reconciliationPreservesCustomSettingsHistoryAndDistinctIdentities() async throws {
        for protection in ["label", "history", "identity", "unreadableHistory"] {
            let url = path()
            defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            let reference = CredentialRef.file(path: "/synthetic/auth")
            let candidate = Account(
                provider: .deepseek, credential: reference,
                identity: protection == "identity"
                    ? BillingIdentity(region: "synthetic", account: "another-account") : nil)
            let known = Account(
                provider: .deepseek, credential: reference,
                identity: BillingIdentity(region: "synthetic", account: "billing-account"))
            var config = Configuration()
            config.accounts = [
                ManagedAccount(
                    account: candidate, preferences: AccountPreferences(label: protection == "label" ? "Keep" : nil)),
                ManagedAccount(account: known, preferences: AccountPreferences()),
            ]
            try ConfigurationStore(url: url.deletingLastPathComponent().appending(path: "configuration.json")).save(
                config)
            let historyURL = url.deletingLastPathComponent().appending(path: "history.jsonl")
            if protection == "history" {
                try HistoryStore(url: historyURL).append([
                    BalanceObservation(
                        accountID: candidate.id, currency: "USD", amount: 1,
                        observedAt: Date(timeIntervalSince1970: 1_800_000_000))
                ])
            } else if protection == "unreadableHistory" {
                try Data("incompatible record\n".utf8).write(to: historyURL)
            }
            let subject = engine([LockedIdentityAdapter()], at: url)
            try await subject.start()
            let rows = await subject.snapshot().accounts
            if protection == "identity" {
                #expect(rows.count == 2)
                #expect(rows.contains { $0.account == candidate })
                #expect(rows.contains { $0.account == known })
                #expect(rows.allSatisfy { $0.state == .unavailable(error: .keychainLocked) })
                #expect(
                    await subject.snapshot().sourceFailures == [
                        SourceFailure(provider: .deepseek, error: .keychainLocked)
                    ])
            } else {
                #expect(Set(rows.map(\.account.id)) == Set([candidate.id, known.id]))
            }
            await subject.stop()
        }
    }

    @Test func failedDiscoveryNeverMatchesAnotherKnownIdentityOrAmbiguousSource() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([], at: url)
        let reference = CredentialRef.file(path: "/synthetic/auth")
        let first = Account(
            provider: .deepseek, credential: reference,
            identity: BillingIdentity(region: "synthetic", account: "first"))
        let second = Account(
            provider: .deepseek, credential: reference,
            identity: BillingIdentity(region: "synthetic", account: "second"))
        let managed = [first, second].map {
            ManagedAccount(account: $0, preferences: AccountPreferences(label: $0.identity?.account))
        }
        let different = Discovered(
            account: Account(
                provider: .deepseek, credential: reference,
                identity: BillingIdentity(region: "synthetic", account: "third")),
            secret: nil, connectionError: .keychainLocked)
        #expect(await subject.discoveryMatch(different, in: managed) == nil)
        let unidentified = Discovered(
            account: Account(provider: .deepseek, credential: reference),
            secret: nil, connectionError: .keychainLocked)
        #expect(await subject.discoveryMatch(unidentified, in: managed) == nil)
        #expect(await subject.discoveryMatch(unidentified, in: [managed[0]]) == 0)
        let exact = Discovered(account: second, secret: nil, connectionError: .keychainLocked)
        #expect(await subject.discoveryMatch(exact, in: managed) == 1)
    }

    @Test func disabledSourceDoesNotDiscoverAfterRestart() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        var preferences = UserPreferences()
        preferences.disabledProviders = [.cursor]
        try await subject.updatePreferences(preferences)
        await subject.stop()
        let restored = engine([FailingDiscovery(), GoodAdapter(gate: nil)], at: url)
        try await restored.start()
        #expect(await restored.snapshot().sourceFailures.isEmpty)
        await restored.stop()
    }

    @Test func invalidPreferencesNeverReplaceSavedSettings() async throws {
        let url = path()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let subject = engine([GoodAdapter(gate: nil)], at: url)
        try await subject.start()
        let config = url.deletingLastPathComponent().appending(path: "configuration.json")
        let before = try Data(contentsOf: config)
        var preferences = UserPreferences()
        preferences.refreshInterval = 0
        await #expect(throws: SettingsError.invalidInterval) { try await subject.updatePreferences(preferences) }
        #expect(try Data(contentsOf: config) == before)
        await subject.stop()
    }
}

private struct IdentityAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor { GoodAdapter.descriptor }
    let credential: String
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    provider: .deepseek, credential: .file(path: "/synthetic/auth"),
                    identity: BillingIdentity(region: "synthetic", account: "billing-account")),
                secret: Secret(credential))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage { reading(20) }
}

private actor FetchCounter {
    var count = 0
    func increment() { count += 1 }
}

private struct OtherProviderAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor { FailingDiscovery.descriptor }
    let counter: FetchCounter
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(
                    id: AccountID(rawValue: "synthetic-other"), provider: .cursor,
                    credential: .file(path: "/synthetic/other")), secret: Secret("synthetic-other"))
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        await counter.increment()
        return reading(30)
    }
}

private struct LockedIdentityAdapter: ProviderAdapter {
    static var descriptor: ProviderDescriptor { GoodAdapter.descriptor }
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        [
            Discovered(
                account: Account(provider: .deepseek, credential: .file(path: "/synthetic/auth")), secret: nil,
                connectionError: .keychainLocked)
        ]
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        fatalError("Locked source cannot fetch")
    }
}
