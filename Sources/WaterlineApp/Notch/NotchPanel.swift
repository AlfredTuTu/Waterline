import AppKit
import SwiftUI
import WaterlineKit

/// A non-activating panel above the menu bar, positioned by `NotchGeometry`.
final class NotchPanel: NSPanel {
    init(geometry: NotchGeometry) {
        super.init(
            contentRect: geometry.collapsedFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        contentView = NSHostingView(rootView: CollapsedBar(geometry: geometry))
    }
}
