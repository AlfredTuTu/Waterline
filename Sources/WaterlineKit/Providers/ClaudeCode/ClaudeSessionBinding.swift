import Foundation

/// Binds only an empty, newly started CLI session to an independently verified login.
/// A later callback cannot establish which login an already-running session originally used.
public struct ClaudeSessionBinding: Codable, Sendable, Equatable {
    public let sessionID: UUID
    public let identity: BillingIdentity
    public private(set) var lastAPIDurationMilliseconds: Double

    public init?(initial: ClaudeStatuslineReading, localIdentity: BillingIdentity, verifiedIdentity: BillingIdentity) {
        guard initial.apiDurationMilliseconds == 0, initial.quotas.isEmpty,
            ClaudeLocalLogin.matches(localIdentity, verified: verifiedIdentity)
        else { return nil }
        sessionID = initial.sessionID
        identity = verifiedIdentity
        lastAPIDurationMilliseconds = 0
    }

    /// Returns quota data only after API progress in the same bound session.
    /// It does not assign a provider timestamp or turn unchanged cached quotas into a fresh reading.
    public mutating func accept(
        _ reading: ClaudeStatuslineReading, currentIdentity: BillingIdentity
    ) throws -> [ClaudeStatuslineQuota]? {
        guard reading.sessionID == sessionID, ClaudeLocalLogin.matches(currentIdentity, verified: identity) else {
            throw FetchError.credentialMissing
        }
        guard lastAPIDurationMilliseconds.isFinite, lastAPIDurationMilliseconds >= 0 else {
            throw FetchError.schemaChanged(detail: "claude.session.lastAPIDurationMilliseconds")
        }
        guard let duration = reading.apiDurationMilliseconds else { return nil }
        guard duration.isFinite, duration >= lastAPIDurationMilliseconds else {
            throw FetchError.schemaChanged(detail: "claude.session.apiDurationRegression")
        }
        guard duration > lastAPIDurationMilliseconds else { return nil }
        lastAPIDurationMilliseconds = duration
        return reading.quotas.isEmpty ? nil : reading.quotas
    }
}
