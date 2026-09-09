import Darwin
import Foundation
import Testing

@testable import WaterlineKit

struct LocalServiceListenerTests {
    @Test(arguments: ["127.0.0.1", "0.0.0.0"])
    func onlyOwnedLoopbackListenersAreAccepted(address: String) throws {
        var fd = socket(AF_INET, SOCK_STREAM, 0)
        #expect(fd >= 0)
        defer { if fd >= 0 { close(fd) } }
        var endpoint = sockaddr_in()
        endpoint.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        endpoint.sin_family = sa_family_t(AF_INET)
        endpoint.sin_addr.s_addr = inet_addr(address)
        let bound = withUnsafePointer(to: &endpoint) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        #expect(bound == 0)
        #expect(listen(fd, 1) == 0)
        let process = try #require(LocalProcessIdentity.read(getpid()))
        let found = process.loopbackListeners().first { $0.descriptor == fd }
        if address == "127.0.0.1" {
            let listener = try #require(found)
            #expect(listener.port > 0)
            #expect(listener.isCurrent())
            let differentSocket = LocalServiceListener(
                process: listener.process, descriptor: listener.descriptor, port: listener.port,
                socketGeneration: listener.socketGeneration &+ 1, socketIdentity: listener.socketIdentity)
            #expect(!differentSocket.isCurrent())
            close(fd)
            fd = -1
            #expect(!listener.isCurrent())
        } else {
            #expect(found == nil)
        }
    }
}
