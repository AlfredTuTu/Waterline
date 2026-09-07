import Foundation

public struct BalanceChartSample: Sendable {
    public let observation: BalanceObservation
    public let startsSegment: Bool
}

/// Min/max envelope per horizontal pixel. Only drawing is reduced; journal records remain intact.
public enum BalanceChart {
    public static func samples(
        _ points: [BalanceObservation], columns: Int, gap: TimeInterval
    ) -> [BalanceChartSample] {
        guard let first = points.first, let last = points.last else { return [] }
        let count = max(1, min(columns, 4096))
        let span = max(1, last.observedAt.timeIntervalSince(first.observedAt))
        var breaks = [Int](repeating: 0, count: points.count)
        var selected: [Int] = []
        var bucket = -1
        var start = 0
        var minimum = 0
        var maximum = 0
        var end = 0
        func flush() {
            selected.append(contentsOf: Set([start, minimum, maximum, end]).sorted())
        }
        for index in points.indices {
            if index > 0 {
                breaks[index] =
                    breaks[index - 1]
                    + (points[index].observedAt.timeIntervalSince(points[index - 1].observedAt) > gap ? 1 : 0)
            }
            let x = points[index].observedAt.timeIntervalSince(first.observedAt) / span
            let column = min(count - 1, max(0, Int(x * Double(count))))
            if column != bucket {
                if bucket >= 0 { flush() }
                bucket = column
                start = index
                minimum = index
                maximum = index
            }
            end = index
            if points[index].amount < points[minimum].amount { minimum = index }
            if points[index].amount > points[maximum].amount { maximum = index }
        }
        flush()
        return selected.enumerated().map { offset, index in
            BalanceChartSample(
                observation: points[index],
                startsSegment: offset == 0 || breaks[index] != breaks[selected[offset - 1]])
        }
    }
}
