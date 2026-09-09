import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeLocalLoginTests {
    @Test func sameUserInDifferentOrganizationsIsNotTheSameAccount() throws {
        let local = try ClaudeLocalLogin.identity(
            Data(
                #"{"oauthAccount":{"accountUuid":"AAAAAAAA-0000-0000-0000-000000000001","organizationUuid":"BBBBBBBB-0000-0000-0000-000000000001","emailAddress":"ignored@example.invalid","subscriptionType":"ignored"}}"#
                    .utf8))
        let matching = BillingIdentity(
            region: "api.anthropic.com", account: local.account.lowercased(), subject: local.subject?.lowercased())
        #expect(ClaudeLocalLogin.matches(local, verified: matching))
        #expect(
            !ClaudeLocalLogin.matches(
                local,
                verified: BillingIdentity(
                    region: matching.region,
                    account: "cccccccc-0000-0000-0000-000000000001", subject: matching.subject)))
        #expect(
            !ClaudeLocalLogin.matches(
                local, verified: BillingIdentity(region: "other", account: local.account, subject: local.subject)))
    }

    @Test func missingAndInvalidIdentityCannotBindAQuota() {
        #expect(throws: FetchError.credentialMissing) { try ClaudeLocalLogin.identity(Data("{}".utf8)) }
        #expect(throws: FetchError.self) {
            try ClaudeLocalLogin.identity(
                Data(#"{"oauthAccount":{"accountUuid":"bad","organizationUuid":"bad"}}"#.utf8))
        }
        #expect(throws: FetchError.self) { try ClaudeLocalLogin.identity(Data(repeating: 32, count: 4_194_305)) }
        let invalid = BillingIdentity(region: "api.anthropic.com", account: "bad", subject: "bad")
        #expect(!ClaudeLocalLogin.matches(invalid, verified: invalid))
    }
}
