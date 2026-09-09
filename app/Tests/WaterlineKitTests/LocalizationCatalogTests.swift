import Foundation
import Testing

struct LocalizationCatalogTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func catalog(_ locale: String) throws -> [String: String] {
        let url = root.appending(path: "Resources/\(locale).lproj/Localizable.strings")
        return try #require(
            PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
    }

    @Test func catalogsPreserveKeysAndFormatArguments() throws {
        let english = try catalog("en")
        let chinese = try catalog("zh-Hans")
        #expect(Set(english.keys) == Set(chinese.keys))
        let placeholders = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:@|lld|ld|d|f|s)"#)
        func arguments(_ text: String) -> [String] {
            placeholders.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                (text as NSString).substring(with: $0.range)
            }.sorted()
        }
        for (key, value) in chinese {
            #expect(!value.isEmpty, "Empty translation: \(key)")
            #expect(arguments(key) == arguments(value), "Format arguments changed: \(key)")
        }
    }

    // Covers direct single-line literals, not dynamic provider data or interpolated SwiftUI keys.
    @Test func directInterfaceLiteralsHaveCatalogEntries() throws {
        let entries = try catalog("en")
        let literals = try NSRegularExpression(
            pattern:
                #"(?:Text|Button|Label|Toggle|Picker|GroupBox|TextField|SecureField|Menu|ContentUnavailableView|help|accessibilityLabel|accessibilityHint|text|format|LocalizedStringKey)\(\s*"([^"\n]*)""#
        )
        let source = root.appending(path: "Sources/WaterlineApp")
        let files = try #require(FileManager.default.enumerator(at: source, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let contents = try String(contentsOf: file, encoding: .utf8)
            for match in literals.matches(in: contents, range: NSRange(contents.startIndex..., in: contents)) {
                let key = (contents as NSString).substring(with: match.range(at: 1))
                if key.contains(#"\("#) || ["", "—", "Waterline"].contains(key) { continue }
                #expect(entries[key] != nil, "Missing UI translation key in \(file.lastPathComponent): \(key)")
            }
        }
        #expect(entries["Manual key"] != nil)
    }
}
