import Darwin
import Foundation

/// Kernel identity for a local status service; a PID alone can be reused after exit.
public struct LocalProcessIdentity: Equatable, Sendable {
    public let pid: Int32
    public let userID: UInt32
    public let executable: String
    public let startedSeconds: UInt64
    public let startedMicroseconds: UInt64

    public static func read(_ pid: Int32) -> LocalProcessIdentity? {
        guard pid > 0 else { return nil }
        var info = proc_bsdinfo()
        let count = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size))
        guard count == MemoryLayout<proc_bsdinfo>.size else { return nil }
        var path = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &path, UInt32(path.count))
        guard length > 0 else { return nil }
        let bytes = path.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        guard let executable = String(bytes: bytes, encoding: .utf8), !executable.isEmpty else { return nil }
        return LocalProcessIdentity(
            pid: pid, userID: info.pbi_uid, executable: executable,
            startedSeconds: info.pbi_start_tvsec, startedMicroseconds: info.pbi_start_tvusec)
    }

    public func isCurrent(expectedExecutable: URL, userID: UInt32) -> Bool {
        guard self.userID == userID,
            executable == expectedExecutable.resolvingSymlinksInPath().path
        else { return false }
        return Self.read(pid) == self
    }
}

extension LocalProcessIdentity {
    static func ownedProcesses(executable: URL) -> [LocalProcessIdentity] {
        let size = proc_listpids(UInt32(PROC_UID_ONLY), getuid(), nil, 0)
        guard size > 0, size <= 1_048_576 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(size) / MemoryLayout<pid_t>.stride + 16)
        let bytes = pids.withUnsafeMutableBytes {
            proc_listpids(UInt32(PROC_UID_ONLY), getuid(), $0.baseAddress, Int32($0.count))
        }
        guard bytes > 0, Int(bytes) <= pids.count * MemoryLayout<pid_t>.stride else { return [] }
        return pids.prefix(Int(bytes) / MemoryLayout<pid_t>.stride).compactMap(Self.read)
            .filter { $0.isAntigravityCLI(expectedExecutable: executable) }.sorted { $0.pid < $1.pid }
    }
}
