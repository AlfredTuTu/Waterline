import SwiftUI
import WaterlineKit

struct AccountConnectionsView: View {
    let model: AppModel
    @State private var accountSearch = ""
    @State private var showAccountOrder = false

    var body: some View {
        accounts
            .padding(18).frame(width: 590, height: 480)
            .disabled(model.isVerification)
            .sheet(isPresented: $showAccountOrder) { AccountOrderSheet(model: model) }

    }

    private var accounts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Manage accounts").font(.headline)
                    Spacer()
                    Button("Account display order") { showAccountOrder = true }
                        .disabled(model.snapshot.accounts.count < 2)
                }
                if model.snapshot.accounts.count > 8 || !accountSearch.isEmpty {
                    TextField("Search accounts", text: $accountSearch)
                }
                ForEach(filteredAccounts, id: \.account.id) { entry in
                    AccountSettingsRow(model: model, entry: entry)
                    Divider()
                }
                ForEach(missingProviders, id: \.self) { provider in
                    MissingProviderRow(model: model, provider: provider)
                    Divider()
                }
                if filteredAccounts.isEmpty && missingProviders.isEmpty {
                    Text("No matching accounts.").foregroundStyle(.secondary)
                }
                errorMessage
            }.padding(8)
        }
    }

    private var filteredAccounts: [AccountEntry] {
        Dashboard.overviewAccounts(model.snapshot).filter { entry in
            let description = [entry.account.provider.displayName, entry.preferences.label, entry.account.plan]
                .compactMap { $0 }.joined(separator: " ")
            return accountSearch.isEmpty || description.localizedStandardContains(accountSearch)
        }
    }

    private var missingProviders: [Provider] {
        Registry.adapters.map { type(of: $0).descriptor.provider }.filter { provider in
            !model.snapshot.accounts.contains { $0.account.provider == provider }
                && (accountSearch.isEmpty || provider.displayName.localizedStandardContains(accountSearch))
        }
    }

    @ViewBuilder private var errorMessage: some View {
        if let error = model.error { Text(AppText.text(error)).font(.caption).foregroundStyle(.red) }
    }
}

private struct AccountSettingsRow: View {
    let model: AppModel
    let entry: AccountEntry
    private var sourceAllowed: Bool { model.snapshot.preferences.allowsSource(for: entry.account) }
    private var selected: Bool {
        Dashboard.notchAccounts(model.snapshot).contains { $0.account.id == entry.account.id }
    }
    private var busy: Bool { entry.operation != .idle }

    var body: some View {
        HStack(spacing: 12) {
            ProviderLogo(provider: entry.account.provider).frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.preferences.label ?? entry.account.provider.displayName).fontWeight(.semibold)
                    if let plan = entry.account.plan {
                        Text(plan.uppercased()).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                connectionStatus
            }
            Spacer()
            if !sourceAllowed {
                Button("Enable source") { Task { await model.connectManagedProvider(entry.account.provider) } }
                    .disabled(busy)
            } else if !entry.preferences.enabled {
                Button("Resume account") { Task { await model.setEnabled(entry, enabled: true) } }.disabled(busy)
            } else if needsConnect {
                Button("Connect") { Task { await model.reconnect(entry) } }.disabled(busy)
            }
            Button {
                Task { await model.toggleNotchAccount(entry.account.id) }
            } label: {
                Image(systemName: selected ? "pin.fill" : "pin").frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(Text(LocalizedStringKey(selected ? "Remove from notch" : "Show in notch")))
            .accessibilityLabel(Text(LocalizedStringKey(selected ? "Remove from notch" : "Show in notch")))
        }
        .padding(.vertical, 7)
    }

    private var needsConnect: Bool {
        switch entry.state {
        case .unavailable(let error), .stale(_, let error): error.needsConnect
        default: false
        }
    }

    @ViewBuilder private var connectionStatus: some View {
        if busy {
            ProgressView(LocalizedStringKey(entry.operation == .connecting ? "Connecting…" : "Refreshing…"))
                .controlSize(.small)
        } else if !entry.preferences.enabled || !sourceAllowed {
            Text("Paused").font(.caption).foregroundStyle(.secondary)
        } else {
            switch entry.state {
            case .unavailable(let error), .stale(_, let error):
                Text(AppText.text(error.message)).font(.caption).foregroundStyle(.orange)
            case .partial: Text("Partial data").font(.caption).foregroundStyle(.orange)
            case .fresh(let reading):
                Text(LocalizedStringKey(reading.usage.unsupportedReason == nil ? "Connected" : "Usage unavailable"))
                    .font(.caption).foregroundStyle(.secondary)
            case .pending: Text("Checking…").font(.caption).foregroundStyle(.secondary)
            case .expired: Text("Awaiting update").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct MissingProviderRow: View {
    let model: AppModel
    let provider: Provider
    @State private var connecting = false
    @State private var attempted = false
    var body: some View {
        HStack(spacing: 12) {
            ProviderLogo(provider: provider).frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName).fontWeight(.semibold)
                Text(LocalizedStringKey(attempted ? "Sign in to the app or CLI, then connect again." : "Not connected"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if connecting { ProgressView().controlSize(.small) }
            Button("Connect") {
                connecting = true
                Task {
                    await model.connectManagedProvider(provider)
                    attempted = true; connecting = false
                }
            }.disabled(connecting || !model.loaded)
        }.padding(.vertical, 7)
    }
}
