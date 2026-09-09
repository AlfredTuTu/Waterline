import Foundation

/// Local login metadata can associate a new CLI session, but cannot prove current subscription or authorization.
public enum ClaudeLocalLogin {
    public static func identity(_ data: Data) throws -> BillingIdentity {
        guard data.count <= 4_194_304 else { throw FetchError.schemaChanged(detail: "claude.localLogin.size") }
        struct OAuthAccount: Decodable { let accountUuid: String; let organizationUuid: String }
        struct Configuration: Decodable { let oauthAccount: OAuthAccount? }
        let configuration: Configuration
        do { configuration = try JSONDecoder().decode(Configuration.self, from: data) } catch {
            throw schemaError(error, prefix: "claude.localLogin")
        }
        guard let account = configuration.oauthAccount else { throw FetchError.credentialMissing }
        guard UUID(uuidString: account.accountUuid) != nil, UUID(uuidString: account.organizationUuid) != nil else {
            throw FetchError.schemaChanged(detail: "claude.localLogin.oauthAccount.uuid")
        }
        return BillingIdentity(
            region: "api.anthropic.com", account: account.organizationUuid, subject: account.accountUuid)
    }

    public static func matches(_ local: BillingIdentity, verified: BillingIdentity) -> Bool {
        guard local.region == "api.anthropic.com", verified.region == local.region,
            let localSubject = local.subject, let verifiedSubject = verified.subject,
            let localAccount = UUID(uuidString: local.account),
            let verifiedAccount = UUID(uuidString: verified.account),
            let localUser = UUID(uuidString: localSubject), let verifiedUser = UUID(uuidString: verifiedSubject)
        else { return false }
        return localAccount == verifiedAccount && localUser == verifiedUser
    }
}
