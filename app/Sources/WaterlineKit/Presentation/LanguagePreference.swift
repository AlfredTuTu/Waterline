import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public func localizationIdentifier(systemLanguages: [String]) -> String {
        if self != .system { return rawValue }
        return Bundle.preferredLocalizations(from: ["en", "zh-Hans"], forPreferences: systemLanguages).first ?? "en"
    }
}

/// Uses the standard per-app language override; never writes the global preference domain.
public struct LanguagePreferenceStore {
    private let domain: String
    private let defaults: UserDefaults

    public init(domain: String) {
        self.domain = domain
        self.defaults = domain == Bundle.main.bundleIdentifier ? .standard : UserDefaults(suiteName: domain)!
    }

    public var selected: AppLanguage {
        let languages = defaults.persistentDomain(forName: domain)?["AppleLanguages"] as? [String]
        return languages?.first.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    public func select(_ language: AppLanguage) {
        if language == .system {
            defaults.removeObject(forKey: "AppleLanguages")
        } else {
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }
}
