import Foundation
import Testing

@testable import WaterlineKit

struct AntigravityQuotaSummaryTests {
    @Test func reconstructedOfficialShapeMapsGroupsOnceAndDoesNotStampFreshness() throws {
        // Synthetic reconstructed fixture matching the observed official response shape; no account data.
        let usage = try parse(
            #"""
            [{"displayName":"Gemini Models","buckets":[
              {"bucketId":"gemini-weekly","displayName":"Weekly Limit Remaining","window":"weekly",
               "remainingFraction":0.75,"resetTime":"2026-09-13T12:36:15Z"},
              {"bucketId":"gemini-5h","displayName":"Five Hour Limit Remaining","window":"5h",
               "remainingFraction":0.5,"resetTime":"2026-09-07T17:06:18.123Z"}]},
             {"displayName":"Claude and GPT models","buckets":[
              {"bucketId":"3p-weekly","window":"weekly","remainingFraction":1},
              {"bucketId":"3p-5h","window":"5h","remainingFraction":0}]}]
            """#)
        #expect(usage.quotaWindows.map(\.id) == ["gemini-weekly", "gemini-5h", "3p-weekly", "3p-5h"])
        #expect(usage.quotaWindows.map(\.usedFraction) == [0.25, 0.5, 0, 1])
        #expect(usage.quotaWindows.map(\.durationSeconds) == [604800, 18000, 604800, 18000])
        #expect(usage.quotaWindows[0].label == "Gemini Models · 7d")
        #expect(usage.quotaWindows[2].group == "Claude and GPT models")
        #expect(usage.quotaWindows[0].resetsAt != nil)
        #expect(usage.quotaWindows[1].resetsAt != nil)
        #expect(usage.quotaWindows.allSatisfy { $0.observedAt == nil })
        #expect(usage.componentFailures.isEmpty)
    }

    @Test func missingNullUnknownCadenceAndUnrelatedFieldsStayUninferred() throws {
        let usage = try parse(
            #"""
            [{"displayName":"Group","modelNames":["one","two"],"buckets":[
              {"bucketId":"a","window":"future","displayName":"Future limit","remainingFraction":null,
               "resetTime":null,"extra":{"anything":true}},
              {"bucketId":"b","window":null}]}]
            """#)
        #expect(usage.quotaWindows.count == 2)
        #expect(
            usage.quotaWindows.allSatisfy { $0.usedFraction == nil && $0.resetsAt == nil && $0.durationSeconds == nil })
        #expect(usage.componentFailures.isEmpty)
    }

    @Test(arguments: ["-0.1", "1.1", "true", "\"0.5\"", "{}"])
    func badFractionPreservesSibling(fraction: String) throws {
        let usage = try parse(
            """
            [{"displayName":"G","buckets":[{"bucketId":"bad","remainingFraction":\(fraction)},
            {"bucketId":"good","remainingFraction":0}]}]
            """)
        #expect(usage.quotaWindows.map(\.id) == ["good"])
        #expect(usage.componentFailures.map(\.id) == ["bad"])
        #expect(
            usage.componentFailures.first?.error
                == .schemaChanged(detail: "response.groups.0.buckets.0.remainingFraction"))
    }

    @Test func malformedGroupBucketResetAndMetadataAreIsolated() throws {
        let usage = try parse(
            #"""
            [null,{"displayName":123,"buckets":[]},{"displayName":"G","buckets":[
              null,{"bucketId":"bad-date","resetTime":"later"},{"bucketId":"bad-type","resetTime":3},
              {"bucketId":"bad-window","window":5},{"bucketId":"bad-name","displayName":false},
              {"bucketId":"good","remainingFraction":0.25}]}]
            """#)
        #expect(usage.quotaWindows.map(\.id) == ["good"])
        #expect(usage.componentFailures.count == 7)
    }

    @Test func duplicateIdentityCollapsesIdenticalAndInvalidatesConflicts() throws {
        let usage = try parse(
            #"""
            [{"displayName":"G","buckets":[
              {"bucketId":"same","remainingFraction":1},{"bucketId":"same","remainingFraction":1},
              {"bucketId":"conflict","remainingFraction":1},{"bucketId":"conflict","remainingFraction":0},
              {"bucketId":"conflict","remainingFraction":1},
              {"bucketId":"future","window":"future-a"},{"bucketId":"future","window":"future-b"},
              {"bucketId":"invalid","remainingFraction":1},{"bucketId":"invalid","remainingFraction":true}]}]
            """#)
        #expect(usage.quotaWindows.map(\.id) == ["same"])
        #expect(usage.componentFailures.map(\.id) == ["conflict", "future", "invalid"])
    }

    @Test func malformedEnvelopeAndOversizeAreRejectedWhileEmptyIsEmpty() throws {
        for json in ["{}", #"{"response":null}"#, #"{"response":{"groups":null}}"#, "not JSON"] {
            #expect(throws: FetchError.self) { try AntigravityQuotaSummary.parse(Data(json.utf8)) }
        }
        #expect(throws: FetchError.self) { try AntigravityQuotaSummary.parse(Data(repeating: 32, count: 1_048_577)) }
        #expect(try parse("[]").quotaWindows.isEmpty)
    }

    private func parse(_ groups: String) throws -> Usage {
        try AntigravityQuotaSummary.parse(Data("{\"response\":{\"groups\":\(groups)}}".utf8))
    }
}
