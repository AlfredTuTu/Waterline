import Foundation
import Testing

@testable import WaterlineKit

struct LanguagePreferenceTests {
    @Test func explicitLanguageAndSystemFallbackResolveIndependently() {
        #expect(AppLanguage.english.localizationIdentifier(systemLanguages: ["zh-Hans-CN"]) == "en")
        #expect(AppLanguage.simplifiedChinese.localizationIdentifier(systemLanguages: ["en-AU"]) == "zh-Hans")
        #expect(AppLanguage.system.localizationIdentifier(systemLanguages: ["zh-Hans-CN", "en-AU"]) == "zh-Hans")
        #expect(AppLanguage.system.localizationIdentifier(systemLanguages: ["en-AU", "zh-Hans"]) == "en")
        #expect(AppLanguage.system.localizationIdentifier(systemLanguages: ["fr-FR"]) == "en")
    }
    @Test func languageIsAppScopedAndRestoresSystemFallback() {
        let firstDomain = "waterline.language-test.\(UUID())"
        let secondDomain = "waterline.language-test.\(UUID())"
        defer {
            UserDefaults.standard.removePersistentDomain(forName: firstDomain)
            UserDefaults.standard.removePersistentDomain(forName: secondDomain)
        }
        let first = LanguagePreferenceStore(domain: firstDomain)
        let second = LanguagePreferenceStore(domain: secondDomain)
        #expect(first.selected == .system)
        first.select(.simplifiedChinese)
        #expect(LanguagePreferenceStore(domain: firstDomain).selected == .simplifiedChinese)
        #expect(second.selected == .system)
        first.select(.english)
        #expect(LanguagePreferenceStore(domain: firstDomain).selected == .english)
        first.select(.system)
        #expect(first.selected == .system)
        #expect(UserDefaults.standard.persistentDomain(forName: firstDomain)?["AppleLanguages"] == nil)
    }
}
