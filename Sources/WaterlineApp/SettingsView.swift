import SwiftUI
import WaterlineKit

struct SettingsView: View {
    let model: AppModel
    @State private var interval: Double = 300
    @State private var warning = 70.0
    @State private var critical = 90.0
    @State private var cny: Decimal = 50
    @State private var usd: Decimal = 10
    @State private var saved = false
    @State private var manualProvider: Provider?
    @State private var accountSearch = ""
    @State private var accountProvider: Provider?
    @State private var showGuide = false
    @AppStorage("connectionGuideCompleted") private var guideCompleted = false

    var body: some View {
        TabView(selection: Binding(get: { model.settingsTab }, set: { model.settingsTab = $0 })) {
            Form {
                LanguageSettings()
                Divider()
                LoginItemSettings()
                Divider()
                SoftwareUpdateSettings()
                Divider()
                Toggle(
                    "Usage notifications",
                    isOn: Binding(
                        get: { model.notifications.enabled },
                        set: { enabled in Task { await model.notifications.setEnabled(enabled) } })
                )
                .disabled(model.notifications.changing)
                Text("New threshold crossings only. At most one alert per account each hour.")
                    .font(.caption).foregroundStyle(.secondary)
                if model.notifications.changing { ProgressView("Updating…").controlSize(.small) }
                if let message = model.notifications.message {
                    Text(LocalizedStringKey(message)).font(.caption).foregroundStyle(.orange)
                }
                Divider()
                Button("Connection guide") { showGuide = true }
            }.padding(12)
                .tabItem { Label("General", systemImage: "gearshape") }.tag("general")
            accounts.tabItem { Label("Accounts", systemImage: "person.crop.circle") }.tag("accounts")
            limits.tabItem { Label("Display & refresh", systemImage: "slider.horizontal.3") }.tag("limits")
            privacy.tabItem { Label("Privacy", systemImage: "hand.raised") }.tag("privacy")
        }
        .padding(18).frame(width: 590, height: 480)
        .disabled(model.isVerification)
        .onAppear { if !guideCompleted { showGuide = true } }
        .sheet(isPresented: $showGuide) {
            ConnectionGuide(model: model) {
                guideCompleted = true
                model.settingsTab = "accounts"
                showGuide = false
            }
        }
        .sheet(isPresented: Binding(get: { manualProvider != nil }, set: { if !$0 { manualProvider = nil } })) {
            if let provider = manualProvider { ManualKeySheet(model: model, provider: provider, accountID: nil) }
        }
        .task(id: model.snapshot.preferences) {
            let preferences = model.snapshot.preferences
            interval = preferences.refreshInterval
            warning = preferences.windowWarning * 100
            critical = preferences.windowCritical * 100
            cny = preferences.balanceThresholds["CNY"] ?? 50
            usd = preferences.balanceThresholds["USD"] ?? 10
        }
    }

