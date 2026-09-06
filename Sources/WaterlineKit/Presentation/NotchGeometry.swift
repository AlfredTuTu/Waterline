import CoreGraphics

/// Where the panel sits, computed from screen metrics so it is testable without AppKit.
/// Frames use AppKit screen coordinates (origin bottom-left).
public struct NotchGeometry: Equatable, Sendable {
    public enum Style: Equatable, Sendable {
        /// Content sits on both sides of the camera housing.
        case notch
        /// No housing (external display, older Mac): a floating capsule at the top centre.
        case floating
    }

    public let style: Style
    /// The collapsed panel frame.
    public let collapsedFrame: CGRect
    /// Width of the camera housing; zero when floating.
    public let notchWidth: CGFloat

    /// Horizontal room on each side of the housing for dots and the headline metric.
    public static let sideWidth: CGFloat = 132
    public static let floatingSize = CGSize(width: 264, height: 32)
    public static let floatingTopInset: CGFloat = 8

    public static func compute(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeftWidth: CGFloat?,
        auxiliaryTopRightWidth: CGFloat?
    ) -> NotchGeometry {
        guard safeAreaTop > 0, let left = auxiliaryTopLeftWidth, let right = auxiliaryTopRightWidth else {
            let origin = CGPoint(
                x: screenFrame.midX - floatingSize.width / 2,
                y: screenFrame.maxY - floatingTopInset - floatingSize.height
            )
            let frame = CGRect(origin: origin, size: floatingSize)
            return NotchGeometry(style: .floating, collapsedFrame: frame, notchWidth: 0)
        }
        let notchWidth = screenFrame.width - left - right
        let width = notchWidth + sideWidth * 2
        let frame = CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - safeAreaTop,
            width: width,
            height: safeAreaTop
        )
        return NotchGeometry(style: .notch, collapsedFrame: frame, notchWidth: notchWidth)
    }
}
