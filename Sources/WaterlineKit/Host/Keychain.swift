import Foundation
import Security

public struct KeychainItem: Sendable, Hashable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }
}

public protocol KeychainReading: Sendable {
    /// Lists items by attributes only. Never prompts.
    func items(service: String) throws -> [KeychainItem]

    /// Reads the secret data. When `allowsUserInteraction` is false and macOS would need to ask the
    /// user, throws `FetchError.keychainLocked` instead of showing a prompt.
    func secret(for item: KeychainItem, allowsUserInteraction: Bool) throws -> Secret
}

/// Login keychain access through the Security framework.
public struct SystemKeychain: KeychainReading {
    public init() {}

    public func items(service: String) throws -> [KeychainItem] {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
        let attributes = result as! [[String: Any]]
        return attributes.map { KeychainItem(service: service, account: $0[kSecAttrAccount as String] as! String) }
    }

    public func secret(for item: KeychainItem, allowsUserInteraction: Bool) throws -> Secret {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: item.service,
            kSecAttrAccount: item.account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        SecKeychainSetUserInteractionAllowed(allowsUserInteraction)
        defer { SecKeychainSetUserInteractionAllowed(true) }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return Secret(String(decoding: result as! Data, as: UTF8.self))
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            throw FetchError.keychainLocked
        case errSecItemNotFound:
            throw FetchError.credentialMissing
        default:
            throw KeychainFailure(status: status)
        }
    }
}

public struct KeychainFailure: Error, Equatable {
    public let status: OSStatus
}
