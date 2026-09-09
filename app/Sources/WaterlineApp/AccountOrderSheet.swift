import SwiftUI
import WaterlineKit

struct AccountOrderSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var changing = false
    @State private var selection: AccountID?
    private var entries: [AccountEntry] { Dashboard.overviewAccounts(model.snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account display order").font(.headline)
            Text("Drag accounts to reorder. Changes save automatically.")
                .font(.caption).foregroundStyle(.secondary)
            List(selection: $selection) {
                ForEach(Array(entries.enumerated()), id: \.element.account.id) { index, entry in
                    HStack(spacing: 10) {
                        Text(String(index + 1)).monospacedDigit().foregroundStyle(.secondary).frame(width: 22)
                        ProviderLogo(provider: entry.account.provider).frame(width: 20, height: 20)
                        Text(label(entry)).lineLimit(1)
                        Spacer()
                        Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                    .tag(entry.account.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: Text(AppText.format("Move %@ up", label(entry)))) {
                        move(entry.account.id, by: -1)
                    }
                    .accessibilityAction(named: Text(AppText.format("Move %@ down", label(entry)))) {
                        move(entry.account.id, by: 1)
                    }
                    .moveDisabled(changing)
                }
                .onMove { source, destination in
                    var ids = entries.map(\.account.id)
                    ids.move(fromOffsets: source, toOffset: destination)
                    save(ids)
                }
            }
            .listStyle(.plain)
            .onKeyPress(keys: [.upArrow, .downArrow], phases: .down) { event in
                guard event.modifiers.intersection([.command, .control, .option, .shift]) == .option,
                    let selection
                else { return .ignored }
                move(selection, by: event.key == .upArrow ? -1 : 1)
                return .handled
            }
            .help("Select an account and press Option-Up or Option-Down to reorder.")
            if changing { ProgressView("Saving…").controlSize(.small) }
            if let error = model.error { Text(AppText.text(error)).font(.caption).foregroundStyle(.orange) }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).disabled(changing)
            }
        }.padding(20).frame(width: 460, height: 400)
    }

    private func move(_ id: AccountID, by offset: Int) {
        var ids = entries.map(\.account.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        ids.swapAt(index, index + offset)
        save(ids)
    }

    private func save(_ ids: [AccountID]) {
        guard !changing, ids != entries.map(\.account.id) else { return }
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
