import Foundation

/// One limiter per engine, shared by usage and discovery clients across overlapping operations.
actor HTTPRequestLimiter {
    private var active = 0
    private var waiters: [(UUID, CheckedContinuation<Void, any Error>)] = []
    var waitingCount: Int { waiters.count }

    func send(_ request: HTTPRequest, through client: any HTTPClient) async throws -> HTTPResponse {
        try await withPermit { try await client.send(request) }
    }

    func withPermit<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if active < 4 {
                    active += 1
                    continuation.resume()
                } else {
                    waiters.append((id, continuation))
                }
            }
        } onCancel: {
            Task { await self.cancelWaiting(id) }
        }
        defer { release() }
        try Task.checkCancellation()
        let response = try await operation()
        try Task.checkCancellation()
        return response
    }

    private func cancelWaiting(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.0 == id }) else { return }
        waiters.remove(at: index).1.resume(throwing: CancellationError())
    }

    private func release() {
        if waiters.isEmpty { active -= 1 } else { waiters.removeFirst().1.resume() }
    }
}

struct LimitedHTTPClient: HTTPClient {
    let client: any HTTPClient
    let limiter: HTTPRequestLimiter
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await limiter.send(request, through: client)
    }
    func withRequestPermit<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await limiter.withPermit(operation)
    }
}
