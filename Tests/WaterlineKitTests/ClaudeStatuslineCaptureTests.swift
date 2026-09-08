import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeStatuslineCaptureTests {
    @Test func commandReadsLocalIdentityAndWritesOnlyQuotaData() throws {
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let session = UUID()
        let user = UUID().uuidString, organization = UUID().uuidString
        let identity = BillingIdentity(region: "api.anthropic.com", account: organization, subject: user)
        let account = Account(provider: .claudeCode, credential: .file(path: "/synthetic/login"), identity: identity)
        let root = home.appending(path: "Library/Application Support/Waterline")
        try SnapshotStore(url: root.appending(path: "snapshot.json")).save(
            Snapshot(generatedAt: Date(), accounts: [AccountEntry(account: account, state: .pending)]))
        let login = try JSONSerialization.data(withJSONObject: [
            "oauthAccount": [
                "accountUuid": user, "organizationUuid": organization, "emailAddress": "do-not-store@example.invalid",
            ]
        ])
        try login.write(to: home.appending(path: ".claude.json"))
        func input(_ duration: Int, quota: Bool) throws -> Data {
            var object: [String: Any] = [
                "session_id": session.uuidString, "version": "2.1.263", "cost": ["total_api_duration_ms": duration],
                "transcript_path": "/do-not-store/transcript", "workspace": ["current_dir": "/do-not-store/workspace"],
            ]
            if quota { object["rate_limits"] = ["five_hour": ["used_percentage": 30, "resets_at": 1800000000]] }
            return try JSONSerialization.data(withJSONObject: object)
        }
        try ClaudeStatuslineCapture.run(input: input(0, quota: false), home: home, environment: [:])
        try ClaudeStatuslineCapture.run(input: input(1, quota: true), home: home, environment: [:])
        let store = ClaudeLocalObservationStore(directory: root.appending(path: "claude-local-observations"))
        #expect(try store.observation(sessionID: session, matching: identity)?.quotas.first?.usedFraction == 0.3)
        let written = try String(
            contentsOf: store.directory.appending(path: session.uuidString + ".json"), encoding: .utf8)
        #expect(!written.contains("do-not-store"))
        #expect(throws: FetchError.credentialMissing) {
            try ClaudeStatuslineCapture.run(
                input: input(2, quota: true), home: home, environment: ["CLAUDE_CONFIG_DIR": "/other-profile"])
        }
        #expect(throws: FetchError.credentialMissing) {
            try ClaudeStatuslineCapture.capture(
                input: input(2, quota: true), login: login, accounts: [account, account], directory: store.directory,
                now: Date())
        }
    }
}
