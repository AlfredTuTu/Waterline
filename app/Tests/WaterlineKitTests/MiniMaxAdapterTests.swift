import Foundation
import Testing

@testable import WaterlineKit

struct MiniMaxAdapterTests {
    @Test func legacyUsageCountMeansRemaining() throws {
        let usage = try MiniMaxAdapter.parse(
            Data(
                #"{"base_resp":{"status_code":0},"model_remains":[{"model_name":"legacy","current_interval_total_count":1000,"current_interval_usage_count":250,"end_time":1800000000000}]}"#
                    .utf8))
        #expect(usage.quotaWindows.first?.usedFraction == 0.75)
        #expect(usage.quotaWindows.first?.used == 750)
        #expect(usage.quotaWindows.first?.resetsAt == Date(timeIntervalSince1970: 1_800_000_000))
    }
    @Test func modernPercentDoesNotInventAbsoluteQuotaCounts() throws {
        let usage = try MiniMaxAdapter.parse(
            Data(
                #"{"data":{"base_resp":{"status_code":0},"model_remains":[{"model_name":"general","current_interval_total_count":0,"current_interval_usage_count":0,"current_interval_remaining_percent":96,"current_interval_status":1,"current_weekly_remaining_percent":70,"current_weekly_status":1,"weekly_boost_permille":1500}]}}"#
                    .utf8))
        #expect(usage.quotaWindows.map(\.usedFraction) == [0.04, 0.3])
        #expect(usage.quotaWindows.allSatisfy { $0.used == nil && $0.limit == nil })
        #expect(usage.balances.isEmpty)
    }
    @Test func unquantifiedLaneDoesNotBecomeZeroUsed() throws {
        let usage = try MiniMaxAdapter.parse(
            Data(
                #"{"model_remains":[{"model_name":"video","current_weekly_status":3,"current_weekly_remaining_percent":100,"current_weekly_total_count":0}]}"#
                    .utf8))
        #expect(usage.quotaWindows.first?.usedFraction == nil)
        #expect(usage.quotaWindows.first?.note != nil)
    }
    @Test func statusAloneDoesNotEraseAReportedPercentage() throws {
        let usage = try MiniMaxAdapter.parse(
            Data(
                #"{"model_remains":[{"model_name":"general","current_weekly_status":3,"current_weekly_remaining_percent":50}]}"#
                    .utf8))
        #expect(usage.quotaWindows.first?.usedFraction == 0.5)
    }

    @Test func badWeeklyFieldPreservesCurrentWindow() throws {
        let usage = try MiniMaxAdapter.parse(
            Data(
                #"{"model_remains":[{"model_name":"general","current_interval_remaining_percent":80,"current_weekly_remaining_percent":"bad"}]}"#
                    .utf8))
        #expect(usage.quotaWindows.count == 1)
        #expect(usage.quotaWindows[0].usedFraction == 0.2)
        #expect(usage.componentFailures.first?.id == "model_remains.general.weekly")
    }
    @Test func regionalManualFlowUsesCurrentDocumentedEndpoint() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-minimax-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let deps = Engine.Dependencies(
            adapters: [MiniMaxAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in MiniMaxHTTPFixture() },
            store: SnapshotStore(url: url), ownedSecrets: FakeOwnedSecrets())
        let result = await WaterlineCLI.run(
            ["account", "add", "minimax", "--region", "global", "--stdin", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-minimax"))
        #expect(result.exitCode == 0)
        #expect(
            try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8)).accounts.first?.state
                .reading?.usage.quotaWindows.first?.usedFraction == 0.1)
    }
}
private struct MiniMaxHTTPFixture: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://www.minimax.io/v1/token_plan/remains")
        #expect(request.headers["Authorization"] == "Bearer synthetic-minimax")
        return HTTPResponse(
            status: 200, headers: [:],
            body: Data(
                #"{"base_resp":{"status_code":0},"model_remains":[{"model_name":"general","current_interval_remaining_percent":90,"current_interval_status":1}]}"#
                    .utf8))
    }
}
