import Foundation
import Testing

@testable import WaterlineKit

@Suite struct HTTPClientTests {
    @Test func `a request to a host outside the allowlist never leaves the process`() async {
        let client = URLSessionHTTPClient(allowedHosts: ["api.deepseek.com"])
        await #expect(throws: HostNotAllowed(host: "api.deepseek.com.evil.example")) {
            try await client.send(HTTPRequest(url: URL(string: "https://api.deepseek.com.evil.example/user/balance")!))
        }
    }
}
