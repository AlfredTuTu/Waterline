import Foundation
import Testing

@testable import WaterlineKit

struct ClaudeStatuslineSetupTests {
    @Test func setupPreservesSettingsBacksUpOnceAndDoesNotReplaceUserCommand() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let settings = root.appending(path: "settings.json")
        let executable = URL(fileURLWithPath: "/synthetic/Owner's App/waterline")
        let original = Data(#"{"permissions":{"defaultMode":"plan"},"env":{"UNCHANGED":"synthetic"}}"#.utf8)
        try original.write(to: settings)
        #expect(try ClaudeStatuslineSetup.install(settingsURL: settings, executable: executable) == .installed)
        let installed = try Data(contentsOf: settings)
        let decoded = try #require(JSONSerialization.jsonObject(with: installed) as? [String: Any])
        #expect((decoded["env"] as? [String: String])?["UNCHANGED"] == "synthetic")
        #expect(
            (decoded["statusLine"] as? [String: String])?["command"]
                == "'/synthetic/Owner'\\''s App/waterline' claude-statusline-v1")
        #expect(try ClaudeStatuslineSetup.install(settingsURL: settings, executable: executable) == .alreadyInstalled)
        #expect(try Data(contentsOf: settings) == installed)
        let backups = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("settings-waterline-backup-") }
        #expect(backups.count == 1)
        #expect(try Data(contentsOf: #require(backups.first)) == original)
        let custom = Data(#"{"statusLine":{"type":"command","command":"my-existing-statusline"}}"#.utf8)
        try custom.write(to: settings)
        #expect(try ClaudeStatuslineSetup.install(settingsURL: settings, executable: executable) == .occupied)
        #expect(try Data(contentsOf: settings) == custom)
        try Data(#"{"disableAllHooks":true}"#.utf8).write(to: settings)
        #expect(try ClaudeStatuslineSetup.install(settingsURL: settings, executable: executable) == .disabled)
    }
}
