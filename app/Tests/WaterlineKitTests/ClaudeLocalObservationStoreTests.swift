import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeLocalObservationStoreTests {
    @Test func sessionStorageIsBoundedAndKeepsUnrelatedFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unrelated = directory.appending(path: "notes.json")
        try Data("keep".utf8).write(to: unrelated)
        let store = ClaudeLocalObservationStore(directory: directory)
        let identity = BillingIdentity(
            region: "api.anthropic.com", account: UUID().uuidString, subject: UUID().uuidString)
        for _ in 0..<130 {
            let reading = ClaudeStatuslineReading(
                sessionID: UUID(), version: "2.1.263", apiDurationMilliseconds: 0, quotas: [])
            try store.capture(reading, localIdentity: identity, verifiedIdentity: identity, receivedAt: Date())
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        #expect(files.filter { UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }.count == 128)
        #expect(try String(contentsOf: unrelated, encoding: .utf8) == "keep")
        #expect(try store.latest(matching: identity) == nil)
    }

    @Test func repeatedValuesKeepOriginalReceiptAcrossRestart() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = UUID()
        let identity = BillingIdentity(
            region: "api.anthropic.com", account: UUID().uuidString, subject: UUID().uuidString)
        let now = Date(timeIntervalSince1970: 1800000000)
        func reading(_ duration: Double, fraction: Double? = nil) -> ClaudeStatuslineReading {
            ClaudeStatuslineReading(
                sessionID: session, version: "2.1.263", apiDurationMilliseconds: duration,
                quotas: fraction.map {
                    [ClaudeStatuslineQuota(id: "five_hour", usedFraction: $0, resetsAt: now.addingTimeInterval(3600))]
                } ?? [])
        }
        let store = ClaudeLocalObservationStore(directory: directory)
        #expect(
            try store.capture(reading(0), localIdentity: identity, verifiedIdentity: identity, receivedAt: now) == nil)
        let first = try #require(
            try store.capture(
                reading(10, fraction: 0.3), localIdentity: identity,
                verifiedIdentity: identity, receivedAt: now))
        let restored = ClaudeLocalObservationStore(directory: directory)
        let repeated = try restored.capture(
            reading(20, fraction: 0.3), localIdentity: identity,
            verifiedIdentity: identity, receivedAt: now.addingTimeInterval(60))
        #expect(repeated == first)
        let missing = try restored.capture(
            reading(30), localIdentity: identity,
            verifiedIdentity: identity, receivedAt: now.addingTimeInterval(120))
        #expect(missing == first)
        let changed = try #require(
            try restored.capture(
                reading(40, fraction: 0.4), localIdentity: identity,
                verifiedIdentity: identity, receivedAt: now.addingTimeInterval(180)))
        #expect(changed.receivedAt == now.addingTimeInterval(180))
        #expect(try restored.observation(sessionID: session, matching: identity) == changed)
        let other = BillingIdentity(region: identity.region, account: UUID().uuidString, subject: identity.subject)
        #expect(try restored.observation(sessionID: session, matching: other) == nil)
        #expect(throws: FetchError.credentialMissing) {
            try restored.capture(
                reading(50, fraction: 0.5), localIdentity: other, verifiedIdentity: other, receivedAt: now)
        }
        let attributes = try FileManager.default.attributesOfItem(
            atPath: directory.appending(path: session.uuidString + ".json").path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }
}
