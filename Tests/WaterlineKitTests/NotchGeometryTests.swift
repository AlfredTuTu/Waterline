import CoreGraphics
import Foundation
import Testing

@testable import WaterlineKit

@Suite struct NotchGeometryTests {
    @Test func `a screen with a camera housing gets a notch layout hugging the top edge`() {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTop: 32,
            auxiliaryTopLeftWidth: 500,
            auxiliaryTopRightWidth: 500
        )
        #expect(geometry.style == .notch)
        #expect(geometry.notchWidth == 512)
        #expect(geometry.collapsedFrame == CGRect(x: 368, y: 950, width: 776, height: 32))
    }

    @Test func `a screen without a housing gets a floating capsule`() {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            safeAreaTop: 0,
            auxiliaryTopLeftWidth: nil,
            auxiliaryTopRightWidth: nil
        )
        #expect(geometry.style == .floating)
        #expect(geometry.notchWidth == 0)
        #expect(geometry.collapsedFrame == CGRect(x: 1148, y: 1400, width: 264, height: 32))
    }
}
