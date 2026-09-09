import SwiftUI

/// Expanded content and header share one contour, anchored to the screen edge when a housing exists.
struct IslandSilhouette: Shape {
    let expanded: Bool
    let attachedToTop: Bool

    func path(in rect: CGRect) -> Path {
        if !expanded && !attachedToTop { return Capsule().path(in: rect) }
        let bottomRadius: CGFloat = expanded ? 26 : 14
        let topRadius: CGFloat = attachedToTop ? 0 : 24
        return UnevenRoundedRectangle(
            topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius,
            bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius
        ).path(in: rect)
    }
}
