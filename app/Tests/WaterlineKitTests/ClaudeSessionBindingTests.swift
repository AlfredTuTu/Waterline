import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeSessionBindingTests {
    let session = UUID()
    let identity = BillingIdentity(
        region: "api.anthropic.com",
        account: "00000000-0000-0000-0000-000000000001", subject: "00000000-0000-0000-0000-000000000002")

    func reading(_ duration: Double?, withQuota: Bool = false) -> ClaudeStatuslineReading {
        ClaudeStatuslineReading(
            sessionID: session, version: "2.1.263", apiDurationMilliseconds: duration,
            quotas: withQuota
                ? [
                    ClaudeStatuslineQuota(
                        id: "five_hour", usedFraction: 0.3, resetsAt: Date(timeIntervalSince1970: 1800000000))
                ] : [])
    }

    @Test func bindsAtStartPersistsAndRejectsReplayedCallbacks() throws {
        let binding = try #require(
            ClaudeSessionBinding(initial: reading(0), localIdentity: identity, verifiedIdentity: identity))
        var restored = try JSONDecoder().decode(ClaudeSessionBinding.self, from: JSONEncoder().encode(binding))
        #expect(try restored.accept(reading(5, withQuota: true), currentIdentity: identity)?.first?.usedFraction == 0.3)
        #expect(try restored.accept(reading(5, withQuota: true), currentIdentity: identity) == nil)
        #expect(throws: FetchError.self) { try restored.accept(reading(4, withQuota: true), currentIdentity: identity) }
        #expect(try restored.accept(reading(6), currentIdentity: identity) == nil)
    }

    @Test func lateInstallationAndAccountSwitchCannotAttributeQuota() throws {
        #expect(
            ClaudeSessionBinding(
                initial: reading(5, withQuota: true), localIdentity: identity, verifiedIdentity: identity) == nil)
        #expect(ClaudeSessionBinding(initial: reading(nil), localIdentity: identity, verifiedIdentity: identity) == nil)
        var binding = try #require(
            ClaudeSessionBinding(initial: reading(0), localIdentity: identity, verifiedIdentity: identity))
        let other = BillingIdentity(region: identity.region, account: identity.account, subject: UUID().uuidString)
        #expect(throws: FetchError.credentialMissing) {
            try binding.accept(reading(5, withQuota: true), currentIdentity: other)
        }
        let otherSession = ClaudeStatuslineReading(
            sessionID: UUID(), version: "2.1.263", apiDurationMilliseconds: 5,
            quotas: reading(5, withQuota: true).quotas)
        #expect(throws: FetchError.credentialMissing) { try binding.accept(otherSession, currentIdentity: identity) }
    }
}
