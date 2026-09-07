import SwiftUI
import WaterlineKit

struct ConnectionGuide: View {
    let model: AppModel
    let continueToAccounts: () -> Void
    @State private var selected: Set<Provider> = [.codex, .claudeCode, .cursor]
    @State private var connecting: Provider?
    @State private var operation: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your accounts, in one place").font(.title2.weight(.semibold))
            Text("Waterline reads usage on this Mac and sends credentials only to the corresponding provider.")
                .foregroundStyle(.secondary)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Saved tool logins are checked automatically. Optional sources stay off until enabled.")
                    Text("Choose the accounts to connect. macOS may ask you to approve each saved login.")
                    Text(
                        "Always Allow can remember access for a consistently signed installation. Development updates may ask again."
                    )
                    ForEach([Provider.codex, .claudeCode, .cursor], id: \.self) { provider in
                        HStack {
                            Toggle(
                                provider.displayName,
                                isOn: Binding(
                                    get: { selected.contains(provider) },
                                    set: { if $0 { selected.insert(provider) } else { selected.remove(provider) } })
                            )
                            .toggleStyle(.checkbox)
                            .disabled(
                                operation != nil || model.snapshot.preferences.disabledProviders.contains(provider))
                            Spacer()
                            if connecting == provider {
                                ProgressView().controlSize(.small)
                            } else {
                                Text(LocalizedStringKey(connectionState(provider))).font(.caption).foregroundStyle(
                                    .secondary)
                            }
                        }
                    }
                    Button("Connect selected accounts") {
                        operation = Task {
                            for provider in [Provider.codex, .claudeCode, .cursor] where selected.contains(provider) {
                                guard !Task.isCancelled else { break }
                                connecting = provider
                                await model.connect(provider)
                            }
                            connecting = nil
                            operation = nil
                        }
                    }.disabled(operation != nil || selected.isEmpty || !model.loaded)

                    Text("Manual keys stay in Waterline’s Keychain service. Choose the key’s region when requested.")
                    Divider()
                    ForEach(Registry.adapters.map { type(of: $0).descriptor }, id: \.provider) { descriptor in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(descriptor.provider.displayName).fontWeight(.medium)
                            Text(LocalizedStringKey(sourceDescription(descriptor))).font(.caption)
                            Text(
                                AppText.format(
                                    "Destination: %@", descriptor.allowedHosts.sorted().joined(separator: ", "))
                            )
                            .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    Divider()
                    Text(
                        "Pause a source to stop its requests. Missing usage stays unavailable; it is never shown as zero."
                    )
                    .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Continue to accounts", action: continueToAccounts).keyboardShortcut(.defaultAction)
                    .disabled(operation != nil)
            }
        }.padding(24).frame(width: 520, height: 520)
            .onAppear { selected.subtract(model.snapshot.preferences.disabledProviders) }
            .onDisappear { operation?.cancel() }
    }

    private func connectionState(_ provider: Provider) -> String {
        if model.snapshot.preferences.disabledProviders.contains(provider) { return "Accounts paused" }
        let accounts = model.snapshot.accounts.filter { $0.account.provider == provider }
        if accounts.isEmpty { return "Not connected" }
        return accounts.allSatisfy { $0.state.hasCurrentResponse } ? "Connected" : "Needs attention"
    }

    private func sourceDescription(_ descriptor: ProviderDescriptor) -> String {
        switch descriptor.provider {
        case .codex: "Codex’s saved local login file. API-key-only logins do not report subscription quota here."
        case .claudeCode: "Claude Code’s saved Keychain login, or its credentials file when no Keychain item exists."
        case .cursor: "Cursor’s local login database, opened read-only."
        case .deepseek: "Manual key, or explicitly enabled environment and Claude Code settings sources."
        default:
            descriptor.supportsManualKey
                ? "Add a provider key in Accounts. Its required type and destination are shown before saving."
                : "Connect the provider’s saved login from Accounts."
        }
    }
}
