import Testing

@testable import WaterlineKit

struct AccountNavigationTests {
    @Test func notificationTargetIsBoundedAndOpaque() {
        #expect(AccountNavigation.decodeTarget(nil) == nil)
        #expect(AccountNavigation.decodeTarget("") == nil)
        #expect(AccountNavigation.decodeTarget("bad\nidentifier") == nil)
        #expect(AccountNavigation.decodeTarget(String(repeating: "x", count: 257)) == nil)
        #expect(AccountNavigation.decodeTarget("legacy-opaque-id") == AccountID(rawValue: "legacy-opaque-id"))
    }

    @Test func targetWaitsForLoadingAndDoesNotInventRemovedAccount() {
        let id = AccountID(rawValue: "target")
        let row = AccountEntry(account: Account(id: id, provider: .codex, credential: .manual), state: .pending)
        #expect(AccountNavigation.resolve(id, accounts: [], loading: true) == .loading(id))
        #expect(AccountNavigation.resolve(id, accounts: [row], loading: true) == .detail(id))
        #expect(AccountNavigation.resolve(id, accounts: [], loading: false) == .unavailable)
        #expect(AccountNavigation.resolve(nil, accounts: [row], loading: false) == .overview)
    }

    @Test func repeatedTargetCreatesAnotherNavigationEvent() {
        let id = AccountID(rawValue: "target")
        let first = AccountNavigationRequest(accountID: id)
        let second = AccountNavigationRequest(accountID: id)
        #expect(first.accountID == second.accountID)
        #expect(first.requestID != second.requestID)
    }
}
