import SwiftUI
import WaterlineKit

@main
struct WaterlineApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var localization = AppLocalization.shared

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            Group {
                Text("Waterline")
                Button("Show accounts") { delegate.showAccounts() }
                Button("Refresh") { Task { await delegate.model.refresh() } }
                    .disabled(delegate.model.refreshing)
                Button("Manage accounts") {
                    NSApplication.shared.activate(); openWindow(id: "connections")
                }.disabled(delegate.model.isVerification)
                Picker("Language", selection: Binding(get: { localization.language }, set: { localization.select($0) }))
                {
                    Text("Follow system").tag(AppLanguage.system)
                    Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
                    Text(verbatim: "English").tag(AppLanguage.english)
                }
                Divider()
                Button("Quit Waterline") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }.environment(\.locale, localization.locale)
        } label: {
            Image(nsImage: WaterlineMark.image).accessibilityLabel("Waterline")
        }
        Window("Account display order", id: "account-order") {
            AccountOrderSheet(model: delegate.model).environment(\.locale, localization.locale)
        }.windowResizability(.contentSize)
        Window("Manage accounts", id: "connections") {
            AccountConnectionsView(model: delegate.model).environment(\.locale, localization.locale)
        }.windowResizability(.contentSize)
    }
}
