import Foundation

public enum QuotaKind: String, Codable, Sendable {
    case window
    case balance
    case both
    case unsupported
}

/// Whether the endpoint is documented by the vendor or reverse-engineered by the community.
public enum DocStatus: String, Codable, Sendable {
    case official
    case community
}

public struct ManualRegion: Sendable, Identifiable {
    public let id: String
    public let label: String
    public let host: String
    public init(id: String, label: String, host: String) { self.id = id; self.label = label; self.host = host }
}

public struct ProviderDescriptor: Sendable {
    public let provider: Provider
    public let kind: QuotaKind
    public let docStatus: DocStatus
    /// The only hosts this adapter may talk to. Enforced by `HTTPClient`, not by convention.
    public let allowedHosts: Set<String>
    /// Where a double-click on the row goes: top-ups and upgrades happen there, not in the app.
    public let regionalConsoleURLs: [String: URL]
    public let manualRegions: [ManualRegion]
    public let requiresTeamID: Bool
    public let supportsManualKey: Bool
    public let consoleURL: URL

    public init(
        provider: Provider,
        kind: QuotaKind,
        docStatus: DocStatus,
        allowedHosts: Set<String>,
        consoleURL: URL, supportsManualKey: Bool = false, manualRegions: [ManualRegion] = [],
        regionalConsoleURLs: [String: URL] = [:], requiresTeamID: Bool = false
    ) {
        self.provider = provider
        self.kind = kind
        self.docStatus = docStatus
        self.allowedHosts = allowedHosts
        self.consoleURL = consoleURL
        self.supportsManualKey = supportsManualKey
        self.manualRegions = manualRegions
        self.regionalConsoleURLs = regionalConsoleURLs
        self.requiresTeamID = requiresTeamID
    }
    public func consoleURL(for region: String?) -> URL {
        region.flatMap { regionalConsoleURLs[$0] } ?? consoleURL
    }

}

/// One provider = one folder under `Providers/` + one line in `Registry`.
public protocol ProviderAdapter: Sendable {
    static var descriptor: ProviderDescriptor { get }

    /// Read-only discovery of accounts on this machine. Returns a `nil` secret when reading it
    /// would prompt and `environment.allowsUserInteraction` is false.
    func discover(in environment: DiscoveryEnvironment, http: any HTTPClient) async throws -> [Discovered]

    /// Report exactly what the provider says. Throw `FetchError` when it cannot; never invent values.
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage
}

/// Providers authenticated by a verified local service do not manufacture a secret credential.
public protocol LocalProviderAdapter: ProviderAdapter {
    func fetchLocal(_ account: Account, requestBudget: any HTTPClient) async throws -> Usage
}

extension LocalProviderAdapter {
    public func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage {
        throw FetchError.credentialMissing
    }
}
