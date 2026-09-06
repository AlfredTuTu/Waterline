import SwiftUI
import WaterlineKit

@main
struct WaterlineApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Waterline", systemImage: "water.waves") {
            Text("Waterline \(WaterlineVersion.current)")
            Divider()
            Button("Quit Waterline") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
