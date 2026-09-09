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
    /// The selected display, independent of the panel's previous display during a move.
    public let screenFrame: CGRect
    /// The collapsed panel frame.
    public let collapsedFrame: CGRect
    /// Width of the camera housing; zero when floating.
    public let notchWidth: CGFloat

    /// Horizontal room on each side of the housing for a provider logo.
    public static let sideWidth: CGFloat = 68
    public static let floatingSize = CGSize(width: 136, height: 32)
    public static let floatingTopInset: CGFloat = 8

    public var previewFrame: CGRect {
        let width = min(screenFrame.width - 16, notchWidth + 264)
        return CGRect(
            x: collapsedFrame.midX - width / 2, y: collapsedFrame.minY,
            width: width, height: collapsedFrame.height)
    }

    public func expandedFrame(accountCount: Int) -> CGRect {
        let width = min(screenFrame.width - 16, max(previewFrame.width, accountCount > 1 ? 640 : 420))
        let contentHeight = max(0, min(collapsedFrame.minY - screenFrame.minY - 8, accountCount > 2 ? 420 : 260))
        let height = collapsedFrame.height + contentHeight
        return CGRect(
            x: collapsedFrame.midX - width / 2, y: collapsedFrame.maxY - height,
            width: width, height: height)
    }

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
            return NotchGeometry(style: .floating, screenFrame: screenFrame, collapsedFrame: frame, notchWidth: 0)
        }
        let notchWidth = screenFrame.width - left - right
        let width = notchWidth + sideWidth * 2
        let frame = CGRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.maxY - safeAreaTop,
            width: width,
            height: safeAreaTop
        )
        return NotchGeometry(style: .notch, screenFrame: screenFrame, collapsedFrame: frame, notchWidth: notchWidth)
    }
}
