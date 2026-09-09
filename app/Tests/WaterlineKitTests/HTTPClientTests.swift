import Foundation
import Testing

@testable import WaterlineKit

@Suite struct HTTPClientTests {
    @Test(arguments: [
        "http://api.deepseek.com/user/balance",
        "https://api.deepseek.com:444/user/balance",
        "https://user:password@api.deepseek.com/user/balance",
    ])
    func insecureRequestsNeverLeaveProcess(_ url: String) async {
        let client = URLSessionHTTPClient(allowedHosts: ["api.deepseek.com"])
        await #expect(throws: HTTPBoundaryError.insecureURL) {
            try await client.send(HTTPRequest(url: URL(string: url)!))
        }
    }

    @Test func `a request to a host outside the allowlist never leaves the process`() async {
        let client = URLSessionHTTPClient(allowedHosts: ["api.deepseek.com"])
        await #expect(throws: HostNotAllowed(host: "api.deepseek.com.evil.example")) {
            try await client.send(HTTPRequest(url: URL(string: "https://api.deepseek.com.evil.example/user/balance")!))
        }
    }
}
