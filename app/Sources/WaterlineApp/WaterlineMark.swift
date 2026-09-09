import AppKit

/// Monochrome companion to the app icon, drawn at menu-bar size rather than downsampling its tile.
enum WaterlineMark {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let upper = NSBezierPath()
            upper.lineWidth = 2.2
            upper.lineCapStyle = .round
            upper.move(to: NSPoint(x: 2, y: 10))
            upper.curve(
                to: NSPoint(x: 18, y: 13),
                controlPoint1: NSPoint(x: 8, y: 9.5), controlPoint2: NSPoint(x: 12, y: 13))
            upper.stroke()
            let lower = NSBezierPath()
            lower.lineWidth = 2.2
            lower.lineCapStyle = .round
            lower.move(to: NSPoint(x: 10, y: 5))
            lower.curve(
                to: NSPoint(x: 17, y: 6),
                controlPoint1: NSPoint(x: 13, y: 6.5), controlPoint2: NSPoint(x: 15, y: 6.5))
            lower.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Waterline"
        return image
    }()
}
