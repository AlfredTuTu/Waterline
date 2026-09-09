import Foundation
import Testing

@testable import WaterlineKit

struct HookActivityTests {
    @Test func retiringUnownedHooksPreservesExactFileBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "hook-retirement-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "settings.json")
        let original = Data("{ \"hooks\": {}, \"userSetting\": true }\n".utf8)
        try original.write(to: url)
        try HookSettingsStore(url: url).setEnabled(false, command: "not-owned-here")
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func configurationRoundTripPreservesOtherHooksAndSettings() throws {
        let original: [String: Any] = [
            "env": ["EXAMPLE_KEY": "synthetic-value"],
            "hooks": [
                "Stop": [["hooks": [["type": "command", "command": "existing-command"]]]],
                "Notification": [["hooks": [["type": "command", "command": "unrelated"]]]],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: original)
        let command = HookConfiguration.command(
            executable: "/Applications/Waterline's App.app/Contents/MacOS/waterline")
        #expect(command.contains("'\\''"))
        let installed = try HookConfiguration.update(data, command: command, enabled: true)
        #expect(try HookConfiguration.update(installed, command: command, enabled: true) == installed)
        let removed = try HookConfiguration.update(installed, command: command, enabled: false)
        #expect(
            try NSDictionary(dictionary: original).isEqual(
                to: JSONSerialization.jsonObject(with: removed) as! [String: Any]))
        #expect(throws: HookActivityError.self) {
            try HookConfiguration.update(Data(#"{"disableAllHooks":true}"#.utf8), command: command, enabled: true)
        }
    }

    @Test func storeWritesPrivatelyAndRejectsSymlinksWithoutChangingTargets() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "hook-store-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = directory.appending(path: "settings.json")
        let store = HookSettingsStore(url: settings)
        try store.setEnabled(true, command: "synthetic-command")
        #expect(
            (try FileManager.default.attributesOfItem(atPath: settings.path)[.posixPermissions] as? NSNumber)?.intValue
                == 0o600)
        try store.setEnabled(false, command: "synthetic-command")
        #expect(try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: String] == [:])
        let target = directory.appending(path: "original.json")
        try Data("{}".utf8).write(to: target)
        try FileManager.default.removeItem(at: settings)
        try FileManager.default.createSymbolicLink(at: settings, withDestinationURL: target)
        #expect(throws: HookActivityError.self) { try store.setEnabled(true, command: "synthetic-command") }
        #expect(try Data(contentsOf: target) == Data("{}".utf8))
        try FileManager.default.removeItem(at: target)
        #expect(throws: HookActivityError.self) { try store.setEnabled(true, command: "synthetic-command") }
    }
}
