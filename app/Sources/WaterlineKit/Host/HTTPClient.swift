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
    func withRequestPermit<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T
}

extension HTTPClient {
    public func withRequestPermit<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T
    {
        try await operation()
    }
}

public struct HostNotAllowed: Error, Equatable {
    public let host: String
}

/// The single choke point for outbound requests: a secret can only travel to a host on the allowlist.
public enum HTTPBoundaryError: Error, Equatable {
    case insecureURL
    case redirectRejected
    case invalidResponse
}

private final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

public final class URLSessionHTTPClient: HTTPClient {
    public let allowedHosts: Set<String>
    private let session: URLSession

    public convenience init(allowedHosts: Set<String>) {
        self.init(allowedHosts: allowedHosts, protocolClasses: nil)
    }

    init(allowedHosts: Set<String>, protocolClasses: [AnyClass]?) {
        self.allowedHosts = allowedHosts
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.protocolClasses = protocolClasses
        session = URLSession(configuration: configuration, delegate: RejectRedirects(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard request.url.scheme?.lowercased() == "https",
            request.url.user == nil, request.url.password == nil,
            request.url.port == nil || request.url.port == 443
        else { throw HTTPBoundaryError.insecureURL }
        let host = request.url.host()?.lowercased() ?? ""
        guard allowedHosts.contains(host) else { throw HostNotAllowed(host: host) }
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw HTTPBoundaryError.invalidResponse }
        if (300..<400).contains(http.statusCode) { throw HTTPBoundaryError.redirectRejected }
        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, pair in
            result[String(describing: pair.key).lowercased()] = String(describing: pair.value)
        }
        return HTTPResponse(status: http.statusCode, headers: headers, body: data)
    }
}
