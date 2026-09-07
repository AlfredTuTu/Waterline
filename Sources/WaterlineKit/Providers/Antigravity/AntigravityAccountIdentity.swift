import CryptoKit
import Foundation

/// Stable local identity derived only from the account email reported by GetUserStatus.
public struct AntigravityAccountIdentity: Equatable, Sendable {
    public let key: String

    public static func parse(_ data: Data) throws -> Self {
        guard data.count <= 1_048_576 else { throw FetchError.schemaChanged(detail: "userStatus.size") }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let status = root["userStatus"] as? [String: Any],
            let rawEmail = status["email"] as? String,
            rawEmail.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else { throw FetchError.schemaChanged(detail: "userStatus.email") }

        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard email.utf8.count <= 320, parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else {
            throw FetchError.schemaChanged(detail: "userStatus.email")
        }
        let material = Data(("waterline.antigravity.account.email.v1\u{0}" + email).utf8)
        return Self(key: SHA256.hash(data: material).map { String(format: "%02x", $0) }.joined())
    }
}
