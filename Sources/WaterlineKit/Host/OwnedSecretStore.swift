import Foundation
import Security

/// Access is limited to Waterline-owned entries; callers cannot name another service.
public protocol OwnedSecretStoring: Sendable {
    func read(_ id: AccountID, interactive: Bool) throws -> Secret
    func save(_ secret: Secret, for id: AccountID) throws
    func delete(_ id: AccountID) throws
}

private let ownedKeychainReadQueue = DispatchQueue(
    label: "Waterline.owned-keychain-read", qos: .userInitiated, attributes: .concurrent)

extension OwnedSecretStoring {
    /// Security.framework may wait for system authorization; do not occupy the engine actor while it waits.
    func readAsync(_ id: AccountID, interactive: Bool) async throws -> Secret {
        try await withCheckedThrowingContinuation { continuation in
            ownedKeychainReadQueue.async {
                do { continuation.resume(returning: try self.read(id, interactive: interactive)) } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

public struct SystemOwnedSecretStore: OwnedSecretStoring {
    public static let service = "io.github.alfredtutu.waterline"
    public init() {}

    public func read(_ id: AccountID, interactive: Bool) throws -> Secret {
        try SystemKeychain().secret(
            for: KeychainItem(service: Self.service, account: id.rawValue), allowsUserInteraction: interactive)
    }

    public func save(_ secret: Secret, for id: AccountID) throws {
        let query = query(id)
        let value: [CFString: Any] = [kSecValueData: Data(secret.value.utf8)]
        let status = try SystemKeychain.withInteractionPolicy(false) {
            let updated = SecItemUpdate(query as CFDictionary, value as CFDictionary)
            if updated != errSecItemNotFound { return updated }
            return SecItemAdd(query.merging(value) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainFailure(status: status) }
    }

    public func delete(_ id: AccountID) throws {
        let status = try SystemKeychain.withInteractionPolicy(false) { SecItemDelete(query(id) as CFDictionary) }
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainFailure(status: status) }
    }

    private func query(_ id: AccountID) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: Self.service, kSecAttrAccount: id.rawValue]
    }
}
