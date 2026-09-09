import Foundation

public enum ClaudeStatuslineSetupResult: Sendable, Equatable { case installed, alreadyInstalled, occupied, disabled }

public enum ClaudeStatuslineSetup {
    public static func install(settingsURL: URL, executable: URL) throws -> ClaudeStatuslineSetupResult {
        let files = RealFileSystem()
        let original = files.exists(settingsURL) ? try files.contents(of: settingsURL, maximumBytes: 4_194_304) : nil
        var settings: [String: Any] = [:]
        if let original {
            guard let decoded = try JSONSerialization.jsonObject(with: original) as? [String: Any] else {
                throw FetchError.schemaChanged(detail: "claude.settings")
            }
            settings = decoded
        }
        if settings["disableAllHooks"] as? Bool == true { return .disabled }
        let quoted = "'" + executable.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let command = quoted + " claude-statusline-v1"
        if let existing = settings["statusLine"] {
            if let object = existing as? [String: Any], object["type"] as? String == "command",
                object["command"] as? String == command
            {
                return .alreadyInstalled
            }
            return .occupied
        }
        settings["statusLine"] = ["type": "command", "command": command]
        let parent = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parent, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let current = files.exists(settingsURL) ? try files.contents(of: settingsURL, maximumBytes: 4_194_304) : nil
        guard current == original else { throw FetchError.transport(detail: "Claude settings changed during setup") }
        if let original {
            let backup = parent.appending(path: "settings-waterline-backup-\(UUID()).json")
            try original.write(to: backup, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: backup.path)
        }
        try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            .write(to: settingsURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
        return .installed
    }
}
