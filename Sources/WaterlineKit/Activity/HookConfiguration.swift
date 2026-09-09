import Foundation

public enum HookConfiguration {
    public static func command(executable: String) -> String {
        "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "' hook-claude-v1"
    }

    public static func update(_ data: Data, command: String, enabled: Bool) throws -> Data {
        guard data.count <= 1_048_576,
            var root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw HookActivityError.invalidSettings }
        if enabled, root["disableAllHooks"] as? Bool == true { throw HookActivityError.hooksDisabled }
        guard root["hooks"] == nil || root["hooks"] is [String: Any] else {
            throw HookActivityError.invalidSettings
        }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var removedOwnedCommand = false
        for event in LegacyClaudeHookEvent.allCases {
            guard hooks[event.rawValue] == nil || hooks[event.rawValue] is [[String: Any]] else {
                throw HookActivityError.invalidSettings
            }
            var entries = hooks[event.rawValue] as? [[String: Any]] ?? []
            var found = false
            var retained: [[String: Any]] = []
            for var entry in entries {
                guard let commands = entry["hooks"] as? [[String: Any]] else {
                    throw HookActivityError.invalidSettings
                }
                let contains = commands.contains {
                    $0["type"] as? String == "command" && $0["command"] as? String == command
                }
                found = found || contains
                if !enabled && contains {
                    removedOwnedCommand = true
                    let remaining = commands.filter {
                        !($0["type"] as? String == "command" && $0["command"] as? String == command)
                    }
                    if remaining.isEmpty { continue }
                    entry["hooks"] = remaining
                }
                retained.append(entry)
            }
            entries = retained
            if enabled && !found {
                entries.append(["hooks": [["type": "command", "command": command, "timeout": 2]]])
            }
            if entries.isEmpty { hooks.removeValue(forKey: event.rawValue) } else { hooks[event.rawValue] = entries }
        }
        if !enabled && !removedOwnedCommand { return data }
        if hooks.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = hooks }
        return try JSONSerialization.data(
            withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }
}
