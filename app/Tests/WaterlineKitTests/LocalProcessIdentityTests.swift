import Darwin
import Foundation
import Testing

@testable import WaterlineKit

struct LocalProcessIdentityTests {
    @Test func currentProcessIdentityChecksOwnerExecutableAndStartTime() throws {
        let identity = try #require(LocalProcessIdentity.read(getpid()))
        let path = URL(fileURLWithPath: identity.executable)
        #expect(!identity.isAntigravityCLI(expectedExecutable: path))
        #expect(identity.isCurrent(expectedExecutable: path, userID: getuid()))
        #expect(!identity.isCurrent(expectedExecutable: path, userID: getuid() &+ 1))
        #expect(!identity.isCurrent(expectedExecutable: URL(fileURLWithPath: "/not-the-cli"), userID: getuid()))
        let reused = LocalProcessIdentity(
            pid: identity.pid, userID: identity.userID, executable: identity.executable,
            startedSeconds: identity.startedSeconds &+ 1, startedMicroseconds: identity.startedMicroseconds)
        #expect(!reused.isCurrent(expectedExecutable: path, userID: getuid()))
    }

    @Test func invalidProcessIdentifiersAreRejected() {
        #expect(LocalProcessIdentity.read(0) == nil)
        #expect(LocalProcessIdentity.read(-1) == nil)
        #expect(LocalProcessIdentity.read(Int32.max) == nil)
    }
}
