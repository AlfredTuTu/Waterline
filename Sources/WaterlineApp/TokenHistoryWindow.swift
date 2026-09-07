import SwiftUI
import UniformTypeIdentifiers
import WaterlineKit

struct TokenHistoryWindow: View {
    private enum Recovery { case load, chooseFile, importFile(URL) }
    let model: AppModel
    @State private var recovery = Recovery.load
    @State private var sources: [TokenImport] = []
    @State private var days = 30
    @State private var choosingFile = false
    @State private var loading = true
    @State private var importing = false
    @State private var operation: Task<Void, Never>?
    @State private var error: String?
    @State private var status: String?

    init(model: AppModel) { self.model = model }
    #if WATERLINE_VERIFICATION
        init(model: AppModel, sources: [TokenImport], days: Int = 30) {
            self.model = model
            _sources = State(initialValue: sources)
            _days = State(initialValue: days)
            _loading = State(initialValue: false)
        }
    #endif

    private var samples: [CodexTokenSample] {
        let cutoff = days == 0 ? Date.distantPast : Date().addingTimeInterval(-Double(days) * 86400)
        return sources.flatMap(\.samples).filter { $0.observedAt >= cutoff && $0.observedAt <= Date() }
            .sorted { $0.observedAt < $1.observedAt }
    }

    var body: some View {
        let selected = samples
        let valuation = TokenReferenceValuation.summarize(selected)
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Local Token records").font(.title2)
                Spacer()
                if importing {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { operation?.cancel() }
                }
                Button("Import Codex log") { choosingFile = true }.disabled(importing || !model.loaded)
            }
            Picker("Period", selection: $days) {
                ForEach([7, 30, 90], id: \.self) { Text(AppText.format("%@ days", String($0))).tag($0) }
                Text("All records").tag(0)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 320)
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selected.isEmpty {
                ContentUnavailableView(
                    "No Token records", systemImage: "doc.text.magnifyingglass",
                    description: Text(
                        "Import a Codex JSONL log to retain its observed usage. The source file stays unchanged.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(
                            AppText.text(
                                valuation.pricedRecords < valuation.totalRecords
                                    ? "Priced portion (reference)" : "Reference API value")
                        ).font(.subheadline)
                        if let amount = valuation.amount {
                            Text(
                                amount > 0 && amount < Decimal(1) / 100
                                    ? "< USD 0.01" : "≈ USD " + amount.formatted(.number.precision(.fractionLength(2)))
                            ).font(.title2)
                                .foregroundStyle(.blue)
                        } else {
                            Text("—").font(.title2)
                        }
                        Spacer()
                        Text(
                            AppText.format(
                                "Priced %@ of %@ records", String(valuation.pricedRecords),
                                String(valuation.totalRecords))
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(
                            AppText.format(
                                "Standard base API reference %@; excludes regional uplifts and tools, not a bill.",
                                TokenReferenceValuation.reviewedOn))
                        Link("Pricing source", destination: TokenReferenceValuation.sourceURL)
                    }.font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 30) {
                    summary("Input (includes cache)", selected, \.input)
                    summary("Cached input (subset)", selected, \.cachedInput)
                    summary("Output", selected, \.output)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        Text("Latest 100 observations").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            Text("Time").frame(width: 160, alignment: .leading)
                            Text("Model").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Input").frame(width: 100, alignment: .trailing)
                            Text("Output").frame(width: 80, alignment: .trailing)
                        }.font(.caption).foregroundStyle(.secondary)
                        ForEach(Array(selected.suffix(100).reversed())) { sample in
                            HStack(spacing: 14) {
                                Text(sample.observedAt, format: .dateTime.year().month().day().hour().minute())
                                    .frame(width: 160, alignment: .leading)
                                VStack(alignment: .leading) {
                                    Text(sample.model ?? AppText.text("Unknown model")).lineLimit(1)
                                    Text(AppText.format("Local task %@", String(sample.threadID.prefix(8))))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                Text(sample.usage.input.formatted()).monospacedDigit().frame(
                                    width: 100, alignment: .trailing)
                                Text(sample.usage.output.formatted()).monospacedDigit().frame(
                                    width: 80, alignment: .trailing)
                            }.font(.caption)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(
                                    AppText.format(
                                        "%@, %@, input %@, output %@",
                                        sample.observedAt.formatted(), sample.model ?? AppText.text("Unknown model"),
                                        sample.usage.input.formatted(), sample.usage.output.formatted()))
                        }
                    }
                }
            }
            if sources.contains(where: { $0.coverageGaps > 0 || $0.incompleteTail }) {
                Text("Some imported logs have coverage gaps. Counts include observed intervals only.")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let status { Text(AppText.text(status)).font(.caption).foregroundStyle(.secondary) }
            if let error {
                HStack {
                    Text(AppText.text(error)).font(.caption).foregroundStyle(.orange)
                    Button("Retry") {
                        switch recovery {
                        case .load: Task { await reload() }
                        case .chooseFile: choosingFile = true
                        case .importFile(let url): beginImport(url)
                        }
                    }.disabled(importing)
                }
            }
            Text("Local task usage is not an account bill. Unmatched records stay unpriced; accounts are not assigned.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(minWidth: 700, maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
        .task(id: model.loaded) { if model.loaded { await reload() } }
        .onDisappear { operation?.cancel() }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.item]) { result in
            switch result {
            case .success(let url): beginImport(url)
            case .failure(let failure):
                if (failure as NSError).code != CocoaError.userCancelled.rawValue {
                    error = "Could not open the selected log."
                    recovery = .chooseFile
                }
            }
        }
    }

    private func summary(
        _ title: LocalizedStringKey, _ samples: [CodexTokenSample], _ key: KeyPath<CodexTokenCounters, Int64>
    ) -> some View {
        let total = samples.reduce(Decimal.zero) { $0 + Decimal($1.usage[keyPath: key]) }
        return VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(total.formatted()).font(.title2).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func reload() async {
        recovery = .load
        loading = true
        defer { loading = false }
        do { sources = try await model.tokenHistory(); error = nil } catch {
            self.error = "Could not read Token records. The saved file was preserved."
        }
    }
    private func beginImport(_ url: URL) {
        guard !importing else { return }
        importing = true; error = nil; status = nil
        recovery = .importFile(url)
        operation = Task {
            defer { importing = false; operation = nil }
            do {
                let result = try await model.importCodexLog(url)
                await reload()
                status = AppText.format("Added %@ observed records.", String(result.addedSamples))
            } catch is CancellationError { status = "Import cancelled." } catch TokenLedgerError.conflictingSource {
                error = "This log conflicts with saved records or omits earlier records. Nothing was replaced."
            } catch TokenLogError.ambiguousOwnership {
                error = "Inherited or mixed task logs are not yet supported."
            } catch TokenLedgerError.capacity {
                error = "Token records exceed the supported storage size. The import was not saved."
            } catch {
                self.error = "Could not import this log. Check its format and data-folder access."
            }
        }
    }
}
