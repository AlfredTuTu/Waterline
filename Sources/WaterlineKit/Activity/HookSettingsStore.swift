import Darwin
import Foundation

public struct HookSettingsStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func setEnabled(_ enabled: Bool, command: String, replacingCommand: String? = nil) throws {
        let files = FileManager.default
        let parent = url.deletingLastPathComponent()
        if !files.fileExists(atPath: parent.path) {
            guard enabled else { return }
            try files.createDirectory(
                at: parent, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        }
        let parentAttributes = try files.attributesOfItem(atPath: parent.path)
        guard parentAttributes[.type] as? FileAttributeType == .typeDirectory,
            (parentAttributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid()
        else { throw HookActivityError.invalidSettings }
        var metadata = stat()
        let result = lstat(url.path, &metadata)
        guard result == 0 || errno == ENOENT else { throw HookActivityError.invalidSettings }
        let exists = result == 0
        guard enabled || exists else { return }
        if exists {
            let attributes = try files.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular,
                (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
                (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 1_048_576
            else { throw HookActivityError.invalidSettings }
        }
        let original = exists ? try Data(contentsOf: url) : Data("{}".utf8)
        let base: Data
        if enabled, let replacingCommand, replacingCommand != command {
            base = try HookConfiguration.update(original, command: replacingCommand, enabled: false)
        } else {
            base = original
        }
        let updated = try HookConfiguration.update(base, command: command, enabled: enabled)
        let temporary = parent.appending(path: ".waterline-hooks-\(UUID()).tmp")
        let descriptor = Darwin.open(temporary.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw HookActivityError.invalidSettings }
        defer { Darwin.close(descriptor); Darwin.unlink(temporary.path) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: false)
        try handle.write(contentsOf: updated)
        try handle.synchronize()
        // Preserve an external edit observed while preparing the replacement.
        guard files.fileExists(atPath: url.path) == exists else { throw HookActivityError.invalidSettings }
        if exists, try Data(contentsOf: url) != original { throw HookActivityError.invalidSettings }
        guard Darwin.rename(temporary.path, url.path) == 0 else { throw HookActivityError.invalidSettings }
    }
}