    private var accounts: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Accounts").font(.headline)
                if model.snapshot.accounts.isEmpty { Text("No connected accounts.").foregroundStyle(.secondary) }
                HStack {
                    TextField("Search accounts", text: $accountSearch)
                    Picker("Provider", selection: $accountProvider) {
                        Text("All providers").tag(Optional<Provider>.none)
                        ForEach(
                            Provider.allCases.filter { provider in
                                model.snapshot.accounts.contains { $0.account.provider == provider }
                            }, id: \.self
                        ) { provider in
                            Text(provider.displayName).tag(Optional(provider))
                        }
                    }.frame(width: 180)
                }
                if !model.snapshot.accounts.isEmpty && filteredAccounts.isEmpty {
                    Text("No matching accounts.").foregroundStyle(.secondary)
                }
                ForEach(filteredAccounts, id: \.account.id) { entry in
                    AccountSettingsRow(model: model, entry: entry)
                    Divider()
                }
                Text("Sources").font(.headline)
                Text(
                    "Connect reads the tool’s saved login. macOS may ask you to allow access. Background checks never request a dialog."
                )
                .font(.caption).foregroundStyle(.secondary)
                ForEach(
                    Registry.adapters.map { type(of: $0).descriptor.provider }.filter { $0 != .antigravity }, id: \.self
                ) { provider in
                    HStack {
                        Toggle(
                            provider.displayName,
                            isOn: Binding(
                                get: { !model.snapshot.preferences.disabledProviders.contains(provider) },
                                set: { enabled in
                                    Task { await model.setSource(provider, enabled: enabled) }
                                }))
                        Spacer()
                        if Registry.adapters.contains(where: {
                            type(of: $0).descriptor.provider == provider && type(of: $0).descriptor.supportsManualKey
                        }) {
                            Button("Add key") { manualProvider = provider }
                                .disabled(model.snapshot.preferences.disabledProviders.contains(provider))
                        } else {
                            Button("Connect") { Task { await model.connect(provider) } }
                                .disabled(model.snapshot.preferences.disabledProviders.contains(provider))
                        }
                    }
                }
                HStack {
                    Text("Qwen / Bailian")
                    Spacer()
                    Text("Quota lookup not yet supported").foregroundStyle(.secondary)
                }
                Divider()
                OptionalSourcesView(model: model)
                errorMessage
            }.padding(8)
        }
    }

    private var filteredAccounts: [AccountEntry] {
        model.snapshot.accounts.filter { entry in
            let matchesProvider = accountProvider == nil || entry.account.provider == accountProvider
            let description = [
                entry.account.provider.displayName, entry.preferences.label, entry.account.plan, entry.account.region,
            ].compactMap { $0 }.joined(separator: " ")
            return matchesProvider && (accountSearch.isEmpty || description.localizedStandardContains(accountSearch))
        }
    }

    private var limits: some View {
        Form {
            TextField("Refresh interval (seconds)", value: $interval, format: .number)
            Text("60–3600 seconds. Server backoff and signed-out accounts take precedence.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            TextField("Quota warning (%)", value: $warning, format: .number)
            TextField("Quota critical (%)", value: $critical, format: .number)
            TextField("Low balance (CNY)", value: $cny, format: .number)
            TextField("Low balance (USD)", value: $usd, format: .number)
            Text("Each currency is evaluated separately. Thresholds must be positive.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                if saved, model.error == nil { Text("Saved").foregroundStyle(.secondary) }
                Button("Save") {
                    Task {
                        var preferences = model.snapshot.preferences
                        preferences.refreshInterval = interval
                        preferences.windowWarning = warning / 100
                        preferences.windowCritical = critical / 100
                        preferences.balanceThresholds["CNY"] = cny
                        preferences.balanceThresholds["USD"] = usd
                        await model.savePreferences(preferences)
                        saved = model.error == nil
                    }
                }.keyboardShortcut(.defaultAction)
            }
            errorMessage
        }.padding(12)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your account data stays on this Mac").font(.headline)
            Text(
                "Waterline has no backend or telemetry. Saved logins are used only for read-only requests to the corresponding provider."
            )
            ForEach(
                Registry.adapters.map { type(of: $0).descriptor.provider }.filter { $0 != .antigravity }, id: \.self
            ) { provider in
                if let descriptor = Registry.adapters.first(where: { type(of: $0).descriptor.provider == provider })
                    .map({ type(of: $0).descriptor })
                {
                    Text("\(provider.displayName): \(descriptor.allowedHosts.sorted().joined(separator: ", "))")
                }
            }
            Text(
                "Account settings and snapshots are stored in Library/Application Support/Waterline. Waterline never changes another tool’s credentials."
            )
            Text(
                "Source switches stop that source’s discovery and requests. Removing an account keeps it out of automatic discovery until you explicitly connect again."
            )
            if let notice = model.snapshot.historyRepairNotice {
                Text(notice).font(.caption).foregroundStyle(.secondary)
            }
            if model.snapshot.historyFailed {
                Text("Balance history could not be saved.").foregroundStyle(.orange)
                HStack {
                    if model.retryingHistory { ProgressView().controlSize(.small) }
                    Button("Retry history storage") { Task { await model.retryHistoryPersistence() } }
                        .disabled(model.retryingHistory)
                }
            }
            if model.snapshot.pendingSecretCleanup > 0 {
                Text(
                    AppText.format(
                        "%@ saved-key deletion(s) still need cleanup.", String(model.snapshot.pendingSecretCleanup))
                )
                .foregroundStyle(.orange)
                Button("Retry key cleanup") { Task { await model.retrySecretCleanup() } }
            }
            Spacer()
        }.padding(12)
    }

    @ViewBuilder private var errorMessage: some View {
        if let error = model.error { Text(AppText.text(error)).font(.caption).foregroundStyle(.red) }
    }
}

