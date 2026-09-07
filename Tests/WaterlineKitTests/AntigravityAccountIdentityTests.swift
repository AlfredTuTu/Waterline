import Foundation
import Testing

@testable import WaterlineKit

struct AntigravityAccountIdentityTests {
    @Test func restartsAndGoogleEmailCasingPreserveIdentity() throws {
        let before = try parse(email: "  Synthetic+Work@Example.Invalid  ")
        let after = try parse(email: "synthetic+work@example.invalid")
        #expect(before == after)
        #expect(before.key.count == 64)
        #expect(before.key.allSatisfy { $0.isHexDigit })
        #expect(before != (try parse(email: "another@example.invalid")))
        #expect(before != (try parse(email: "synthetic@example.invalid")))
    }

    @Test func onlyOpaqueKeyIsRetained() throws {
        let email = "synthetic@example.invalid"
        let identity = try parse(email: email)
        #expect(!String(describing: identity).contains(email))
        #expect(!String(reflecting: identity).contains(email))
        let children = Array(Mirror(reflecting: identity).children)
        #expect(children.count == 1)
        #expect(children.first?.label == "key")
        #expect(children.first?.value as? String == identity.key)
    }

    @Test func unknownFieldsIncludingPlanAndProcessMetadataDoNotAffectIdentity() throws {
        let identity = try AntigravityAccountIdentity.parse(
            Data(
                #"""
                {"userStatus":{"email":"synthetic@example.invalid","name":"Ignored",
                "planStatus":{"unexpected":true},"userTier":null,"pid":123,"port":456,
                "token":"synthetic-placeholder"},"unknown":[1,2,3]}
                """#.utf8))
        #expect(identity == (try parse(email: "synthetic@example.invalid")))
    }

    @Test(arguments: [
        "", "not-json", "null", "[]", "{}", #"{"userStatus":null}"#,
        #"{"userStatus":[]}"#, #"{"userStatus":{}}"#,
        #"{"userStatus":{"email":null}}"#, #"{"userStatus":{"email":123}}"#,
        #"{"userStatus":{"email":true}}"#, #"{"userStatus":{"email":[]}}"#,
        #"{"userStatus":{"email":{}}}"#,
    ])
    func malformedEnvelopeHasSafeFieldError(json: String) {
        #expect(throws: FetchError.schemaChanged(detail: "userStatus.email")) {
            try AntigravityAccountIdentity.parse(Data(json.utf8))
        }
    }

    @Test(arguments: ["", " ", "missing-at", "@example.invalid", "synthetic@", "a@b@c", "a\n@b", "a@b\t", "a\u{0}@b"])
    func invalidEmailHasSafeFieldError(email: String) {
        #expect(throws: FetchError.schemaChanged(detail: "userStatus.email")) { try parse(email: email) }
    }

    @Test func byteLimitAndEnvelopeSizeAreEnforced() throws {
        _ = try parse(email: String(repeating: "a", count: 318) + "@b")
        #expect(throws: FetchError.schemaChanged(detail: "userStatus.email")) {
            try parse(email: String(repeating: "a", count: 319) + "@b")
        }
        #expect(throws: FetchError.schemaChanged(detail: "userStatus.email")) {
            try parse(email: String(repeating: "é", count: 160) + "@b")
        }
        #expect(throws: FetchError.schemaChanged(detail: "userStatus.size")) {
            try AntigravityAccountIdentity.parse(Data(repeating: 32, count: 1_048_577))
        }
    }

    private func parse(email: String) throws -> AntigravityAccountIdentity {
        try AntigravityAccountIdentity.parse(
            JSONSerialization.data(withJSONObject: ["userStatus": ["email": email]]))
    }
}
