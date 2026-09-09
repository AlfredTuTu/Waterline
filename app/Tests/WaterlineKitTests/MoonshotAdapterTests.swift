import Foundation
import Testing

@testable import WaterlineKit

struct MoonshotAdapterTests {
    @Test func regionalContractsDefineCurrencyWithoutAddingCashAgain() throws {
        let data = Data(
            #"{"code":0,"status":true,"data":{"available_balance":12.34567,"voucher_balance":12.34567,"cash_balance":-5}}"#
                .utf8)
        let cn = try MoonshotAdapter.parse(data, region: "cn")
        let global = try MoonshotAdapter.parse(data, region: "global")
        #expect(cn.balances.first?.currency == "CNY")
        #expect(global.balances.first?.currency == "USD")
        #expect(cn.balances.first?.amount == Decimal(string: "12.34567"))
        #expect(cn.balances.first?.gift == Decimal(string: "12.34567"))
    }

    @Test func badVoucherKeepsValidAvailableAmount() throws {
        let result = try MoonshotAdapter.parse(
            Data(#"{"code":0,"status":true,"data":{"available_balance":0,"voucher_balance":"bad"}}"#.utf8), region: "cn"
        )
        #expect(result.balances.first?.amount == 0)
        #expect(result.componentFailures.first?.id == "balance.CNY.gift")
    }

    @Test func missingRegionIsRejectedBeforeHTTP() async {
        await #expect(throws: ManualKeyError.self) {
            try await MoonshotAdapter().fetch(
                Account(provider: .moonshot, credential: .manual), secret: Secret("synthetic"), http: UnusedHTTP())
        }
    }

    @Test func cliRequiresRegionAndPersistsTheSelectedScope() async throws {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "waterline-moonshot-cli-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let deps = Engine.Dependencies(
            adapters: [MoonshotAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false),
            makeHTTPClient: { _ in RegionalHTTPFixture() }, store: SnapshotStore(url: url), ownedSecrets: store)
        let missing = await WaterlineCLI.run(
            ["account", "add", "moonshot", "--stdin"], dependencies: deps, inputSecret: Secret("synthetic-cn"))
        #expect(missing.exitCode == 64)
        #expect(store.writeCount == 0)
        let result = await WaterlineCLI.run(
            ["account", "add", "moonshot", "--stdin", "--region", "cn", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-cn"))
        #expect(result.exitCode == 0)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.accounts.first?.account.region == "cn")
        #expect(MoonshotAdapter.descriptor.consoleURL(for: "cn").host == "platform.kimi.com")
        #expect(MoonshotAdapter.descriptor.consoleURL(for: "global").host == "platform.kimi.ai")
    }

    @Test func bothRegionsRestoreAndSendOnlyToTheirSelectedHost() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-moonshot-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let deps = Engine.Dependencies(
            adapters: [MoonshotAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false),
            makeHTTPClient: { _ in RegionalHTTPFixture() }, store: SnapshotStore(url: url), ownedSecrets: store)
        let engine = Engine(dependencies: deps)
        await #expect(throws: ManualKeyError.self) {
            try await engine.addManualAccount(provider: .moonshot, key: Secret("synthetic-cn"))
        }
        #expect(store.writeCount == 0)
        let cn = try await engine.addManualAccount(provider: .moonshot, key: Secret("synthetic-cn"), region: "cn")
        let global = try await engine.addManualAccount(
            provider: .moonshot, key: Secret("synthetic-global"), region: "global")
        await engine.stop()
        let restored = Engine(dependencies: deps)
        try await restored.start()
        try await restored.refreshAll()
        let entries = await restored.snapshot().accounts
        #expect(entries.count == 2)
        #expect(entries.first { $0.account.id == cn }?.state.reading?.usage.balances.first?.currency == "CNY")
        #expect(entries.first { $0.account.id == global }?.state.reading?.usage.balances.first?.currency == "USD")
        await restored.stop()
    }
}

private struct RegionalHTTPFixture: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let expected = request.headers["Authorization"] == "Bearer synthetic-cn" ? "api.moonshot.cn" : "api.moonshot.ai"
        #expect(request.url.host == expected)
        #expect(request.url.path == "/v1/users/me/balance")
        return HTTPResponse(
            status: 200, headers: [:],
            body: Data(
                #"{"code":0,"status":true,"data":{"available_balance":10,"voucher_balance":0,"cash_balance":10}}"#.utf8)
        )
    }
}
