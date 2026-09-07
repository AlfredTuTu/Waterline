import Darwin
import Foundation
import Security

public enum LocalServiceError: Error, Equatable {
    case identityChanged, certificateRejected, redirectRejected, responseTooLarge, invalidResponse
}

public enum AntigravityLocalRequest: Sendable {
    case quotaSummary, userStatus

    var path: String {
        switch self {
        case .quotaSummary: "/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
        case .userStatus: "/exa.language_server_pb.LanguageServerService/GetUserStatus"
        }
    }

    var body: Data {
        switch self {
        case .quotaSummary: Data(#"{"forceRefresh":true}"#.utf8)
        case .userStatus: Data(#"{}"#.utf8)
        }
    }
}

/// Only for a previously identified CLI listener. Never accepts a URL or credentials from callers.
public struct AntigravityLocalClient: Sendable {
    public init() {}

    public func request(
        _ kind: AntigravityLocalRequest, listener: LocalServiceListener, expectedExecutable: URL,
        requestBudget: any HTTPClient
    ) async throws -> Data {
        try await requestBudget.withRequestPermit {
            try await performRequest(kind, listener: listener, expectedExecutable: expectedExecutable)
        }
    }

    private func performRequest(
        _ kind: AntigravityLocalRequest, listener: LocalServiceListener, expectedExecutable: URL
    ) async throws -> Data {
        guard listener.process.isAntigravityCLI(expectedExecutable: expectedExecutable),
            listener.isCurrent()
        else { throw LocalServiceError.identityChanged }
        let delegate = LocalServiceTLSDelegate(listener: listener)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://127.0.0.1:\(listener.port)\(kind.path)")!)
        request.httpMethod = "POST"
        request.httpBody = kind.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        let (stream, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw LocalServiceError.invalidResponse }
        if (300..<400).contains(response.statusCode) { throw LocalServiceError.redirectRejected }
        guard response.expectedContentLength <= 1_048_576 else { throw LocalServiceError.responseTooLarge }
        var body = Data()
        for try await byte in stream {
            guard body.count < 1_048_576 else { throw LocalServiceError.responseTooLarge }
            body.append(byte)
        }
        guard listener.isCurrent() else { throw LocalServiceError.identityChanged }
        let headers = response.value(forHTTPHeaderField: "Retry-After").map { ["Retry-After": $0] } ?? [:]
        try HTTPResponse(status: response.statusCode, headers: headers, body: Data()).validateStatus()
        return body
    }
}

/// Mutable pin state is protected by the lock; delegate callbacks may arrive on different queues.
private final class LocalServiceTLSDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let listener: LocalServiceListener
    private let lock = NSLock()
    private var certificate: Data?

    init(listener: LocalServiceListener) { self.listener = listener }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == "127.0.0.1", challenge.protectionSpace.port == Int(listener.port),
            listener.isCurrent(), let serverTrust = challenge.protectionSpace.serverTrust,
            let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate], let leaf = chain.first
        else { completionHandler(.cancelAuthenticationChallenge, nil); return }
        let data = SecCertificateCopyData(leaf) as Data
        guard listener.process.isAntigravityCLI(expectedExecutable: URL(fileURLWithPath: listener.process.executable)),
            let trust = LocalTLSCertificate.trust(der: data, allowAntigravityCLIProfile: true)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil); return
        }
        let matches = lock.withLock {
            if let certificate { return certificate == data }
            certificate = data
            return true
        }
        guard matches else { completionHandler(.cancelAuthenticationChallenge, nil); return }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
