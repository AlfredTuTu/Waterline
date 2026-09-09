import Foundation
import Testing

@testable import WaterlineKit

struct ZhipuAdapterTests {
    @Test func weeklyFiveHourAndMCPWindowsRemainDistinct() throws {
        let usage = try ZhipuAdapter.parse(
            Data(
                #"{"success":true,"code":200,"data":{"level":"pro","limits":[{"type":"TOKENS_LIMIT","unit":6,"number":1,"percentage":20},{"type":"CREDIT_LIMIT","unit":3,"number":5,"percentage":30,"nextResetTime":1800000000000},{"type":"TIME_LIMIT","unit":5,"number":1,"percentage":0}]}}"#
                    .utf8))
        #expect(usage.quotaWindows.map(\.label) == ["7d", "5h", "MCP"])
        #expect(Dashboard.overviewWindows(usage).count == 2)
        #expect(usage.quotaWindows[1].resetsAt == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(usage.quotaWindows[2].resetsAt == nil)
        #expect(usage.balances.isEmpty)
    }
    @Test func countsTakePrecedenceAndMalformedSiblingIsIsolated() throws {
        let usage = try ZhipuAdapter.parse(
            Data(
                #"{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":50,"usage":100,"currentValue":25},{"type":"CREDIT_LIMIT","unit":6,"number":1,"percentage":"broken"},{"type":"NEW_UNRELATED","unknown":true}]}}"#
                    .utf8))
        #expect(usage.quotaWindows.count == 1)
        #expect(usage.quotaWindows[0].usedFraction == 0.25)
        #expect(usage.componentFailures.count == 1)
    }
    @Test func malformedKnownWindowRetainsItsOwnEarlierValue() throws {
        let earlier = Date(timeIntervalSince1970: 1_800_000_000)
        let first = try ZhipuAdapter.parse(
            Data(
                #"{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":20}]}}"#
                    .utf8)
        ).accepting(at: earlier, previous: nil)
        let failed = try ZhipuAdapter.parse(
            Data(
                #"{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":"bad"}]}}"#
                    .utf8))
        let merged = failed.accepting(
            at: earlier.addingTimeInterval(300), previous: Reading(usage: first, fetchedAt: earlier))
        #expect(merged.quotaWindows.first?.usedFraction == 0.2)
        #expect(merged.quotaWindows.first?.observedAt == earlier)
        #expect(merged.quotaWindows.first?.error != nil)
    }

    @Test func regionIsRequiredBeforeAnyRequest() async {
        await #expect(throws: ManualKeyError.self) {
            try await ZhipuAdapter().fetch(
                Account(provider: .zhipu, credential: .manual), secret: Secret("synthetic"), http: UnusedHTTP())
        }
    }
    @Test func cliManualRegionalFlowReturnsCodingQuota() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-zhipu-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let deps = Engine.Dependencies(
            adapters: [ZhipuAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false),
            makeHTTPClient: { _ in ZhipuHTTPFixture(host: "api.z.ai") }, store: SnapshotStore(url: url),
            ownedSecrets: FakeOwnedSecrets())
        let result = await WaterlineCLI.run(
            ["account", "add", "zhipu", "--stdin", "--region", "global", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-zhipu"))
        #expect(result.exitCode == 0)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.accounts.first?.account.region == "global")
        #expect(snapshot.accounts.first?.state.reading?.usage.quotaWindows.first?.usedFraction == 0.25)
    }

    @Test func selectedRegionDeterminesOnlyRequestHost() async throws {
        for region in ZhipuAdapter.descriptor.manualRegions {
            _ = try await ZhipuAdapter().fetch(
                Account(provider: .zhipu, credential: .manual, region: region.id), secret: Secret("synthetic"),
                http: ZhipuHTTPFixture(host: region.host))
        }
    }
}
private struct ZhipuHTTPFixture: HTTPClient {
    let host: String
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.host == host)
        #expect(request.url.path == "/api/monitor/usage/quota/limit")
        #expect(request.url.query == nil)
        return HTTPResponse(
            status: 200, headers: [:],
            body: Data(
                #"{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25}]}}"#
                    .utf8))
    }
}
