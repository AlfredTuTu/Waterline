import Foundation
import Testing

@testable import WaterlineKit

struct AntigravityStatuslineTests {
    @Test func officialShapeMapsOnlyQuotaAndDoesNotInferWindowsFromPlan() throws {
        let value = try AntigravityStatusline.parse(
            Data(
                #"""
                {"product":"antigravity","email":"synthetic@example.invalid","plan_tier":"Test plan",
                 "context_window":{"used_percentage":99},"cwd":"/not-retained","quota":{
                   "bucket-a":{"remaining_fraction":0.75,"reset_time":"2026-09-07T06:00:00.000Z"},
                   "bucket-b":{"remaining_fraction":0},"bucket-c":{"remaining_fraction":1},
                   "unknown":{"reset_in_seconds":300}},"unrelated":"ignored"}
                """#.utf8))
        #expect(value.accountSubject == "synthetic@example.invalid")
        #expect(value.windows.map(\.id) == ["bucket-a", "bucket-b", "bucket-c", "unknown"])
        #expect(value.windows.map(\.usedFraction) == [0.25, 1, 0, nil])
        #expect(value.windows[0].resetsAt != nil)
        #expect(value.windows[3].resetsAt == nil)
    }

    @Test func missingQuotaIsMissingRatherThanAnUnusedAllowance() throws {
        let value = try AntigravityStatusline.parse(
            Data(#"{"product":"antigravity","email":"test","plan_tier":"Ultra"}"#.utf8))
        #expect(value.windows.isEmpty)
    }

    @Test(arguments: ["-0.1", "1.1", "\"0.5\""])
    func incompatibleFractionIsRejected(fraction: String) {
        let json =
            "{\"product\":\"antigravity\",\"email\":\"test\",\"quota\":{\"bucket\":{\"remaining_fraction\":\(fraction)}}}"
        #expect(throws: FetchError.self) { try AntigravityStatusline.parse(Data(json.utf8)) }
    }

    @Test func wrongProductUnknownIdentityBadDateAndOversizeAreRejected() {
        for json in [
            #"{"product":"other","email":"test"}"#,
            #"{"product":"antigravity","email":" "}"#,
            #"{"product":"antigravity","email":"test","quota":{"a":{"reset_time":"later"}}}"#,
        ] {
            #expect(throws: FetchError.self) { try AntigravityStatusline.parse(Data(json.utf8)) }
        }
        #expect(throws: FetchError.self) { try AntigravityStatusline.parse(Data(repeating: 32, count: 1_048_577)) }
    }
}
