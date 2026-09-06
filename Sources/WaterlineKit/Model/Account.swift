import CryptoKit
import Foundation

/// Stable identity of one credential-backed account: `<provider>:<fingerprint>`.
public struct AccountID: RawRepresentable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(provider: Provider, secret: Secret) {
        rawValue = "\(provider.rawValue):\(secret.fingerprint)"
    }

    public var description: String { rawValue }
}

/// Where a credential was found. The secret itself is never persisted.
public enum CredentialRef: Codable, Sendable, Hashable {
    case keychain(service: String, account: String)
    case file(path: String)
    case env(name: String, sourceFile: String)
    case manual
}

public struct Account: Identifiable, Codable, Sendable, Hashable {
    public let id: AccountID
    public let provider: Provider
    public let credential: CredentialRef

    public init(id: AccountID, provider: Provider, credential: CredentialRef) {
        self.id = id
        self.provider = provider
        self.credential = credential
    }
}

/// A secret held in memory only. Not Codable, not printable.
public struct Secret: Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    /// First 8 hex characters of SHA-256; enough to tell accounts apart, useless for recovery.
    public var fingerprint: String {
        SHA256.hash(data: Data(value.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}

/// An account found on this machine, with its secret when it could be read without prompting.
public struct Discovered: Sendable {
    public let account: Account
    public let secret: Secret?

    public init(account: Account, secret: Secret?) {
        self.account = account
        self.secret = secret
    }
}
