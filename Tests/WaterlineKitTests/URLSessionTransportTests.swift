import Foundation
import Testing

@testable import WaterlineKit

struct URLSessionTransportTests {
    @Test func actualSessionReturnsStatusBodyAndNormalizedHeaders() async throws {
        let client = URLSessionHTTPClient(allowedHosts: ["allowed.example"], protocolClasses: [TransportProbe.self])
        let response = try await client.send(
            HTTPRequest(
                url: URL(string: "https://allowed.example/ok")!,
                method: "POST", headers: ["Authorization": "Bearer synthetic-transport"], body: Data("{}".utf8)))
        #expect(response.status == 200)
        #expect(response.headers["x-test"] == "observed")
        #expect(response.body == Data("response".utf8))
    }

    @Test(arguments: ["allowed.example", "blocked.example"])
    func redirectedRequestIsNeverIssued(destination: String) async {
        let token = UUID().uuidString
        let url = URL(string: "https://allowed.example/redirect?target=\(destination)&id=\(token)")!
        let client = URLSessionHTTPClient(allowedHosts: ["allowed.example"], protocolClasses: [TransportProbe.self])
        await #expect(throws: HTTPBoundaryError.redirectRejected) {
            try await client.send(HTTPRequest(url: url, headers: ["Authorization": "Bearer synthetic-secret"]))
        }
        let requests = TransportProbe.log.takeRequests(id: token)
        #expect(requests.count == 1)
        #expect(requests.first?.url?.host == "allowed.example")
    }

    @Test func responseCookiesAreNotReplayed() async throws {
        let token = UUID().uuidString
        let client = URLSessionHTTPClient(allowedHosts: ["allowed.example"], protocolClasses: [TransportProbe.self])
        _ = try await client.send(HTTPRequest(url: URL(string: "https://allowed.example/cookie?id=\(token)")!))
        _ = try await client.send(HTTPRequest(url: URL(string: "https://allowed.example/ok?id=\(token)")!))
        let requests = TransportProbe.log.takeRequests(id: token)
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Cookie") == nil })
    }

    @Test func nonHTTPResponseIsRejected() async {
        let client = URLSessionHTTPClient(allowedHosts: ["allowed.example"], protocolClasses: [TransportProbe.self])
        await #expect(throws: HTTPBoundaryError.invalidResponse) {
            try await client.send(HTTPRequest(url: URL(string: "https://allowed.example/non-http")!))
        }
    }
}

private final class TransportProbe: URLProtocol, @unchecked Sendable {
    static let log = RequestLog()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.log.append(request)
        let url = request.url!
        if url.path == "/redirect" {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            let host = components.queryItems!.first { $0.name == "target" }!.value!
            let target = URL(string: "https://\(host)/target?" + (components.percentEncodedQuery ?? ""))!
            let response = HTTPURLResponse(
                url: url, statusCode: 302, httpVersion: "HTTP/1.1",
                headerFields: ["Location": target.absoluteString])!
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        } else if url.path == "/non-http" {
            client?.urlProtocol(
                self,
                didReceive: URLResponse(
                    url: url, mimeType: nil, expectedContentLength: 0,
                    textEncodingName: nil), cacheStoragePolicy: .notAllowed)
        } else {
            let response = HTTPURLResponse(
                url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                headerFields: ["X-Test": "observed", "Set-Cookie": "synthetic-cookie=one; Secure; Path=/"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
            client?.urlProtocol(self, didLoad: Data("response".utf8))
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func append(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        requests.append(request)
    }
    func takeRequests(id: String) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        let matches = requests.filter { $0.url?.query?.contains(id) == true }
        requests.removeAll { $0.url?.query?.contains(id) == true }
        return matches
    }
}
