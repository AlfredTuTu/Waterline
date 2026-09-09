import Foundation
import Testing

@testable import WaterlineKit

struct AccountScopeMatchingTests {
    @Test func unidentifiedSourceAccountsKeepRegionsAndTeamsSeparate() async {
        let subject = engine(
            [], at: FileManager.default.temporaryDirectory.appending(path: "scope-\(UUID())/snapshot.json"))
        let reference = CredentialRef.configuration(
            source: .zhipuClaudeSettings, path: "/synthetic/settings.json", key: "ANTHROPIC_AUTH_TOKEN")
        let china = Account(provider: .zhipu, credential: reference, region: "cn", teamID: "a")
        let global = Account(provider: .zhipu, credential: reference, region: "global", teamID: "a")
        let otherTeam = Account(provider: .zhipu, credential: reference, region: "cn", teamID: "b")
        #expect(await !subject.sameAccount(china, global))
        #expect(await !subject.sameAccount(china, otherTeam))
    }

    @Test func unknownCredentialScopeCanRecoverExistingIdentityButExplicitMismatchCannot() async {
        let subject = engine(
            [], at: FileManager.default.temporaryDirectory.appending(path: "scope-\(UUID())/snapshot.json"))
        let reference = CredentialRef.file(path: "/synthetic/auth.json")
        let known = Account(
            provider: .zhipu, credential: reference,
            identity: BillingIdentity(region: "cn", account: "synthetic"), region: "cn")
        let managed = [ManagedAccount(account: known, preferences: AccountPreferences())]
        let unknown = Discovered(
            account: Account(provider: .zhipu, credential: reference), secret: nil, connectionError: .credentialMissing)
        let mismatch = Discovered(
            account: Account(provider: .zhipu, credential: reference, region: "global"), secret: nil,
            connectionError: .credentialMissing)
        #expect(await subject.discoveryMatch(unknown, in: managed) == 0)
        #expect(await subject.discoveryMatch(mismatch, in: managed) == nil)
    }
}
