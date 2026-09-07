import SwiftUI
import WaterlineKit

@main
struct WaterlineApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var localization = AppLocalization.shared

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra {
            Group {
                Text("Waterline \(WaterlineVersion.current)")
                Button("Show accounts") { delegate.showAccounts() }
                Button("Balance history") {
                    NSApplication.shared.activate(); openWindow(id: "balance-history")
                }
                Button("Token records") {
                    NSApplication.shared.activate(); openWindow(id: "token-history")
                }
                Button("Refresh") { Task { await delegate.model.refresh() } }
                    .disabled(delegate.model.refreshing)
                Button("Settings") {
                    NSApplication.shared.activate(); openSettings()
                }.disabled(delegate.model.isVerification)
                Divider()
                Button("Quit Waterline") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q")
            }.environment(\.locale, localization.locale)
        } label: {
            Image(nsImage: WaterlineMark.image).accessibilityLabel("Waterline")
        }
        Window("Balance history", id: "balance-history") {
            HistoryWindow(model: delegate.model).modifier(RecordWindowBehavior()).environment(
                \.locale, localization.locale)
        }.defaultSize(width: 720, height: 520)
        Window("Token records", id: "token-history") {
            TokenHistoryWindow(model: delegate.model).modifier(RecordWindowBehavior()).environment(
                \.locale, localization.locale)
        }.defaultSize(width: 780, height: 560)
        Settings { SettingsView(model: delegate.model).environment(\.locale, localization.locale) }
    }
}
