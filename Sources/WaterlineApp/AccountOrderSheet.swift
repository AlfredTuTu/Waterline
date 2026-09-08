import SwiftUI
import WaterlineKit

struct AccountOrderSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var changing = false
    private var entries: [AccountEntry] { Dashboard.overviewAccounts(model.snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account display order").font(.headline)
            Text("Left to right, top to bottom. Changes save automatically.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(entries.enumerated()), id: \.element.account.id) { index, entry in
                        HStack(spacing: 10) {
                            Text(String(index + 1)).monospacedDigit().foregroundStyle(.secondary).frame(width: 22)
                            ProviderLogo(provider: entry.account.provider).frame(width: 20, height: 20)
                            Text(label(entry)).lineLimit(1)
                            Spacer()
                            Button {
                                move(entry.account.id, by: -1)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .accessibilityLabel(AppText.format("Move %@ up", label(entry)))
                            .disabled(changing || index == 0)
                            Button {
                                move(entry.account.id, by: 1)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .accessibilityLabel(AppText.format("Move %@ down", label(entry)))
                            .disabled(changing || index == entries.count - 1)
                        }
                    }
                }.padding(.vertical, 6)
            }
            if changing { ProgressView("Saving…").controlSize(.small) }
            if let error = model.error { Text(AppText.text(error)).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("Automatic order") {
                    changing = true
                    Task {
                        await model.setAccountOrder(nil); changing = false
                    }
                }.disabled(changing || model.snapshot.preferences.accountOrder == nil)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).disabled(changing)
            }
        }.padding(20).frame(width: 460, height: 400)
    }

    private func move(_ id: AccountID, by offset: Int) {
        var ids = entries.map(\.account.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        ids.swapAt(index, index + offset)
        changing = true
        Task {
            await model.setAccountOrder(ids); changing = false
        }
    }

    private func label(_ entry: AccountEntry) -> String {
        if let label = entry.preferences.label { return label }
        let siblings = model.snapshot.accounts.filter { $0.account.provider == entry.account.provider }
            .sorted { $0.account.id.rawValue < $1.account.id.rawValue }
        guard siblings.count > 1, let index = siblings.firstIndex(where: { $0.account.id == entry.account.id }) else {
            return entry.account.provider.displayName
        }
        return "\(entry.account.provider.displayName) \(index + 1)"
    }
}
