import CoreGraphics
import Foundation
import Testing

@testable import WaterlineKit

@Suite struct NotchGeometryTests {
    @Test(arguments: [CGPoint(x: -1280, y: -900), CGPoint(x: 1512, y: 982), CGPoint.zero])
    func expansionUsesTargetDisplayCoordinates(origin: CGPoint) {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(origin: origin, size: CGSize(width: 1280, height: 800)),
            safeAreaTop: 0, auxiliaryTopLeftWidth: nil, auxiliaryTopRightWidth: nil)
        let frame = geometry.expandedFrame(accountCount: 11)
        #expect(frame == CGRect(x: origin.x + 320, y: origin.y + 340, width: 640, height: 452))
        #expect(frame.maxY == geometry.collapsedFrame.maxY)
        #expect(geometry.screenFrame.contains(frame))
    }

    @Test func expansionFitsNarrowShortDisplay() {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(x: -500, y: -300, width: 500, height: 300),
            safeAreaTop: 0, auxiliaryTopLeftWidth: nil, auxiliaryTopRightWidth: nil)
        let frame = geometry.expandedFrame(accountCount: 11)
        #expect(frame == CGRect(x: -492, y: -292, width: 484, height: 284))
        #expect(frame.minY == geometry.screenFrame.minY + 8)
    }

    @Test func accountCountChangesSizeWithoutMovingTopAnchor() {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            safeAreaTop: 0, auxiliaryTopLeftWidth: nil, auxiliaryTopRightWidth: nil)
        let single = geometry.expandedFrame(accountCount: 1)
        let pair = geometry.expandedFrame(accountCount: 2)
        let many = geometry.expandedFrame(accountCount: 11)
        #expect(single.size == CGSize(width: 420, height: 292))
        #expect(pair.size == CGSize(width: 640, height: 292))
        #expect(many.size == CGSize(width: 640, height: 452))
        #expect(single.maxY == pair.maxY && pair.maxY == many.maxY)
        #expect(single.midX == pair.midX && pair.midX == many.midX)
    }

    @Test func wideHousingIsPreservedOnExpansion() {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTop: 32, auxiliaryTopLeftWidth: 500, auxiliaryTopRightWidth: 500)
        #expect(geometry.expandedFrame(accountCount: 1) == CGRect(x: 368, y: 690, width: 776, height: 292))
    }

    @Test func `a screen with a camera housing gets a notch layout hugging the top edge`() {
        let geometry = NotchGeometry.compute(
            screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeAreaTop: 32,
            auxiliaryTopLeftWidth: 500,
            auxiliaryTopRightWidth: 500
        )
        #expect(geometry.style == .notch)
        #expect(geometry.notchWidth == 512)
        #expect(geometry.collapsedFrame == CGRect(x: 432, y: 950, width: 648, height: 32))
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
        #expect(geometry.collapsedFrame == CGRect(x: 1212, y: 1400, width: 136, height: 32))
    }
}
