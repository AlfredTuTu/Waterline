import Foundation
import LocalAuthentication
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
        let context = LAContext()
        context.interactionNotAllowed = true
        let query: [CFString: Any] = [
            kSecUseAuthenticationContext: context,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecMatchLimit: kSecMatchLimitAll,
            kSecReturnAttributes: true,
        ]
        let (status, result) = try Self.match(query, interactive: false)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
        guard let attributes = result as? [[String: Any]] else {
            throw KeychainFailure(status: errSecDecode)
        }
        return try attributes.map {
            guard let account = $0[kSecAttrAccount as String] as? String else {
                throw KeychainFailure(status: errSecDecode)
            }
            return KeychainItem(service: service, account: account)
        }
    }

    public func secret(for item: KeychainItem, allowsUserInteraction: Bool) throws -> Secret {
        let context = LAContext()
        context.interactionNotAllowed = !allowsUserInteraction
        let query: [CFString: Any] = [
            kSecUseAuthenticationContext: context,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: item.service,
            kSecAttrAccount: item.account,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecReturnData: true,
        ]
        let (status, result) = try Self.match(query, interactive: allowsUserInteraction)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainFailure(status: errSecDecode)
            }
            return Secret(value)
        case errSecInteractionNotAllowed, errSecAuthFailed, errSecUserCanceled:
            throw FetchError.keychainLocked
        case errSecItemNotFound:
            throw FetchError.credentialMissing
        default:
            throw KeychainFailure(status: status)
        }
    }

    private static let queryLock = NSLock()

    /// LAContext does not govern legacy file-Keychain ACL dialogs. Serialize the process-local
    /// legacy policy and restore the exact prior value, including an already-disabled policy.
    private static func match(_ query: [CFString: Any], interactive: Bool) throws -> (OSStatus, CFTypeRef?) {
        try withInteractionPolicy(interactive) {
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            return (status, result)
        }
    }

    static func withInteractionPolicy<T>(_ interactive: Bool, operation: () -> T) throws -> T {
        queryLock.lock()
        defer { queryLock.unlock() }
        var previous = DarwinBoolean(false)
        let readPolicy = SecKeychainGetUserInteractionAllowed(&previous)
        guard readPolicy == errSecSuccess else { throw KeychainFailure(status: readPolicy) }
        let setPolicy = SecKeychainSetUserInteractionAllowed(interactive)
        guard setPolicy == errSecSuccess else { throw KeychainFailure(status: setPolicy) }
        let result = operation()
        let restored = SecKeychainSetUserInteractionAllowed(previous.boolValue)
        guard restored == errSecSuccess else { throw KeychainFailure(status: restored) }
        return result
    }

}

public struct KeychainFailure: Error, Equatable {
    public let status: OSStatus
}
