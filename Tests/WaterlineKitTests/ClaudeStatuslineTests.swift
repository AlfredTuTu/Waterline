import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeStatuslineTests {
    private func payload(_ limits: String) -> Data {
        Data(
            (#"{"session_id":"00000000-0000-0000-0000-000000000001","version":"2.1.263","cost":{"total_api_duration_ms":500},"context_window":{"used_percentage":99},"rate_limits":"#
                + limits + "}").utf8)
    }

    @Test func readsSubscriptionWindowsWithoutContextOrUnknownBuckets() throws {
        let reading = try ClaudeStatusline.parse(
            payload(
                #"{"seven_day":{"used_percentage":31,"resets_at":1789192800},"five_hour":{"used_percentage":30,"resets_at":1788887400},"future_model_bucket":{"unknown":true}}"#
            ))
        #expect(reading.quotas.map(\.id) == ["five_hour", "seven_day"])
        #expect(reading.quotas.map(\.usedFraction) == [0.3, 0.31])
        #expect(reading.apiDurationMilliseconds == 500)
    }

    @Test func absenceAndExpiredResetDoNotInventZeroOrFreshness() throws {
        #expect(try ClaudeStatusline.parse(payload("null")).quotas.isEmpty)
        #expect(try ClaudeStatusline.parse(payload("{}")).quotas.isEmpty)
        let reading = try ClaudeStatusline.parse(payload(#"{"five_hour":{"used_percentage":0,"resets_at":1}}"#))
        #expect(reading.quotas.first?.usedFraction == 0)
        #expect(reading.quotas.first?.resetsAt == Date(timeIntervalSince1970: 1))
    }

    @Test(arguments: [
        #"{"five_hour":{"used_percentage":101,"resets_at":1}}"#,
        #"{"five_hour":{"used_percentage":true,"resets_at":1}}"#,
        #"{"five_hour":{"used_percentage":2,"resets_at":-1}}"#,
        #"{"five_hour":{"used_percentage":2}}"#,
    ])
    func malformedWindowDoesNotBecomeFree(limits: String) {
        #expect(throws: FetchError.self) { try ClaudeStatusline.parse(payload(limits)) }
    }

    @Test func boundsAndSessionIdentity() {
        #expect(throws: FetchError.self) { try ClaudeStatusline.parse(Data(repeating: 32, count: 1_048_577)) }
        #expect(throws: FetchError.self) {
            try ClaudeStatusline.parse(Data(#"{"session_id":"invalid","version":"2.1.263"}"#.utf8))
        }
    }
}
