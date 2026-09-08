import Foundation
import Observation
import SwiftUI
import WaterlineKit

/// Upgrade-only cleanup for the retired activity feature. No session listener is installed.
@Observable
final class LegacyIntegrationCleanup {
    static let shared = LegacyIntegrationCleanup()
    private(set) var changing = false
    private(set) var message: String?

    func run() async {
        guard !changing else { return }
        let defaults = UserDefaults.standard
        let keys = ["waterlineClaudeHookCommand", "waterlineClaudeHookPendingCommand"]
        let wasEnabled = defaults.bool(forKey: "waterlineClaudeHooksEnabled")
        var commands = Set(keys.compactMap { defaults.string(forKey: $0) })
        commands.formUnion(defaults.stringArray(forKey: "waterlineRetiredHookCommands") ?? [])
        defaults.set(false, forKey: "waterlineClaudeHooksEnabled")
        guard wasEnabled || !commands.isEmpty else { return }
        commands.insert(
            HookConfiguration.command(
                executable: Bundle.main.bundleURL.appending(path: "Contents/MacOS/waterline").path))
        defaults.set(Array(commands), forKey: "waterlineRetiredHookCommands")
        changing = true
        defer { changing = false }
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
        do {
            let owned = commands
            try await Task.detached {
                let store = HookSettingsStore(url: url)
                for command in owned { try store.setEnabled(false, command: command) }
            }.value
            for key in keys + ["waterlineClaudeHooksEnabled", "waterlineRetiredHookCommands"] {
                defaults.removeObject(forKey: key)
            }
            message = nil
        } catch {
            message = "Could not remove old Waterline hooks. Retry cleanup."
        }
    }
}

struct LegacyIntegrationCleanupView: View {
    private let cleanup = LegacyIntegrationCleanup.shared
    var body: some View {
        if let message = cleanup.message {
            Text(LocalizedStringKey(message)).font(.caption).foregroundStyle(.orange)
            Button("Retry cleanup") { Task { await cleanup.run() } }.disabled(cleanup.changing)
        }
    }
}
