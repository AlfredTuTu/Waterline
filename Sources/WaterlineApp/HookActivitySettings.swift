import AppKit
import Observation
import SwiftUI
import WaterlineKit

@Observable
final class HookActivity: NSObject {
    static let shared = HookActivity()
    private(set) var enabled = UserDefaults.standard.bool(forKey: "waterlineClaudeHooksEnabled")
    private(set) var changing = false
    private(set) var error: String?
    private(set) var needsCleanup = false
    private var state = HookActivityState()
    private var listening = false

    func start() {
        #if WATERLINE_VERIFICATION
            enabled = false
        #else
            guard !listening else { return }
            listening = true
            needsCleanup =
                !enabled
                && (UserDefaults.standard.string(forKey: "waterlineClaudeHookCommand") != nil
                    || UserDefaults.standard.string(forKey: "waterlineClaudeHookPendingCommand") != nil)
            DistributedNotificationCenter.default().addObserver(
                self, selector: #selector(receive(_:)),
                name: Notification.Name(HookActivityEvent.notificationName), object: nil)
        #endif
    }

    @objc private func receive(_ notification: Notification) {
        guard enabled, let data = notification.userInfo?["event"] as? Data, data.count < 2048,
            let event = try? JSONDecoder().decode(HookActivityEvent.self, from: data)
        else { return }
        state.receive(event, now: Date())
    }

    func activeCount(now: Date) -> Int { enabled ? state.activeCount(now: now) : 0 }

    func setEnabled(_ value: Bool) async {
        guard !changing, !value || !needsCleanup else { return }
        changing = true
        error = nil
        defer { changing = false }
        let defaults = UserDefaults.standard
        if !value {
            enabled = false
            defaults.set(false, forKey: "waterlineClaudeHooksEnabled")
            state = HookActivityState()
        }
        let executable = Bundle.main.bundleURL.appending(path: "Contents/MacOS/waterline")
        guard !value || FileManager.default.isExecutableFile(atPath: executable.path) else {
            error = "Could not find the bundled Waterline command. Reinstall the app and try again."; return
        }
        let previousCommand = defaults.string(forKey: "waterlineClaudeHookCommand")
        let command =
            value
            ? HookConfiguration.command(executable: executable.path)
            : previousCommand ?? HookConfiguration.command(executable: executable.path)
        let pendingCommand = defaults.string(forKey: "waterlineClaudeHookPendingCommand")
        if value { defaults.set(command, forKey: "waterlineClaudeHookPendingCommand") }
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/settings.json")
        do {
            try await Task.detached {
                let store = HookSettingsStore(url: url)
                try store.setEnabled(value, command: command, replacingCommand: previousCommand)
                if !value, let pendingCommand, pendingCommand != command {
                    try store.setEnabled(false, command: pendingCommand)
                }
            }.value
            if value {
                defaults.set(command, forKey: "waterlineClaudeHookCommand")
                defaults.set(true, forKey: "waterlineClaudeHooksEnabled")
                enabled = true
            } else {
                defaults.removeObject(forKey: "waterlineClaudeHookCommand")
            }
            defaults.removeObject(forKey: "waterlineClaudeHookPendingCommand")
            needsCleanup = false
        } catch {
            self.error =
                (error as? HookActivityError) == .hooksDisabled
                ? "Claude Code has disabled hooks. Enable them there before connecting activity."
                : "Could not update Claude Code hooks. Check settings permissions and JSON, then retry."
            needsCleanup =
                !enabled
                && (defaults.string(forKey: "waterlineClaudeHookCommand") != nil
                    || defaults.string(forKey: "waterlineClaudeHookPendingCommand") != nil)
        }
    }
}

struct HookActivitySettings: View {
    private let activity = HookActivity.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "Claude Code session activity",
                isOn: Binding(get: { activity.enabled }, set: { value in Task { await activity.setEnabled(value) } })
            )
            .disabled(activity.changing || activity.needsCleanup)
            Text("Adds local hooks to Claude Code settings. Conversation content is not recorded.")
                .font(.caption).foregroundStyle(.secondary)
            if activity.changing { ProgressView("Updating…").controlSize(.small) }
            if let error = activity.error {
                Text(LocalizedStringKey(error))
                    .font(.caption).foregroundStyle(.orange)
            }
            if activity.needsCleanup {
                Button("Remove remaining hooks") { Task { await activity.setEnabled(false) } }.disabled(
                    activity.changing)
            }
        }
    }
}

struct HookActivityBanner: View {
    private let activity = HookActivity.shared
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if activity.activeCount(now: context.date) > 0 {
                Label("Claude Code: recent session activity", systemImage: "waveform")
                    .font(.caption).foregroundStyle(.orange).padding(.bottom, 8)
            }
        }
    }
}
