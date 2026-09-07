import Foundation
import SQLite3
import Testing

@testable import WaterlineKit

struct CursorAdapterTests {
    @Test func currentModelPoolsReplaceTheAggregateAsIndependentQuotas() throws {
        let usage = try CursorAdapter.parse(
            Data(
                #"{"individualUsage":{"plan":{"used":520,"limit":2000,"totalPercentUsed":1.07,"autoPercentUsed":1.15,"apiPercentUsed":0}}}"#
                    .utf8))
        #expect(!usage.quotaWindows.contains { $0.id == "individualUsage.plan" })
        #expect(usage.quotaWindows.first { $0.id == "individualUsage.plan.autoPercentUsed" }?.label == "Cursor Models")
        #expect(usage.quotaWindows.first { $0.id == "individualUsage.plan.apiPercentUsed" }?.label == "Other Models")
        #expect(usage.quotaWindows.first { $0.id == "individualUsage.plan.spend" }?.used == Decimal(string: "5.2"))
    }
    @Test func reportedPercentageAndMoneyRemainDistinctWhenTheyDisagree() throws {
        // Synthetic regression matching the differing units observed in the live response.
        let usage = try CursorAdapter.parse(
            Data(#"{"individualUsage":{"plan":{"used":520,"limit":2000,"totalPercentUsed":1.07}}}"#.utf8))
        let quota = try #require(usage.quotaWindows.first { $0.id == "individualUsage.plan" })
        let spend = try #require(usage.quotaWindows.first { $0.id == "individualUsage.plan.spend" })
        #expect(abs(try #require(quota.usedFraction) - 0.0107) < 0.000000001)
        #expect(quota.used == nil && quota.limit == nil && quota.unit == nil)
        #expect(spend.used == Decimal(string: "5.2") && spend.limit == 20)
        #expect(spend.usedFraction == nil)
    }

    @Test func fetchUsesScopedCookieAndRetainsSummaryWhenGrokFails() async throws {
        let claims = Data(#"{"sub":"auth0|synthetic-user"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        let secret = Secret("header.\(claims).signature")
        let account = Account(
            provider: .cursor, credential: .file(path: "/synthetic/state.vscdb"),
            identity: BillingIdentity(region: "cursor.com", account: "synthetic-user"))
        let result = try await CursorAdapter().fetch(account, secret: secret, http: CursorHTTP(secret: secret))
        #expect(result.quotaWindows.first?.usedFraction == 0.4)
        #expect(result.componentFailures == [MetricFailure(id: "grok-bot", error: .rateLimited(retryAfter: 60))])
    }

    @Test func independentPoolsAreNotAveragedAndSmallPercentIsNotAFraction() throws {
        let usage = try CursorAdapter.parse(
            Data(
                #"{"membershipType":"pro","individualUsage":{"plan":{"autoPercentUsed":0.36,"apiPercentUsed":70}}}"#
                    .utf8))
        #expect(usage.quotaWindows.count == 2)
        #expect(usage.quotaWindows[0].usedFraction == 0.0036)
        #expect(usage.quotaWindows[1].usedFraction == 0.7)
        #expect(!usage.quotaWindows.contains { $0.label == "Included" })
        #expect(usage.planLabel == "pro")
    }

    @Test func moneyPoolsAndAbsentCapsStaySeparate() throws {
        let usage = try CursorAdapter.parse(
            Data(
                #"{"individualUsage":{"overall":{"used":1250,"limit":2000},"onDemand":{"enabled":true,"used":50}},"teamUsage":{"pooled":{"used":3000,"limit":10000}}}"#
                    .utf8))
        #expect(usage.quotaWindows.map(\.used) == [Decimal(string: "12.5"), Decimal(string: "0.5"), Decimal(30)])
        #expect(usage.quotaWindows[1].limit == nil)
        #expect(usage.quotaWindows[1].usedFraction == nil)
        #expect(usage.balances.isEmpty)
    }

    @Test func badPoolRetainsOtherPoolAndMissingDataIsNotZero() throws {
        let usage = try CursorAdapter.parse(
            Data(#"{"individualUsage":{"plan":{"used":"broken"},"onDemand":{"used":0,"limit":0}}}"#.utf8))
        #expect(usage.quotaWindows.count == 1)
        #expect(usage.quotaWindows[0].used == 0)
        #expect(usage.quotaWindows[0].usedFraction == nil)
        #expect(usage.componentFailures.first?.id == "individualUsage.plan")
        #expect(throws: FetchError.self) { try CursorAdapter.parse(Data("{}".utf8)) }
    }

    @Test func grokIsIndependentAndRequiresReportedAllowance() throws {
        #expect(try CursorAdapter.parseGrok(Data(#"{"hasNonZeroIncludedLimit":false,"usagePercent":0}"#.utf8)) == nil)
        let window = try CursorAdapter.parseGrok(
            Data(
                #"{"hasNonZeroIncludedLimit":true,"usagePercent":25,"nextResetTimestampUtc":"2026-09-10T00:00:00Z"}"#
                    .utf8))
        #expect(window?.id == "grok-bot")
        #expect(window?.usedFraction == 0.25)
        #expect(window?.resetsAt != nil)
    }

    @Test func sqliteReadDoesNotMutateOrCreateDatabase() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "state.vscdb")
        let reader = SystemCredentialDatabase()
        #expect(throws: FetchError.self) { try reader.cursorAccessToken(at: url) }
        #expect(!FileManager.default.fileExists(atPath: url.path))
        var database: OpaquePointer?
        #expect(sqlite3_open(url.path, &database) == SQLITE_OK)
        #expect(
            sqlite3_exec(
                database,
                "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT); INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', 'synthetic-token');",
                nil, nil, nil) == SQLITE_OK)
        sqlite3_close(database)
        let before = try Data(contentsOf: url)
        #expect(try reader.cursorAccessToken(at: url)?.value == "synthetic-token")
        #expect(try Data(contentsOf: url) == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["state.vscdb"])
    }

    @Test func headerInjectionAndMalformedTokensAreRejected() {
        for value in ["bad", "a.b.c\r\nCookie: bad", "a...c"] {
            #expect(throws: FetchError.self) { try CursorAdapter.subject(Secret(value)) }
        }
    }
}

private struct CursorHTTP: HTTPClient {
    let secret: Secret
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        #expect(request.url.host == "cursor.com")
        #expect(request.url.scheme == "https")
        #expect(request.headers["Cookie"] == "WorkosCursorSessionToken=synthetic-user%3A%3A\(secret.value)")
        if request.url.path == "/api/usage-summary" {
            #expect(request.method == "GET")
            return HTTPResponse(
                status: 200, headers: [:], body: Data(#"{"individualUsage":{"plan":{"totalPercentUsed":40}}}"#.utf8))
        }
        if request.url.path == "/api/usage" {
            #expect(
                URLComponents(url: request.url, resolvingAgainstBaseURL: false)?.queryItems == [
                    URLQueryItem(name: "user", value: "synthetic-user")
                ])
            return HTTPResponse(status: 200, headers: [:], body: Data("{}".utf8))
        }
        #expect(request.url.path == "/api/dashboard/get-sand-usage-status")
        #expect(request.method == "POST")
        #expect(request.headers["Origin"] == "https://cursor.com")
        #expect(request.body == Data("{}".utf8))
        return HTTPResponse(status: 429, headers: ["Retry-After": "60"], body: Data())
    }
}
