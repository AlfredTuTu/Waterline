import Foundation
import Testing

@testable import WaterlineKit

struct XAIAdapterTests {
    @Test func invertedCentLedgerIsExplicitlyPostedCredit() throws {
        let usage = try XAIAdapter.parse(Data(#"{"total":{"val":"-12345"},"changes":[]}"#.utf8))
        #expect(usage.balances.first?.amount == Decimal(string: "123.45"))
        #expect(usage.balances.first?.currency == "USD")
        #expect(usage.balances.first?.basis == .postedLedger)
        let entry = AccountEntry(
            account: Account(provider: .xai, credential: .manual),
            state: .fresh(reading: Reading(usage: usage, fetchedAt: Date())))
        #expect(Dashboard.balanceHeadline([entry], preferences: UserPreferences()) == nil)
        #expect(Dashboard.health(entry, preferences: UserPreferences()) == .muted)
    }
    @Test func malformedTotalNeverBecomesZero() {
        #expect(throws: FetchError.self) { try XAIAdapter.parse(Data(#"{"changes":[]}"#.utf8)) }
        #expect(throws: FetchError.self) { try XAIAdapter.parse(Data(#"{"total":{"val":"12.3"}}"#.utf8)) }
    }
    @Test func postedLedgerIsNeverUsedForDepletionEstimate() {
        let id = AccountID(rawValue: "xai-team")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let history = [
            BalanceObservation(
                accountID: id, currency: "USD", amount: 100, observedAt: now.addingTimeInterval(-86400),
                basis: .postedLedger),
            BalanceObservation(accountID: id, currency: "USD", amount: 80, observedAt: now, basis: .postedLedger),
        ]
        #expect(BalanceHistory.estimate(history, accountID: id, currency: "USD", now: now, latestIsFresh: true) == nil)
    }
    @Test func scopedCLIFlowRequiresTeamBeforeSaving() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-xai-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = FakeOwnedSecrets()
        let deps = Engine.Dependencies(
            adapters: [XAIAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in XAIHTTPFixture() },
            store: SnapshotStore(url: url), ownedSecrets: store)
        let missing = await WaterlineCLI.run(
            ["account", "add", "xai", "--stdin"], dependencies: deps, inputSecret: Secret("synthetic-management"))
        #expect(missing.exitCode == 64)
        #expect(store.writeCount == 0)
        let result = await WaterlineCLI.run(
            ["account", "add", "xai", "--team", "team-a", "--stdin", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-management"))
        #expect(result.exitCode == 0)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.accounts.first?.account.teamID == "team-a")
        #expect(snapshot.accounts.first?.state.reading?.usage.balances.first?.basis == .postedLedger)
    }
    @Test func pathInjectionAndForbiddenAccessAreRejected() async {
        await #expect(throws: ManualKeyError.self) {
            try await XAIAdapter().fetch(
                Account(provider: .xai, credential: .manual, teamID: "../another?team"), secret: Secret("synthetic"),
                http: UnusedHTTP())
        }
        #expect(throws: FetchError.permissionDenied) {
            try HTTPResponse(status: 403, headers: [:], body: Data()).validateStatus()
        }
    }
}
private struct XAIHTTPFixture: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://management-api.x.ai/v1/billing/teams/team-a/prepaid/balance")
        #expect(request.method == "GET")
        #expect(request.headers["Authorization"] == "Bearer synthetic-management")
        return HTTPResponse(status: 200, headers: [:], body: Data(#"{"total":{"val":"-1000"}}"#.utf8))
    }
}
