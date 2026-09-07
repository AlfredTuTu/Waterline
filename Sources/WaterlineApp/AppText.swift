import Foundation
import WaterlineKit

enum AppText {
    static func source(_ credential: CredentialRef) -> String {
        if case .keychain(let service, _) = credential { return format("Keychain · %@", service) }
        if case .env(let name, let sourceFile) = credential, sourceFile == "process" {
            return format("%@ · App environment", name)
        }
        return text(credential.sourceLabel)
    }
    static func text(_ key: String) -> String {
        AppLocalization.shared.bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// Arguments stay data; never build a localization key or format string from an account label.
    static func format(_ key: String, _ arguments: String...) -> String {
        String(format: text(key), locale: AppLocalization.shared.locale, arguments: arguments.map { $0 as CVarArg })
    }
}
