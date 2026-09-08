import AppKit
import SwiftUI
import WaterlineKit

struct ProviderLogo: View {
    let provider: Provider?

    private static let images: [Provider: NSImage] = Dictionary(
        uniqueKeysWithValues: Provider.allCases.compactMap { provider in
            if provider == .codex,
                let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex"),
                let bundle = Bundle(url: appURL),
                (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) == "ChatGPT"
            {
                return (provider, NSWorkspace.shared.icon(forFile: appURL.path))
            }
            guard let url = Bundle.main.url(forResource: "Provider-\(provider.rawValue)", withExtension: "png"),
                let image = NSImage(contentsOf: url)
            else { return nil }
            return (provider, image)
        })

    var body: some View {
        if let provider, let image = Self.images[provider] {
            Image(nsImage: image)
                .renderingMode([Provider.moonshot, .cursor, .grok, .xai].contains(provider) ? .template : .original)
                .resizable().scaledToFit()
                .accessibilityHidden(true)
        } else {
            Image(nsImage: WaterlineMark.image).resizable().scaledToFit().foregroundStyle(.cyan)
                .accessibilityHidden(true)
        }
    }
}
