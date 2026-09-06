import AppKit
import WaterlineKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main!
        let geometry = NotchGeometry.compute(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryTopRightWidth: screen.auxiliaryTopRightArea?.width
        )
        let panel = NotchPanel(geometry: geometry)
        panel.orderFrontRegardless()
        self.panel = panel
    }
}
