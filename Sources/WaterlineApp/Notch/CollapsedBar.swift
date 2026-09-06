import SwiftUI
import WaterlineKit

/// Placeholder collapsed state: health dots on the left of the housing, the headline metric on the right.
struct CollapsedBar: View {
    let geometry: NotchGeometry

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(.secondary).frame(width: 5, height: 5)
                }
            }
            .frame(width: NotchGeometry.sideWidth)
            Color.clear.frame(width: geometry.notchWidth)
            Text("—")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: NotchGeometry.sideWidth)
        }
        .frame(width: geometry.collapsedFrame.width, height: geometry.collapsedFrame.height)
        .background(geometry.style == .floating ? Color.black.opacity(0.85) : .clear, in: Capsule())
    }
}
