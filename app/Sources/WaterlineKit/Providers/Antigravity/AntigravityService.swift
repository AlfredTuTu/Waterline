import Foundation

public protocol AntigravityServiceReading: Sendable {
    func identities(executable: URL, requestBudget: any HTTPClient) async throws -> [AntigravityAccountIdentity]
    func usage(
        identity: AntigravityAccountIdentity, executable: URL, requestBudget: any HTTPClient
    ) async throws -> Usage
}

public actor SystemAntigravityService: AntigravityServiceReading {
    private var managedSession: AntigravityManagedSession?
    public init() {}

    public func identities(executable: URL, requestBudget: any HTTPClient) async throws -> [AntigravityAccountIdentity]
    {
        var found: [AntigravityAccountIdentity] = []
        var failure: any Error = FetchError.localServiceUnavailable
        for listener in try await availableListeners(executable) {
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
        for listener in try await availableListeners(executable) {
            try Task.checkCancellation()
            do {
                let client = AntigravityLocalClient()
                let before = try AntigravityAccountIdentity.parse(
                    await client.request(
                        .userStatus, listener: listener, expectedExecutable: executable, requestBudget: requestBudget))
                guard before == identity else { continue }
                let data = try await client.request(
                    .quotaSummary, listener: listener, expectedExecutable: executable, requestBudget: requestBudget)
                let status = try await client.request(
                    .userStatus, listener: listener, expectedExecutable: executable, requestBudget: requestBudget)
                let after = try AntigravityAccountIdentity.parse(status)
                guard after == before else { throw FetchError.credentialMissing }
                let usage = try AntigravityQuotaSummary.parse(data)
                do {
                    return .metrics(
                        windows: usage.quotaWindows, balances: [],
                        plan: try AntigravitySubscription.plan(status), failures: usage.componentFailures)
                } catch let error as FetchError {
                    return .metrics(
                        windows: usage.quotaWindows, balances: [], plan: nil,
                        failures: usage.componentFailures + [
                            MetricFailure(id: "antigravity.subscription-plan", error: error)
                        ])
                }
            } catch {
                try Task.checkCancellation()
                failure = error
            }
        }
        throw failure
    }

    private func availableListeners(_ executable: URL) async throws -> [LocalServiceListener] {
        if let session = managedSession, !session.isRunning { managedSession = nil }
        if managedSession == nil {
            let existing = listeners(executable)
            if !existing.isEmpty { return existing }
            guard LocalProcessIdentity.isInstalledAntigravityCLI(executable) else {
                throw FetchError.localServiceUnavailable
            }
            managedSession = try AntigravityManagedSession(
                executable: executable,
                arguments: ["--input-format", "stream-json", "--output-format", "stream-json", "--print="],
                directory: FileManager.default.temporaryDirectory)
        }
        guard let session = managedSession else { throw FetchError.localServiceUnavailable }
        session.renew()
        do {
            for _ in 0..<150 {
                try Task.checkCancellation()
                guard session.isRunning else { throw FetchError.localServiceUnavailable }
                if session.isReady { return listeners(executable) }
                try await Task.sleep(for: .milliseconds(200))
            }
            throw FetchError.localServiceUnavailable
        } catch {
            session.stop()
            managedSession = nil
            throw error
        }
    }

    private func listeners(_ executable: URL) -> [LocalServiceListener] {
        LocalProcessIdentity.ownedProcesses(executable: executable).flatMap { $0.loopbackListeners() }
    }
}
