import SwiftUI
import WaterlineKit

struct BalanceHistoryView: View {
    let entry: AccountEntry
    let model: AppModel
    @State private var observations: [BalanceObservation] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(entry.state.reading?.usage.balances ?? [], id: \.currency) { balance in
                let series = observations.filter {
                    $0.currency == balance.currency && ($0.basis == .postedLedger) == (balance.basis == .postedLedger)
                }
                if !series.isEmpty {
                    Text(
                        AppText.format(
                            balance.basis == .postedLedger ? "Posted credit history · %@" : "7-day balance · %@",
                            balance.currency)
                    ).font(.caption).foregroundStyle(.secondary)
                    BalanceTrend(points: series, gap: model.snapshot.preferences.refreshInterval * 2)
                    if let estimate = BalanceHistory.estimate(
                        observations, accountID: entry.account.id,
                        currency: balance.currency, now: Date(),
                        latestIsFresh: entry.isEnabled(in: model.snapshot.preferences) && balance.basis != .postedLedger
                            && entry.state.hasCurrentResponse
                            && balance.error == nil
                            && balance.isCurrent(
                                at: Date(), fallbackObservation: entry.state.reading?.observedAt ?? .distantPast,
                                interval: model.snapshot.preferences.refreshInterval)
                            && !model.snapshot.historyFailed && series.last?.amount == balance.amount
                            && Date().timeIntervalSince(series.last?.observedAt ?? .distantPast) <= model.snapshot
                                .preferences.refreshInterval * 2
                    ) {
                        Text(
                            AppText.format(
                                "≈ %@ %@/day average decrease",
                                estimate.averageDecreasePerDay.formatted(.number.precision(.fractionLength(0...2))),
                                balance.currency)
                        )
                        .font(.caption).foregroundStyle(.secondary)
                        if let days = estimate.estimatedDaysLeft {
                            Text(
                                AppText.format(
                                    "≈ %@ days left", days.formatted(.number.precision(.fractionLength(0...1))))
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Text(
                            "Net balance change over the observed period; offsetting deposits and charges may be hidden."
                        )
                        .font(.caption2).foregroundStyle(.secondary)
                    } else if balance.basis == .postedLedger {
                        Text(
                            "Posted ledger; current-cycle charges may not be included. No depletion estimate is shown."
                        ).font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("An estimate needs a fresh balance and at least 24 hours of comparable observations.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            if model.snapshot.historyFailed {
                Text("History could not be saved. Current readings are still available.").font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .task(id: model.snapshot.generatedAt) { observations = await model.balanceHistory(for: entry.account.id) }
    }
}

struct BalanceTrend: View {
    let points: [BalanceObservation]
    let gap: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard let first = points.first, let last = points.last else { return }
                let samples = BalanceChart.samples(points, columns: Int(geometry.size.width), gap: gap)
                let amounts = samples.map { NSDecimalNumber(decimal: $0.observation.amount).doubleValue }
                let low = amounts.min() ?? 0, high = amounts.max() ?? 0
                let span = max(1, last.observedAt.timeIntervalSince(first.observedAt))
                for (index, sample) in samples.enumerated() {
                    let point = sample.observation
                    let x = point.observedAt.timeIntervalSince(first.observedAt) / span * geometry.size.width
                    let y =
                        high == low
                        ? geometry.size.height / 2 : (1 - (amounts[index] - low) / (high - low)) * geometry.size.height
                    let position = CGPoint(x: x, y: y)
                    if sample.startsSegment {
                        path.addEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                        path.move(to: position)
                    } else {
                        path.addLine(to: position)
                    }
                }
            }.stroke(.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }.frame(height: 42)
            .accessibilityLabel(AppText.format("Recorded balance history, %@ observations", String(points.count)))
    }
}
