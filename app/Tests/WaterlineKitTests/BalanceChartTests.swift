import Foundation
import Testing

@testable import WaterlineKit

struct BalanceChartTests {
    private let id = AccountID(rawValue: "chart-test")
    private func point(_ time: Double, _ amount: Int) -> BalanceObservation {
        BalanceObservation(
            accountID: id, currency: "USD", amount: Decimal(amount),
            observedAt: Date(timeIntervalSince1970: time))
    }

    @Test func pixelEnvelopePreservesEndpointsAndExtremaOfLongHistory() {
        var points = (0..<25920).map { point(Double($0 * 300), 100) }
        points[12001] = point(Double(12001 * 300), 900)
        points[12002] = point(Double(12002 * 300), -20)
        let samples = BalanceChart.samples(points, columns: 600, gap: 600)
        #expect(samples.count <= 2400)
        #expect(samples.first?.observation == points.first)
        #expect(samples.last?.observation == points.last)
        #expect(samples.map(\.observation.amount).max() == 900)
        #expect(samples.map(\.observation.amount).min() == -20)
        #expect(samples.filter(\.startsSegment).count == 1)
        #expect(samples.map(\.observation.observedAt) == samples.map(\.observation.observedAt).sorted())
    }

    @Test func omittedGapInSamePixelCannotBecomeAConnectingLine() {
        let points = [point(0, 10), point(1, 20), point(50, 15), point(51, 14), point(52, 10)]
        let samples = BalanceChart.samples(points, columns: 1, gap: 2)
        #expect(samples.map(\.observation.observedAt.timeIntervalSince1970) == [0, 1, 52])
        #expect(samples.map(\.startsSegment) == [true, false, true])
    }

    @Test func emptySingleAndDisconnectedReadingsStayHonest() {
        #expect(BalanceChart.samples([], columns: 100, gap: 600).isEmpty)
        let single = BalanceChart.samples([point(5, 0)], columns: 0, gap: 600)
        #expect(single.count == 1 && single[0].startsSegment)
        let points = (0..<1000).map { point(Double($0 * 1000), $0) }
        let samples = BalanceChart.samples(points, columns: 10, gap: 600)
        #expect(samples.count <= 40)
        #expect(samples.allSatisfy { $0.startsSegment })
    }
}
