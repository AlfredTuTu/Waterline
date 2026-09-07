import SwiftUI
import WaterlineKit

struct LanguageSettings: View {
    @State private var localization = AppLocalization.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(
                "Language",
                selection: Binding(
                    get: { localization.language },
                    set: { localization.select($0) })
            ) {
                Text("Follow system").tag(AppLanguage.system)
                Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
                Text(verbatim: "English").tag(AppLanguage.english)
            }
            Text("Language changes apply immediately.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
