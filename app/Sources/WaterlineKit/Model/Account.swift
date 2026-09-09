import CryptoKit
import Foundation

/// Stable opaque local identity. Legacy secret-derived IDs are read without guessing a migration.
public struct AccountID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        rawValue = UUID().uuidString.lowercased()
    }

    public var description: String { rawValue }
}

/// Where a credential was found. The secret itself is never persisted.
public enum CredentialRef: Codable, Sendable, Hashable {
    case keychain(service: String, account: String)
    case file(path: String)
    case env(name: String, sourceFile: String)
    case configuration(source: OptionalCredentialSource, path: String, key: String)
    case manual
    case localService(name: String)
}

/// Provider scope established from a documented source; a secret is not an identity.
public struct BillingIdentity: Codable, Sendable, Hashable {
    public let region: String
    public let account: String
    public let subject: String?

    public init(region: String, account: String, subject: String? = nil) {
        self.region = region
        self.account = account
        self.subject = subject
    }
}

public struct Account: Identifiable, Codable, Sendable, Hashable {
    public let id: AccountID
    public let provider: Provider
    public let credential: CredentialRef
    public let identity: BillingIdentity?
    public let plan: String?
    public let region: String?
    public let teamID: String?

    public init(
        id: AccountID = AccountID(), provider: Provider, credential: CredentialRef, identity: BillingIdentity? = nil,
        plan: String? = nil, region: String? = nil, teamID: String? = nil
    ) {
        self.id = id
        self.provider = provider
        self.credential = credential
        self.identity = identity
        self.plan = plan
        self.region = region
        self.teamID = teamID
    }
}

/// A secret held in memory only. Not Codable, not printable.
public struct Secret: Sendable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "<redacted>" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }

    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    var revision: String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }

    /// First 8 hex characters of SHA-256; enough to tell accounts apart, useless for recovery.
    public var fingerprint: String {
        SHA256.hash(data: Data(value.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}

/// An account found on this machine, with its secret when it could be read without prompting.
public struct Discovered: Sendable {
    public let account: Account
    public let secret: Secret?
    public let connectionError: FetchError?

    public init(account: Account, secret: Secret?, connectionError: FetchError? = nil) {
        self.account = account
        self.secret = secret
        self.connectionError = connectionError
    }
}

extension CredentialRef {
    public var sourceLabel: String {
        switch self {
        case .file(let path): path
        case .keychain(let service, _): "Keychain · \(service)"
        case .env(let name, let sourceFile): "\(name) · \(sourceFile)"
        case .configuration(_, let path, let key): "\(key) · \(path)"
        case .manual: "Manual key"
        case .localService: "Antigravity CLI"
        }
    }
}
