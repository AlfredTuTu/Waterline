import Foundation
import Testing

@testable import WaterlineKit

struct KimiCodeAdapterTests {
    @Test(arguments: ["cn", "global"])
    func regionalRequestsStayOnSelectedHost(region: String) async throws {
        let host = region == "cn" ? "api.kimi.com" : "api.kimi.ai"
        let usage = try await KimiCodeAdapter().fetch(
            Account(provider: .kimiCode, credential: .manual, region: region),
            secret: Secret("synthetic-kimi-code"), http: KimiHTTPFixture(host: host))
        #expect(usage.quotaWindows.first?.usedFraction == 0.25)
        #expect(usage.balances.isEmpty)
    }

    @Test func invalidRegionRejectedBeforeNetwork() async {
        do {
            _ = try await KimiCodeAdapter().fetch(
                Account(provider: .kimiCode, credential: .manual, region: "untrusted"),
                secret: Secret("synthetic-kimi-code"), http: KimiUnexpectedHTTP())
            Issue.record("Invalid region must fail")
        } catch { #expect(error as? ManualKeyError == .invalidRegion) }
    }

    @Test func subscriptionAndWindowCountsRemainDistinct() throws {
        let usage = try KimiCodeAdapter.parse(
            Data(
                #"{"usage":{"limit":"2048","used":"214","remaining":"1834","resetTime":"2026-09-09T12:00:00.123456789Z"},"limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},"detail":{"limit":"200","used":"139","remaining":"61"}}],"user":{"membership":{"level":"LEVEL_BASIC"}}}"#
                    .utf8))
        #expect(usage.quotaWindows.count == 2)
        #expect(usage.quotaWindows[0].used == 214)
        #expect(usage.quotaWindows[0].limit == 2048)
        #expect(usage.quotaWindows[1].label == "5h")
        #expect(usage.quotaWindows[1].usedFraction == 0.695)
        #expect(usage.quotaWindows[1].resetsAt == nil)
        #expect(usage.planLabel == "LEVEL_BASIC")
        #expect(usage.balances.isEmpty)
    }

    @Test func remainingCanDeriveUsageButZeroLimitCannotCreateAPercent() throws {
        let usage = try KimiCodeAdapter.parse(
            Data(
                #"{"usage":{"limit":"100","remaining":"75"},"limits":[{"window":{"duration":1,"timeUnit":"TIME_UNIT_DAY"},"detail":{"limit":"0","used":"0"}}]}"#
                    .utf8))
        #expect(usage.quotaWindows[0].usedFraction == 0.25)
        #expect(usage.quotaWindows[1].usedFraction == nil)
        #expect(usage.quotaWindows[1].used == 0)
    }

    @Test func malformedWindowDoesNotEraseOtherWindows() throws {
        let usage = try KimiCodeAdapter.parse(
            Data(
                #"{"usage":{"limit":"100","used":"10"},"limits":[false,{"window":{"duration":5,"timeUnit":"TIME_UNIT_HOUR"},"detail":{"limit":"20","used":"5"}}]}"#
                    .utf8))
        #expect(usage.quotaWindows.count == 2)
        #expect(usage.componentFailures.count == 1)
    }

    @Test func manualFlowUsesCodingHostAndDoesNotCreatePlatformBalance() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "waterline-kimi-code-\(UUID())/snapshot.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let deps = Engine.Dependencies(
            adapters: [KimiCodeAdapter()],
            environment: DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:], fileSystem: EmptyFiles(),
                keychain: EmptyKeychain(), allowsUserInteraction: false), makeHTTPClient: { _ in KimiHTTPFixture() },
            store: SnapshotStore(url: url), ownedSecrets: FakeOwnedSecrets())
        let result = await WaterlineCLI.run(
            ["account", "add", "kimi-code", "--region", "cn", "--stdin", "--json"], dependencies: deps,
            inputSecret: Secret("synthetic-kimi-code"))
        #expect(result.exitCode == 0)
        let snapshot = try SnapshotStore.decoder.decode(Snapshot.self, from: Data(result.output.utf8))
        #expect(snapshot.accounts.first?.account.provider == .kimiCode)
        #expect(snapshot.accounts.first?.state.reading?.usage.balances.isEmpty == true)
    }
}

private struct KimiHTTPFixture: HTTPClient {
    var host = "api.kimi.com"
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.absoluteString == "https://\(host)/coding/v1/usages")
        #expect(request.headers["Authorization"] == "Bearer synthetic-kimi-code")
        return HTTPResponse(status: 200, headers: [:], body: Data(#"{"usage":{"limit":"100","used":"25"}}"#.utf8))
    }
}

private struct KimiUnexpectedHTTP: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        Issue.record("Region validation must happen before sending credentials")
        throw FetchError.credentialMissing
    }
}
