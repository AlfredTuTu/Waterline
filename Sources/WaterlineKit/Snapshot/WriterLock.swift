import Darwin
import Foundation

public enum WriterLockError: Error, Equatable {
    case busy
    case inaccessible
}

/// An OS-owned advisory lock. Closing the descriptor, including process exit, releases ownership.
final class WriterLock: Sendable {
    private let descriptor: Int32

    init(directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let path = directory.appending(path: "writer.lock").path
        let opened = Darwin.open(path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard opened >= 0 else { throw WriterLockError.inaccessible }
        guard flock(opened, LOCK_EX | LOCK_NB) == 0 else {
            let reason = errno
            Darwin.close(opened)
            throw reason == EWOULDBLOCK ? WriterLockError.busy : WriterLockError.inaccessible
        }
        descriptor = opened
    }

    deinit {
        Darwin.close(descriptor)
    }
}
