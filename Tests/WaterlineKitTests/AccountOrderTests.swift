import Foundation
import Testing

@testable import WaterlineKit

struct AccountOrderTests {
    @Test func groupsKeepShortWindowsLeftWithoutMixingModels() {
        func window(_ id: String, _ group: String, _ duration: Double) -> UsageWindow {
            UsageWindow(label: id, usedFraction: 0, resetsAt: nil, group: group, id: id, durationSeconds: duration)
        }
        let usage = Usage.windows(
            windows: [
                window("gemini-week", "gemini", 604800), window("gemini-5h", "gemini", 18000),
                window("one", "single", 86400),
                window("claude-week", "claude", 604800), window("claude-5h", "claude", 18000),
            ], plan: nil)
        let groups = Dashboard.detailWindowGroups(usage)
        #expect(groups.map { $0.map(\.id) } == [["gemini-5h", "gemini-week"], ["one"], ["claude-5h", "claude-week"]])
    }

    @Test func manualOrderSurvivesRestartAndAppendsNewAccounts() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "order-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = OrderSource()
        let dependencies = Engine.Dependencies(
            adapters: [OrderAdapter(source: source)],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                fileSystem: EmptyFiles(), keychain: EmptyKeychain(), allowsUserInteraction: false),
            makeHTTPClient: { _ in UnusedHTTP() },
            store: SnapshotStore(url: directory.appending(path: "snapshot.json")),
            ownedSecrets: FakeOwnedSecrets())
        let engine = Engine(dependencies: dependencies)
        try await engine.start()
        let ids = await engine.snapshot().accounts.map(\.account.id)
        let order = Array(ids.reversed())
        try await engine.setAccountOrder(order)
        await #expect(throws: SettingsError.invalidAccountOrder) { try await engine.setAccountOrder([ids[0]]) }
        await #expect(throws: SettingsError.invalidAccountOrder) { try await engine.setAccountOrder([ids[0], ids[0]]) }
        await engine.stop()
        await source.addAccount()
        let restored = Engine(dependencies: dependencies)
        try await restored.start()
        let snapshot = await restored.snapshot()
        #expect(snapshot.preferences.accountOrder?.prefix(order.count).map { $0 } == order)
        #expect(snapshot.preferences.accountOrder?.count == 3)
        #expect(Dashboard.overviewAccounts(snapshot).map(\.account.id) == snapshot.preferences.accountOrder)
        try await restored.removeAccount(order[0])
        #expect(await restored.snapshot().preferences.accountOrder?.contains(order[0]) == false)
        await restored.stop()
    }

    @Test func dailySelectionDoesNotOverrideManualPosition() {
        let a = AccountEntry(
            account: Account(id: AccountID(rawValue: "a"), provider: .codex, credential: .manual), state: .pending)
        let b = AccountEntry(
            account: Account(id: AccountID(rawValue: "b"), provider: .claudeCode, credential: .manual), state: .pending)
        let snapshot = Snapshot(
            generatedAt: Date(), accounts: [a, b],
            preferences: UserPreferences(notchAccountIDs: [a.account.id], accountOrder: [b.account.id, a.account.id]))
        #expect(
            Dashboard.overviewAccounts(snapshot, frozenIDs: [a.account.id, b.account.id]).map(\.account.id) == [
                b.account.id, a.account.id,
            ])
        #expect(Dashboard.notchAccounts(snapshot).map(\.account.id) == [a.account.id])
    }
}
private actor OrderSource {
    var ids = ["first", "second"]
    func addAccount() { ids.append("third") }
    func discoveries() -> [Discovered] {
        ids.map {
            Discovered(
                account: Account(
                    id: AccountID(rawValue: $0), provider: .codex,
                    credential: .file(path: "/synthetic/\($0)")), secret: Secret("synthetic"))
        }
    }
}
private struct OrderAdapter: ProviderAdapter {
    let source: OrderSource
    static let descriptor = ProviderDescriptor(
        provider: .codex, kind: .window, docStatus: .community,
        allowedHosts: [], consoleURL: URL(string: "https://synthetic.example")!)
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered] {
        await source.discoveries()
    }
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        .windows(windows: [UsageWindow(label: "5h", usedFraction: 0.2, resetsAt: nil)], plan: nil)
    }
}
