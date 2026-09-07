import Foundation
import Testing

@testable import WaterlineKit

struct CursorLegacyTests {
    @Test func totalRequestsTakePrecedenceAndResetIsNotInvented() throws {
        let window = try #require(
            try CursorAdapter.parseRequestUsage(
                Data(
                    #"{"gpt-4":{"numRequests":12,"numRequestsTotal":347,"maxRequestUsage":500},"startOfMonth":"2026-09-01"}"#
                        .utf8)))
        #expect(window.used == 347 && window.limit == 500 && window.unit == "requests")
        #expect(window.usedFraction == 0.694)
        #expect(window.resetsAt == nil)
    }

    @Test func missingAndZeroCapsNeverFabricateAQuotaFraction() throws {
        #expect(try CursorAdapter.parseRequestUsage(Data(#"{"gpt-4":{"numRequests":12}}"#.utf8)) == nil)
        let zero = try #require(
            try CursorAdapter.parseRequestUsage(Data(#"{"gpt-4":{"numRequests":12,"maxRequestUsage":0}}"#.utf8)))
        #expect(zero.usedFraction == nil && zero.used == 12 && zero.limit == 0)
        let missing = try #require(
            try CursorAdapter.parseRequestUsage(Data(#"{"gpt-4":{"maxRequestUsage":500}}"#.utf8)))
        #expect(missing.usedFraction == nil && missing.used == nil)
    }

    @Test func invalidCountsAreExplicitErrors() {
        for body in [
            #"{"gpt-4":{"numRequests":-1,"maxRequestUsage":500}}"#,
            #"{"gpt-4":{"numRequestsTotal":"bad","maxRequestUsage":500}}"#,
        ] {
            #expect(throws: FetchError.self) { try CursorAdapter.parseRequestUsage(Data(body.utf8)) }
        }
    }

    @Test func legacyRequestQuotaReplacesModernQuotaBarsInFetch() async throws {
        let claims = Data(#"{"sub":"auth0|legacy-user"}"#.utf8).base64EncodedString().replacingOccurrences(
            of: "=", with: "")
        let account = Account(
            provider: .cursor, credential: .file(path: "/synthetic/state.vscdb"),
            identity: BillingIdentity(region: "cursor.com", account: "legacy-user"))
        let usage = try await CursorAdapter().fetch(
            account, secret: Secret("header.\(claims).signature"), http: LegacyHTTP())
        #expect(usage.componentFailures.isEmpty)
        #expect(!usage.quotaWindows.contains { ["Included", "Auto", "API"].contains($0.label) })
        let request = try #require(usage.quotaWindows.first { $0.id == "legacy-requests" })
        #expect(request.usedFraction == 0.694)
        #expect(request.resetsAt == ISO8601DateFormatter().date(from: "2026-10-01T00:00:00Z"))
    }
}

private struct LegacyHTTP: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.host == "cursor.com")
        let body: String
        switch request.url.path {
        case "/api/usage-summary":
            body =
                #"{"membershipType":"pro","billingCycleEnd":"2026-10-01T00:00:00Z","individualUsage":{"plan":{"totalPercentUsed":7,"autoPercentUsed":11,"apiPercentUsed":22}}}"#
        case "/api/usage":
            #expect(
                URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems == [
                    URLQueryItem(name: "user", value: "legacy-user")
                ])
            body = #"{"gpt-4":{"numRequestsTotal":347,"maxRequestUsage":500}}"#
        case "/api/dashboard/get-sand-usage-status": body = #"{"hasNonZeroIncludedLimit":false}"#
        default: throw FetchError.transport(detail: "Unexpected request")
        }
        return HTTPResponse(status: 200, headers: [:], body: Data(body.utf8))
    }
}
