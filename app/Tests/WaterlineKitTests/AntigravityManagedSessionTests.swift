import Foundation
import Testing

@testable import WaterlineKit

struct AntigravityManagedSessionTests {
    @Test func emptyInputSessionStartsAndStops() async throws {
        let session = try AntigravityManagedSession(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", #"printf '{"event":"init"}\n'; cat >/dev/null"#],
            directory: FileManager.default.temporaryDirectory)
        defer { session.stop() }
        for _ in 0..<100 {
            if session.isReady { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(session.isReady)
        session.stop()
        session.stop()
        for _ in 0..<100 {
            if !session.isRunning { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!session.isRunning)
    }

    @Test func missingExecutableFailsWithoutStarting() {
        #expect(throws: (any Error).self) {
            try AntigravityManagedSession(
                executable: URL(fileURLWithPath: "/nonexistent/waterline-agy"), arguments: [],
                directory: FileManager.default.temporaryDirectory)
        }
    }
}
