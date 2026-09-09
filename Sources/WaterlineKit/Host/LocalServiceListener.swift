import Darwin
import Foundation

/// A specific listening socket, tied to both process lifetime and socket generation.
public struct LocalServiceListener: Equatable, Sendable {
    public let process: LocalProcessIdentity
    public let descriptor: Int32
    public let port: UInt16
    let socketGeneration: UInt64
    let socketIdentity: UInt64

    public func isCurrent() -> Bool {
        guard process.isCurrent(expectedExecutable: URL(fileURLWithPath: process.executable), userID: getuid()) else {
            return false
        }
        return Self.read(process: process, descriptor: descriptor) == self
    }

    static func read(process: LocalProcessIdentity, descriptor: Int32) -> LocalServiceListener? {
        var socket = socket_fdinfo()
        let size = MemoryLayout<socket_fdinfo>.size
        guard proc_pidfdinfo(process.pid, descriptor, PROC_PIDFDSOCKETINFO, &socket, Int32(size)) == size,
            socket.psi.soi_family == AF_INET, socket.psi.soi_kind == SOCKINFO_TCP,
            socket.psi.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN
        else { return nil }
        let info = socket.psi.soi_proto.pri_tcp.tcpsi_ini
        guard info.insi_laddr.ina_46.i46a_addr4.s_addr == inet_addr("127.0.0.1") else { return nil }
        let port = UInt16(bigEndian: UInt16(truncatingIfNeeded: info.insi_lport))
        guard port > 0 else { return nil }
        return LocalServiceListener(
            process: process, descriptor: descriptor, port: port,
            socketGeneration: info.insi_gencnt, socketIdentity: socket.psi.soi_so)
    }
}

extension LocalProcessIdentity {
    public func loopbackListeners() -> [LocalServiceListener] {
        guard isCurrent(expectedExecutable: URL(fileURLWithPath: executable), userID: getuid()) else { return [] }
        let bytes = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bytes > 0, bytes <= 4_194_304 else { return [] }
        let stride = MemoryLayout<proc_fdinfo>.stride
        var descriptors = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(bytes) / stride + 16)
        let count = descriptors.withUnsafeMutableBytes {
            proc_pidinfo(pid, PROC_PIDLISTFDS, 0, $0.baseAddress, Int32($0.count))
        }
        guard count > 0, Int(count) <= descriptors.count * stride else { return [] }
        let listeners = descriptors.prefix(Int(count) / stride).compactMap { entry -> LocalServiceListener? in
            guard entry.proc_fdtype == PROX_FDTYPE_SOCKET else { return nil }
            return LocalServiceListener.read(process: self, descriptor: entry.proc_fd)
        }
        guard isCurrent(expectedExecutable: URL(fileURLWithPath: executable), userID: getuid()) else { return [] }
        return listeners
    }
}
