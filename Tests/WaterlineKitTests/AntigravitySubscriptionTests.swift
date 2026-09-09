import Foundation
import Testing

@testable import WaterlineKit

struct AntigravitySubscriptionTests {
    @Test func specificTierTakesPriorityOverGenericPlan() throws {
        let data = Data(
            #"{"userStatus":{"userTier":{"name":"Google AI Ultra"},"planStatus":{"planInfo":{"planName":"Pro"}}}}"#.utf8
        )
        #expect(try AntigravitySubscription.plan(data) == "Google AI Ultra")
    }

    @Test func absentTierDoesNotInventMembership() throws {
        #expect(try AntigravitySubscription.plan(Data(#"{"userStatus":{}}"#.utf8)) == nil)
        #expect(
            try AntigravitySubscription.plan(
                Data(#"{"userStatus":{"planStatus":{"planInfo":{"planName":"Pro"}}}}"#.utf8)) == "Pro")
    }

    @Test(arguments: [#"{"userStatus":{"userTier":{"name":12}}}"#, #"{"userStatus":{"userTier":{"name":""}}}"#])
    func malformedTierIsNotFree(json: String) {
        #expect(throws: FetchError.self) { try AntigravitySubscription.plan(Data(json.utf8)) }
    }
}
