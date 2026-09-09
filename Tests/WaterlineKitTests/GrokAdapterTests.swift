import Foundation
import Testing

@testable import WaterlineKit

struct GrokAdapterTests {
    private let period =
        #"{"type":"USAGE_PERIOD_TYPE_WEEKLY","start":"2026-09-08T00:00:00Z","end":"2026-09-15T00:00:00Z"}"#

    @Test func subscriptionIdentityAndMissingTier() throws {
        #expect(
            try GrokAdapter.subscriptionPlan(Data(#"{"userId":"u","subscriptionTier":"GrokPro"}"#.utf8), subject: "u")
                == "GrokPro")
        #expect(try GrokAdapter.subscriptionPlan(Data(#"{"userId":"u"}"#.utf8), subject: "u") == nil)
        #expect(throws: FetchError.credentialMissing) {
            try GrokAdapter.subscriptionPlan(
                Data(#"{"userId":"other","subscriptionTier":"GrokPro"}"#.utf8), subject: "u")
        }
        #expect(throws: FetchError.self) {
            try GrokAdapter.subscriptionPlan(Data(#"{"userId":"u","subscriptionTier":12}"#.utf8), subject: "u")
        }
    }

    @Test func subscriptionFailureRetainsQuotaAndRateLimit() async throws {
        let http = GrokHTTP(profileStatus: 429)
        let account = Account(
            provider: .grok, credential: .file(path: "/synthetic/auth.json"),
            identity: BillingIdentity(region: "grok.com", account: "synthetic", subject: "synthetic-user"))
        let usage = try await GrokAdapter().fetch(account, secret: Secret("synthetic-token"), http: http)
        #expect(usage.quotaWindows.first?.usedFraction == 0.2)
        #expect(usage.planLabel == nil)
        #expect(
            usage.componentFailures == [
                MetricFailure(id: "grok.subscription-plan", error: .rateLimited(retryAfter: nil))
            ])
    }

    @Test func reportedPercentAndUnifiedZeroRemainSeparateFromUnknown() throws {
        let used = try GrokAdapter.parse(
            Data("{\"config\":{\"creditUsagePercent\":37.5,\"currentPeriod\":\(period)}}".utf8))
        #expect(used.quotaWindows.first?.usedFraction == 0.375)
        #expect(used.quotaWindows.first?.durationSeconds == 604800)
        #expect(used.quotaWindows.first?.resetsAt != nil)
        let zero = try GrokAdapter.parse(
            Data("{\"config\":{\"isUnifiedBillingUser\":true,\"currentPeriod\":\(period)}}".utf8))
        #expect(zero.quotaWindows.first?.usedFraction == 0)
        for data in [#"{"config":{}}"#, #"{"config":{"creditUsagePercent":null}}"#] {
            #expect(try GrokAdapter.parse(Data(data.utf8)).quotaWindows.first?.usedFraction == nil)
        }
        for data in [
            #"{"config":{"creditUsagePercent":101}}"#, #"{"config":{"creditUsagePercent":true}}"#, #"{"config":null}"#,
        ] {
            #expect(throws: FetchError.self) { try GrokAdapter.parse(Data(data.utf8)) }
        }
    }

    @Test func discoveryPreservesIdentityAcrossTokenRotationAndIgnoresOtherIssuers() async throws {
        func environment(token: String) throws -> DiscoveryEnvironment {
            let data = try JSONSerialization.data(withJSONObject: [
                "https://auth.x.ai::synthetic-client": [
                    "auth_mode": "oidc", "principal_type": "User", "user_id": "synthetic-user",
                    "key": token, "oidc_issuer": "https://auth.x.ai", "oidc_client_id": "synthetic-client",
                ],
                "https://other.example": ["unrelated": true],
            ])
            return DiscoveryEnvironment(
                home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
                fileSystem: GrokFiles(data: data), keychain: EmptyKeychain(), allowsUserInteraction: false)
        }
        let http = GrokHTTP()
        let first = try await GrokAdapter().discover(in: environment(token: "synthetic-first"), http: http)
        let second = try await GrokAdapter().discover(in: environment(token: "synthetic-second"), http: http)
        #expect(first.count == 1)
        #expect(first.first?.account.id == second.first?.account.id)
        #expect(second.first?.secret?.value == "synthetic-second")
        #expect(await http.requests.isEmpty)
    }

    @Test func fetchOnlyUsesConsumerBillingEndpointAndRejectsOtherScopes() async throws {
        let http = GrokHTTP()
        let identity = BillingIdentity(region: "grok.com", account: "synthetic", subject: "synthetic-user")
        let account = Account(
            provider: .grok, credential: .file(path: "/synthetic/.grok/auth.json"), identity: identity)
        _ = try await GrokAdapter().fetch(account, secret: Secret("synthetic-token"), http: http)
        let requests = await http.requests
        #expect(requests.count == 2)
        #expect(requests.first?.url.absoluteString == "https://cli-chat-proxy.grok.com/v1/billing?format=credits")
        #expect(requests.last?.url.absoluteString == "https://cli-chat-proxy.grok.com/v1/user?include=subscription")
        #expect(requests.first?.headers["X-XAI-Token-Auth"] == "xai-grok-cli")
        #expect(requests.first?.headers["x-userid"] == "synthetic-user")
        let wrong = Account(provider: .xai, credential: .manual, identity: identity)
        await #expect(throws: FetchError.credentialMissing) {
            try await GrokAdapter().fetch(wrong, secret: Secret("synthetic-token"), http: http)
        }
        #expect(await http.requests.count == 2)
    }
}

private struct GrokFiles: FileSystem {
    let data: Data
    func exists(_ url: URL) -> Bool { url.path == "/synthetic/.grok/auth.json" }
    func contents(of url: URL) throws -> Data { data }
    func modificationDate(of url: URL) throws -> Date { Date(timeIntervalSince1970: 0) }
}
private actor GrokHTTP: HTTPClient {
    let profileStatus: Int
    init(profileStatus: Int = 200) { self.profileStatus = profileStatus }
    var requests: [HTTPRequest] = []
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        if request.url.path == "/v1/user" {
            return HTTPResponse(
                status: profileStatus, headers: [:],
                body: Data(#"{"userId":"synthetic-user","subscriptionTier":"GrokPro"}"#.utf8)
            )
        }
        return HTTPResponse(status: 200, headers: [:], body: Data(#"{"config":{"creditUsagePercent":20}}"#.utf8))
    }
}
