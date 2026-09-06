import Foundation

public struct HTTPRequest: Sendable {
    public var url: URL
    public var method: String
    public var headers: [String: String]
    public var body: Data?

    public init(url: URL, method: String = "GET", headers: [String: String] = [:], body: Data? = nil) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public let status: Int
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, headers: [String: String], body: Data) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

public protocol HTTPClient: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct HostNotAllowed: Error, Equatable {
    public let host: String
}

/// The single choke point for outbound requests: a secret can only travel to a host on the allowlist.
public struct URLSessionHTTPClient: HTTPClient {
    public let allowedHosts: Set<String>
    private let session: URLSession

    public init(allowedHosts: Set<String>, session: URLSession = .shared) {
        self.allowedHosts = allowedHosts
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let host = request.url.host() ?? ""
        guard allowedHosts.contains(host) else { throw HostNotAllowed(host: host) }
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await session.data(for: urlRequest)
        let http = response as! HTTPURLResponse
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            result[String(describing: pair.key).lowercased()] = String(describing: pair.value)
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}
