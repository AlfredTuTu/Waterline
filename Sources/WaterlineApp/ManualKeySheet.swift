import SwiftUI
import WaterlineKit

struct ManualKeySheet: View {
    let model: AppModel
    let provider: Provider
    let accountID: AccountID?
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var label = ""
    @State private var saving = false
    @State private var region = ""
    @State private var teamID = ""
    private var requiresTeamID: Bool {
        Registry.adapters.first(where: { type(of: $0).descriptor.provider == provider }).map {
            type(of: $0).descriptor.requiresTeamID
        } ?? false
    }
    private var regions: [ManualRegion] {
        Registry.adapters.first(where: { type(of: $0).descriptor.provider == provider }).map {
            type(of: $0).descriptor.manualRegions
        } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppText.format(accountID == nil ? "Add %@ account" : "Update %@ key", provider.displayName))
                .font(.headline)
            Text(
                "The key is stored in Waterline’s Keychain service. It is never saved in the snapshot or sent to another provider."
            )
            .font(.caption).foregroundStyle(.secondary)
            if !regions.isEmpty {
                if accountID == nil {
                    Picker("Account region", selection: $region) {
                        Text("Choose region").tag("")
                        ForEach(regions) { Text(LocalizedStringKey($0.label)).tag($0.id) }
                    }
                }
                let chosen =
                    accountID.flatMap { id in model.snapshot.accounts.first { $0.account.id == id }?.account.region }
                    ?? region
                if let selection = regions.first(where: { $0.id == chosen }) {
                    Text(AppText.format("Destination: %@", selection.host)).font(.caption)
                }
            } else if let descriptor = Registry.adapters.first(where: { type(of: $0).descriptor.provider == provider })
                .map({ type(of: $0).descriptor })
            {
                Text(AppText.format("Destination: %@", descriptor.allowedHosts.sorted().joined(separator: ", "))).font(
                    .caption)
            }
            if provider == .minimax {
                Text("Use the Subscription Key for this region, not a pay-as-you-go API key.").font(.caption)
                    .foregroundStyle(.secondary)
            }
            if provider == .zhipu {
                Text("Personal Coding Plan key. Team selectors are not yet supported.").font(.caption).foregroundStyle(
                    .secondary)
            }
            if provider == .kimiCode {
                Text("Use a Kimi Code Console key, not a Moonshot platform or gateway key.").font(.caption)
                    .foregroundStyle(.secondary)
            }
            if requiresTeamID {
                Text("Use a Management API key with billing-read access, not an inference key.").font(.caption)
                    .foregroundStyle(.secondary)
                if accountID == nil {
                    TextField("Team ID", text: $teamID)
                } else if let id = accountID,
                    let team = model.snapshot.accounts.first(where: { $0.account.id == id })?.account.teamID
                {
                    Text(AppText.format("Team: %@", team)).font(.caption)
                }
            }
            if accountID == nil { TextField("Account name (optional)", text: $label) }
            SecureField("API key", text: $key).textFieldStyle(.roundedBorder)
            if let error = model.error { Text(AppText.text(error)).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(LocalizedStringKey(saving ? "Saving…" : "Save key")) {
                    Task {
                        saving = true
                        let finished = await model.saveManualKey(
                            provider: provider, id: accountID, value: key, label: label,
                            region: region.isEmpty ? nil : region, teamID: teamID.isEmpty ? nil : teamID)
                        saving = false
                        if finished { key = ""; dismiss() }
                    }
                }.keyboardShortcut(.defaultAction).disabled(
                    saving || key.isEmpty || (accountID == nil && !regions.isEmpty && region.isEmpty)
                        || (accountID == nil && requiresTeamID && teamID.isEmpty))
            }
        }.padding(24).frame(width: 440)
            .onDisappear { key = "" }
    }
}
