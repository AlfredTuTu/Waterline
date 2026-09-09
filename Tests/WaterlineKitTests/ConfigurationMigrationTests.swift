import Foundation
import Testing

@testable import WaterlineKit

struct ConfigurationMigrationTests {
    @Test func automaticMonitoringPreservesAccountAndSourceChoices() throws {
        let selected = AccountID(rawValue: "saved-selection")
        let prior = UserPreferences(
            refreshInterval: 300, balanceThresholds: ["USD": 10], disabledProviders: [.xai],
            enabledCredentialSources: [.antigravityCLI], notchAccountIDs: [selected], accountOrder: [selected])
        let restored = try JSONDecoder().decode(UserPreferences.self, from: JSONEncoder().encode(prior))
        let automatic = restored.forAutomaticMonitoring()
        try automatic.validate()
        #expect(automatic.refreshInterval == 60)
        #expect(automatic.balanceThresholds.isEmpty)
        #expect(automatic.notchAccountIDs == prior.notchAccountIDs)
        #expect(automatic.accountOrder == prior.accountOrder)
        #expect(automatic.disabledProviders == prior.disabledProviders)
        #expect(automatic.enabledCredentialSources == prior.enabledCredentialSources)
        #expect(automatic.forAutomaticMonitoring() == automatic)
    }

    @Test func legacyUpgradePreservesExactBytesAndCreatesOnlyOnePrivateBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "configuration-upgrade-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigurationStore(url: directory.appending(path: "configuration.json"))
        var old = Configuration()
        old.schemaVersion = 1
        old.preferences.refreshInterval = 600
        try store.save(old)
        let original = try Data(contentsOf: store.url)
        var upgraded = try #require(try store.load())
        upgraded.schemaVersion = 2
        upgraded.preferences.enabledCredentialSources = [.antigravityCLI]
        try store.save(upgraded)
        try store.save(upgraded)
        let backups = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("configuration-legacy-") }
        #expect(backups.count == 1)
        let backup = try #require(backups.first)
        #expect(try Data(contentsOf: backup) == original)
        let attributes = try FileManager.default.attributesOfItem(atPath: backup.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(try store.load()?.preferences.refreshInterval == 600)
        #expect(try store.load()?.preferences.enabledCredentialSources == [.antigravityCLI])
    }

    @Test(arguments: ["future", "corrupt"])
    func unreadableExistingConfigurationIsNeverReplaced(kind: String) throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "configuration-preserve-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = ConfigurationStore(url: directory.appending(path: "configuration.json"))
        var future = Configuration()
        future.schemaVersion = 999
        let original = kind == "future" ? try SnapshotStore.encoder.encode(future) : Data("{unfinished".utf8)
        try original.write(to: store.url)
        #expect(throws: (any Error).self) { try store.save(Configuration()) }
        #expect(try Data(contentsOf: store.url) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["configuration.json"])
    }
}
