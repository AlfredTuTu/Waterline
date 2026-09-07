import SwiftUI
import WaterlineKit

struct HistoryWindow: View {
    let model: AppModel
    @State private var accountID: AccountID?
    @State private var period = HistoryPeriod.week
    @State private var observations: [BalanceObservation] = []
    @State private var loading = false

    init(model: AppModel) { self.model = model }

    #if WATERLINE_VERIFICATION
        init(model: AppModel, account: AccountID, period: HistoryPeriod, observations: [BalanceObservation]) {
            self.model = model
            _accountID = State(initialValue: account)
            _period = State(initialValue: period)
            _observations = State(initialValue: observations)
        }
    #endif

    private var selection: AccountID? {
        accountID.flatMap { id in model.snapshot.accounts.contains { $0.account.id == id } ? id : nil }
            ?? model.snapshot.accounts.first(where: { !($0.state.reading?.usage.balances.isEmpty ?? true) })?.account.id
            ?? model.snapshot.accounts.first?.account.id
    }
    private var reloadKey: String {
        "\(selection?.rawValue ?? "")/\(period.rawValue)/\(model.snapshot.generatedAt.timeIntervalSince1970)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Picker("Account", selection: Binding(get: { selection }, set: { accountID = $0 })) {
                    if model.snapshot.accounts.isEmpty { Text("No accounts").tag(Optional<AccountID>.none) }
                    ForEach(model.snapshot.accounts, id: \.account.id) { entry in
                        Text(label(entry)).tag(Optional(entry.account.id))
                    }
                }.frame(maxWidth: 390)
                Spacer()
                Picker("Period", selection: $period) {
                    ForEach(HistoryPeriod.allCases, id: \.rawValue) { value in
                        Text(AppText.format("%@ days", String(value.rawValue))).tag(value)
                    }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 210)
            }
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if observations.isEmpty && model.snapshot.historyFailed {
                ContentUnavailableView(
                    "History unavailable", systemImage: "exclamationmark.triangle",
                    description: Text("Current balances remain available. The history file could not be read.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if observations.isEmpty {
                ContentUnavailableView(
                    "No balance history", systemImage: "chart.xyaxis.line",
                    description: Text(
                        "Accepted balance readings will appear here. Quota percentages are not monetary records.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(Set(observations.map(\.currency))).sorted(), id: \.self) { currency in
                            ForEach([false, true], id: \.self) { posted in
                                if observations.contains(where: {
                                    $0.currency == currency && ($0.basis == .postedLedger) == posted
                                }) {
                                    currencySection(currency, posted: posted)
                                }
                            }
                        }
                    }
                }
            }
            if model.snapshot.historyFailed {
                HStack {
                    Text(
                        AppText.text(
                            model.historyRetryError
                                ?? "History could not be saved. Current readings are still available.")
                    ).foregroundStyle(.orange)
                    if model.retryingHistory { ProgressView().controlSize(.small) }
                    Button("Retry") { Task { await model.retryHistoryPersistence() } }
                        .disabled(model.retryingHistory)
                }.font(.caption)
            }
            if let notice = model.snapshot.historyRepairNotice {
                Text(AppText.text(notice)).font(.caption).foregroundStyle(.secondary)
            }
            Text("Balances are original-currency observations, not spending. Different currencies are not combined.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(
            minWidth: 640, maxWidth: .infinity, minHeight: 420, maxHeight: .infinity, alignment: .topLeading
        )
        .task(id: reloadKey) {
            loading = true
            guard let selection else { observations = []; loading = false; return }
            let result = await model.balanceHistory(for: selection, period: period)
            guard !Task.isCancelled else { return }
            observations = result
            loading = false
        }
    }

    private func label(_ entry: AccountEntry) -> String {
        let region = entry.account.region.flatMap { id in
            Registry.adapters.first { type(of: $0).descriptor.provider == entry.account.provider }
                .flatMap { type(of: $0).descriptor.manualRegions.first { $0.id == id }?.label }
        }
        let siblings = model.snapshot.accounts.filter { $0.account.provider == entry.account.provider }
            .sorted { $0.account.id.rawValue < $1.account.id.rawValue }
        let ordinal = siblings.firstIndex { $0.account.id == entry.account.id }.map { String($0 + 1) }
        let nickname = entry.preferences.label ?? (siblings.count > 1 ? ordinal : nil)
        return [entry.account.provider.displayName, nickname, region.map(AppText.text)]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func currencySection(_ currency: String, posted: Bool) -> some View {
        let points = observations.filter { $0.currency == currency && ($0.basis == .postedLedger) == posted }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(currency).font(.headline)
                if posted { Text("Posted credit").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                if let latest = points.last {
                    Text(latest.amount.formatted(.number.precision(.fractionLength(0...4)))).monospacedDigit()
                }
            }
            HStack {
                Text(
                    AppText.format(
                        "Range: %@ – %@", points.map(\.amount).min()?.formatted() ?? "—",
                        points.map(\.amount).max()?.formatted() ?? "—"))
                Spacer()
                Text(AppText.format("%@ observations", String(points.count)))
            }.font(.caption).foregroundStyle(.secondary)
            BalanceTrend(points: points, gap: model.snapshot.preferences.refreshInterval * 2)
            if let first = points.first, let last = points.last {
                HStack {
                    Text(first.observedAt, format: .dateTime.month().day().hour().minute())
                    Spacer()
                    Text(last.observedAt, format: .dateTime.month().day().hour().minute())
                }.font(.caption).foregroundStyle(.secondary)
            }
            Text("Latest 100 observations").font(.subheadline)
            LazyVStack(spacing: 6) {
                ForEach(Array(points.suffix(100).reversed()), id: \.observedAt) { point in
                    HStack {
                        Text(point.observedAt, format: .dateTime.year().month().day().hour().minute())
                        if point.basis == .postedLedger { Text("Posted credit").foregroundStyle(.secondary) }
                        Spacer()
                        Text(point.amount.formatted(.number.precision(.fractionLength(0...4)))).monospacedDigit()
                        Text(currency).foregroundStyle(.secondary)
                    }.font(.caption)
                }
            }
        }
    }
}
