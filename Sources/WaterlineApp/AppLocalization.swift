import Foundation
import Observation
import WaterlineKit

@Observable
final class AppLocalization {
    static let shared = AppLocalization()
    private let store: LanguagePreferenceStore
    private(set) var language: AppLanguage

    private init() {
        let store = LanguagePreferenceStore(domain: Bundle.main.bundleIdentifier ?? "io.github.alfredtutu.waterline")
        self.store = store
        language = store.selected
    }

    var identifier: String {
        if language != .system { return language.localizationIdentifier(systemLanguages: []) }
        let systemLanguages =
            UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[
                "AppleLanguages"] as? [String] ?? Locale.preferredLanguages
        return language.localizationIdentifier(systemLanguages: systemLanguages)
    }

    var locale: Locale { Locale(identifier: identifier) }

    var bundle: Bundle {
        Bundle.main.url(forResource: identifier, withExtension: "lproj").flatMap(Bundle.init(url:)) ?? .main
    }

    func select(_ language: AppLanguage) {
        store.select(language)
        self.language = store.selected
    }
}
