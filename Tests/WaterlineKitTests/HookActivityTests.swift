import Foundation
import Testing

@testable import WaterlineKit

struct HookActivityTests {
    private func event(_ kind: String, session: String = "synthetic-session", at date: Date) throws -> HookActivityEvent
    {
        let data = try JSONSerialization.data(withJSONObject: [
            "session_id": session, "hook_event_name": kind,
            "prompt": "PRIVATE SYNTHETIC PROMPT", "transcript_path": "/synthetic/private/path",
            "last_assistant_message": "PRIVATE SYNTHETIC RESPONSE",
        ])
        return try HookActivityEvent.parse(data, now: date)
    }

    @Test func transportEventContainsNoConversationOrRawSession() throws {
        let event = try event("UserPromptSubmit", at: Date())
        let encoded = String(decoding: try JSONEncoder().encode(event), as: UTF8.self)
        for excluded in ["PRIVATE", "synthetic-session", "/synthetic", "prompt", "transcript"] {
            #expect(!encoded.contains(excluded))
        }
        #expect(event.session.count == 64)
        #expect(throws: HookActivityError.self) {
            try HookActivityEvent.parse(Data(repeating: 32, count: 1_048_577), now: Date())
        }
        #expect(throws: HookActivityError.self) { try self.event("Unsupported", at: Date()) }
    }

    @Test func overlappingSessionsEndIndependentlyAndExpire() throws {
        let now = Date()
        var state = HookActivityState()
        let first = try event("UserPromptSubmit", at: now)
        state.receive(first, now: now)
        state.receive(first, now: now)
        state.receive(try event("UserPromptSubmit", session: "second", at: now), now: now)
        #expect(state.activeCount(now: now) == 2)
        state.receive(try event("Stop", at: now.addingTimeInterval(1)), now: now.addingTimeInterval(1))
        state.receive(first, now: now.addingTimeInterval(2))
        #expect(state.activeCount(now: now.addingTimeInterval(2)) == 1)
        #expect(state.activeCount(now: now.addingTimeInterval(600)) == 0)
        state.receive(try event("UserPromptSubmit", at: now.addingTimeInterval(1000)), now: now)
        #expect(state.activeCount(now: now.addingTimeInterval(600)) == 0)
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
