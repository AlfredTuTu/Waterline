import AppKit
import SwiftUI

struct RecordWindowBehavior: ViewModifier {
    func body(content: Content) -> some View {
        content.background(FullScreenWindowSupport())
    }
}

private struct FullScreenWindowSupport: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowAttachment { WindowAttachment() }
    func updateNSView(_ view: WindowAttachment, context: Context) {}

    final class WindowAttachment: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !(window is NSPanel) else { return }
            window.collectionBehavior.remove([.fullScreenNone, .fullScreenAuxiliary])
            window.collectionBehavior.insert(.fullScreenPrimary)
        }
    }
}