private struct AccountSettingsRow: View {
    let model: AppModel
    let entry: AccountEntry
    @State private var label = ""
    @State private var editingKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.account.provider.displayName).fontWeight(.medium)
                Spacer()
                Toggle(
                    "Enabled",
                    isOn: Binding(
                        get: { entry.preferences.enabled },
                        set: { enabled in
                            Task { await model.setEnabled(entry, enabled: enabled) }
                        })
                ).toggleStyle(.switch).controlSize(.small)
            }
            HStack {
                TextField("Account name", text: $label).onSubmit { Task { await model.rename(entry, label: label) } }
                Button("Rename") { Task { await model.rename(entry, label: label) } }
            }
            if let team = entry.account.teamID {
                Text(AppText.format("Team: %@", team)).font(.caption).foregroundStyle(.secondary)
            }
            if let region = entry.account.region {
                Text(AppText.format("Region: %@", region)).font(.caption).foregroundStyle(.secondary)
            }
            Text(AppText.source(entry.account.credential)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            connectionStatus
            if entry.preferences.enabled && !model.snapshot.preferences.allowsSource(for: entry.account) {
                Text("Enable this credential source to refresh this account.").font(.caption).foregroundStyle(
                    .secondary)
            }
            HStack {
                Toggle(
                    "Show in notch",
                    isOn: Binding(
                        get: { Dashboard.notchAccounts(model.snapshot).contains { $0.account.id == entry.account.id } },
                        set: { _ in
                            Task { await model.toggleNotchAccount(entry.account.id) }
                        }))
                Spacer()
                if entry.account.credential == .manual {
                    Button("Update key") { editingKey = true }
                }
                Button("Reconnect") { Task { await model.reconnect(entry) } }
                    .disabled(entry.operation != .idle)
                Button("Remove", role: .destructive) { Task { await model.remove(entry.account.id) } }
            }.controlSize(.small)
        }
        .onAppear { label = entry.preferences.label ?? "" }
        .sheet(isPresented: $editingKey) {
            ManualKeySheet(model: model, provider: entry.account.provider, accountID: entry.account.id)
        }
    }

    @ViewBuilder private var connectionStatus: some View {
        if entry.operation != .idle {
            ProgressView(LocalizedStringKey(entry.operation == .connecting ? "Connecting…" : "Refreshing…"))
                .controlSize(.small)
        } else {
            switch entry.state {
            case .unavailable(let error), .stale(_, let error):
                Text(AppText.text(error.message)).font(.caption).foregroundStyle(.orange)
            case .partial:
                Text("Partial data").font(.caption).foregroundStyle(.orange)
            case .fresh(let reading):
                Text(AppText.format("Updated %@", reading.observedAt.formatted(date: .omitted, time: .shortened)))
                    .font(.caption).foregroundStyle(.secondary)
            case .pending:
                Text("Checking…").font(.caption).foregroundStyle(.secondary)
            case .expired:
                Text("Awaiting update").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
