import Foundation

public protocol AntigravityServiceReading: Sendable {
    func identities(executable: URL, requestBudget: any HTTPClient) async throws -> [AntigravityAccountIdentity]
    func usage(
        identity: AntigravityAccountIdentity, executable: URL, requestBudget: any HTTPClient
    ) async throws -> Usage
}

public struct SystemAntigravityService: AntigravityServiceReading {
    public init() {}

    public func identities(executable: URL, requestBudget: any HTTPClient) async throws -> [AntigravityAccountIdentity]
    {
        var found: [AntigravityAccountIdentity] = []
        var failure: any Error = FetchError.localServiceUnavailable
        for listener in listeners(executable) {
            try Task.checkCancellation()
            do {
                let data = try await AntigravityLocalClient().request(
                    .userStatus, listener: listener, expectedExecutable: executable, requestBudget: requestBudget)
                let identity = try AntigravityAccountIdentity.parse(data)
                if !found.contains(identity) { found.append(identity) }
            } catch {
                try Task.checkCancellation()
                failure = error
            }
        }
        guard !found.isEmpty else { throw failure }
        return found
    }

    public func usage(
        identity: AntigravityAccountIdentity, executable: URL, requestBudget: any HTTPClient
    ) async throws -> Usage {
        var failure: any Error = FetchError.localServiceUnavailable
        for listener in listeners(executable) {
            try Task.checkCancellation()
            do {
                let client = AntigravityLocalClient()
                let before = try AntigravityAccountIdentity.parse(
                    await client.request(
                        .userStatus, listener: listener, expectedExecutable: executable, requestBudget: requestBudget))
                guard before == identity else { continue }
                let data = try await client.request(
                    .quotaSummary, listener: listener, expectedExecutable: executable, requestBudget: requestBudget)
                let after = try AntigravityAccountIdentity.parse(
                    await client.request(
                        .userStatus, listener: listener, expectedExecutable: executable, requestBudget: requestBudget))
                guard after == before else { throw FetchError.credentialMissing }
                return try AntigravityQuotaSummary.parse(data)
            } catch {
                try Task.checkCancellation()
                failure = error
            }
        }
        throw failure
    }

    private func listeners(_ executable: URL) -> [LocalServiceListener] {
        LocalProcessIdentity.ownedProcesses(executable: executable).flatMap { $0.loopbackListeners() }
    }
}
