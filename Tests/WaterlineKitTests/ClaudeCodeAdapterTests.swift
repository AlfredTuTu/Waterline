import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeCodeAdapterTests {
    @Test func windowsVaryByAccountAndKeepReportedZero() throws {
        let usage = try ClaudeCodeAdapter.parse(
            Data(
                #"{"five_hour":{"utilization":0,"resets_at":"2026-09-07T01:00:00Z"},"seven_day":{"utilization":64},"seven_day_sonnet":{"utilization":12},"extra_field":true}"#
                    .utf8), plan: "pro")
        #expect(usage.quotaWindows.count == 3)
        #expect(usage.quotaWindows[0].usedFraction == 0)
        #expect(usage.quotaWindows[1].resetsAt == nil)
        #expect(Dashboard.overviewWindows(usage).map(\.label) == ["7d", "5h"])
        #expect(usage.planLabel == "pro")
    }

    @Test func malformedWindowDoesNotEraseHealthyWindow() throws {
        let usage = try ClaudeCodeAdapter.parse(
            Data(#"{"five_hour":{"utilization":"bad"},"seven_day":{"utilization":40}}"#.utf8))
        #expect(usage.quotaWindows.count == 1)
        #expect(usage.componentFailures.first?.error == .schemaChanged(detail: "five_hour.utilization"))
    }

    @Test func absentFractionIsNotZero() throws {
        let usage = try ClaudeCodeAdapter.parse(Data(#"{"five_hour":{"resets_at":"2026-09-07T01:00:00.000Z"}}"#.utf8))
        #expect(usage.quotaWindows.first?.usedFraction == nil)
        #expect(usage.quotaWindows.first?.resetsAt != nil)
    }

    @Test func lockedKeychainReturnsAConnectableSourceWithoutHTTP() async throws {
        let environment = DiscoveryEnvironment(
            home: URL(fileURLWithPath: "/synthetic"), processEnvironment: [:],
            fileSystem: EmptyFiles(), keychain: LockedKeychain(), allowsUserInteraction: false)
        let discovered = try await ClaudeCodeAdapter().discover(in: environment, http: UnusedHTTP())
        #expect(discovered.count == 1)
        #expect(discovered[0].secret == nil)
        #expect(discovered[0].connectionError == .keychainLocked)
    }

    @Test func profileIdentitySeparatesOrganisationAndPerson() throws {
        let identity = try ClaudeCodeAdapter.parseIdentity(
            Data(
                #"{"account":{"uuid":"00000000-0000-4000-8000-000000000001"},"organization":{"uuid":"00000000-0000-4000-8000-000000000002"}}"#
                    .utf8))
        #expect(identity.region == "api.anthropic.com")
        #expect(identity.account != identity.subject)
    }
}

private struct LockedKeychain: KeychainReading {
    func items(service: String) throws -> [KeychainItem] { [KeychainItem(service: service, account: "synthetic")] }
    func secret(for item: KeychainItem, allowsUserInteraction: Bool) throws -> Secret {
        #expect(!allowsUserInteraction)
        throw FetchError.keychainLocked
    }
}
