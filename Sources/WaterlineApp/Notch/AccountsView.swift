import SwiftUI
import WaterlineKit

struct AccountsView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    let model: AppModel
    let width: CGFloat
    let keyboardActive: Bool
    let navigation: AccountNavigationRequest
    let close: () -> Void
    @State private var selectedAccount: AccountID?
    @State private var pointerInside = false
    @State private var frozenOrder: [AccountID] = []
    @State private var navigationUnavailable = false
    @State private var savingNotchSelection = false

    private func accent(_ provider: Provider) -> Color {
        switch provider {
        case .claudeCode: Color(red: 0.86, green: 0.57, blue: 0.43)
        case .codex: Color(red: 0.34, green: 0.70, blue: 0.94)
        case .cursor: Color(red: 0.72, green: 0.63, blue: 0.90)
        case .kimiCode, .moonshot: Color(red: 0.40, green: 0.78, blue: 0.72)
        case .deepseek: Color(red: 0.46, green: 0.60, blue: 0.98)
        case .zhipu, .qwen: Color(red: 0.68, green: 0.61, blue: 0.94)
        case .minimax: Color(red: 0.91, green: 0.57, blue: 0.67)
        case .xai, .grok: Color(red: 0.74, green: 0.81, blue: 0.87)
        case .antigravity: Color(red: 0.57, green: 0.75, blue: 0.93)
        }
    }

    init(
        model: AppModel, width: CGFloat, keyboardActive: Bool, navigation: AccountNavigationRequest,
        close: @escaping () -> Void
    ) {
        self.model = model
        self.width = width
        self.keyboardActive = keyboardActive
        self.navigation = navigation
        self.close = close
        let unavailable =
            AccountNavigation.resolve(navigation.accountID, accounts: model.snapshot.accounts, loading: !model.loaded)
            == .unavailable
        _selectedAccount = State(initialValue: unavailable ? nil : navigation.accountID)
        _navigationUnavailable = State(initialValue: unavailable)
        #if WATERLINE_VERIFICATION
            if CommandLine.arguments.contains("--verification-detail") {
                _selectedAccount = State(
                    initialValue: model.snapshot.accounts.first { $0.account.provider == .claudeCode }?.account.id)
            }
        #endif
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            if navigationUnavailable {
                Text("Could not open this account.").font(.caption).foregroundStyle(.orange).padding(.bottom, 8)
            }
            if selectedAccount == nil {
                HStack(spacing: 16) {
                    Text("Overview").foregroundStyle(.white)
                    Text(AppText.format("%@ accounts", String(model.snapshot.accounts.count)))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Manage accounts") {
                        model.settingsTab = "accounts"
                        close(); NSApplication.shared.activate(); openSettings()
                    }
                    .foregroundStyle(Color.gray)
                    .disabled(model.isVerification)
                }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).padding(.bottom, 18)
            }
            HookActivityBanner()
            ScrollView {
                if waitingForAccount || (!model.loaded && model.snapshot.accounts.isEmpty) {
                    Text("Loading account…").foregroundStyle(.secondary).padding(.vertical, 24)
                } else if model.snapshot.accounts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Connect your accounts").font(.title3.weight(.semibold))
                        Text("Open Settings to connect your coding tools, then refresh to see their usage.")
                            .foregroundStyle(.secondary)
                    }.padding(.vertical, 24)
                } else if let selectedAccount,
                    let entry = model.snapshot.accounts.first(where: { $0.account.id == selectedAccount })
                {
                    account(entry, detail: true)
                } else {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: 28, alignment: .topLeading), count: accountColumns
                        ),
                        alignment: .leading,
                        spacing: 28
                    ) {
                        ForEach(visibleAccounts, id: \.account.id) { entry in account(entry, detail: false) }
                    }
                }
                ForEach(model.snapshot.sourceFailures, id: \.provider) { failure in
                    Text(AppText.format("%@: source could not be read.", failure.provider.displayName)).foregroundStyle(
                        .orange)
                }
            }
            .scrollIndicators(.visible)
            Rectangle().fill(.white.opacity(0.10)).frame(height: 1).padding(.top, 15)
            HStack(spacing: 14) {
                if selectedAccount != nil {
                    Button {
                        selectedAccount = nil
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Back to overview").accessibilityLabel("Back to overview")
                }
                Button {
                    close(); NSApplication.shared.activate(); openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .disabled(model.isVerification)
                .help("Settings").accessibilityLabel("Settings")
                notchAccountMenu
                Menu("Waterline") {
                    Button("Collapse island", action: close).keyboardShortcut(.escape, modifiers: [])
                    Button("Balance history") {
                        close()
                        NSApplication.shared.activate(); openWindow(id: "balance-history")
                    }
                    Button("Token records") {
                        close()
                        NSApplication.shared.activate(); openWindow(id: "token-history")
                    }
                    Divider()
                    Button("Quit Waterline") { NSApplication.shared.terminate(nil) }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("App menu")
                Spacer()
                if model.refreshing {
                    ProgressView().controlSize(.mini)
                } else if model.hasProblems || !model.snapshot.accounts.isEmpty {
                    Circle().fill(model.hasProblems ? Color.orange : Color.green).frame(width: 6, height: 6)
                }
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(model.refreshing).help("Refresh").accessibilityLabel("Refresh")
            }
            .foregroundStyle(.white.opacity(0.65))
            .buttonStyle(.plain)
            .padding(.top, 13)
            if let error = model.error {
                Text(AppText.text(error)).font(.caption).foregroundStyle(.orange).padding(.top, 8)
            }
            if model.snapshot.historyFailed {
                Text("History could not be saved; latest balances are available.").font(.caption).foregroundStyle(
                    .orange)
            }
            if model.snapshot.storageFailed { Text("Changes could not be saved.").foregroundStyle(.orange) }
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 18)
        .frame(width: width)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onChange(of: navigation.requestID) { _, _ in
            resolveSelection(navigation.accountID)
        }
        .onChange(of: model.loaded) { _, _ in resolveSelection(selectedAccount) }
        .onHover { inside in
            if inside && !pointerInside && !keyboardActive { frozenOrder = preferredAccounts.map(\.account.id) }
            pointerInside = inside
        }
        .onChange(of: keyboardActive, initial: true) { _, active in
            if active && !pointerInside { frozenOrder = preferredAccounts.map(\.account.id) }
        }
        .onChange(of: model.snapshot.accounts.map(\.account.id)) { _, ids in
            if pointerInside || keyboardActive {
                frozenOrder = Dashboard.preservingOrder(preferredAccounts, ids: frozenOrder).map(\.account.id)
            }
            if selectedAccount != nil { resolveSelection(selectedAccount) }
        }
    }

    private var notchAccountMenu: some View {
        Menu {
            Toggle(
                "Automatic",
                isOn: Binding(
                    get: { model.snapshot.preferences.notchAccountIDs == nil },
                    set: { automatic in
                        saveNotchSelection(automatic ? nil : Dashboard.notchAccounts(model.snapshot).map(\.account.id))
                    }
                ))
            Divider()
            ForEach(model.snapshot.accounts.filter { $0.isEnabled(in: model.snapshot.preferences) }, id: \.account.id) {
                entry in
                let selected = Dashboard.notchAccounts(model.snapshot).contains { $0.account.id == entry.account.id }
                Toggle(
                    accountLabel(entry),
                    isOn: Binding(
                        get: { selected },
                        set: { _ in
                            savingNotchSelection = true
                            Task {
                                await model.toggleNotchAccount(entry.account.id)
                                savingNotchSelection = false
                            }
                        }
                    )
                )
            }
        } label: {
            Image(systemName: model.snapshot.preferences.notchAccountIDs == nil ? "pin" : "pin.fill")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(savingNotchSelection || model.isVerification)
        .help("Accounts in notch")
        .accessibilityLabel("Accounts in notch")
    }

    private func saveNotchSelection(_ ids: [AccountID]?) {
        savingNotchSelection = true
        Task {
            await model.setNotchAccounts(ids)
            savingNotchSelection = false
        }
    }

    private var waitingForAccount: Bool {
        if case .loading = AccountNavigation.resolve(
            selectedAccount, accounts: model.snapshot.accounts, loading: !model.loaded)
        {
            return true
        }
        return false
    }

    private func resolveSelection(_ requested: AccountID?) {
        switch AccountNavigation.resolve(requested, accounts: model.snapshot.accounts, loading: !model.loaded) {
        case .detail(let id), .loading(let id): selectedAccount = id; navigationUnavailable = false
        case .overview: selectedAccount = nil; navigationUnavailable = false
        case .unavailable: selectedAccount = nil; navigationUnavailable = true
        }
    }

    @ViewBuilder private func account(_ entry: AccountEntry, detail: Bool) -> some View {
        VStack(alignment: .leading, spacing: detail ? 22 : 12) {
            HStack(spacing: detail ? 9 : 6) {
                ProviderLogo(provider: entry.account.provider).frame(width: 20, height: 20)
                Button {
                    selectedAccount = selectedAccount == entry.account.id ? nil : entry.account.id
                } label: {
                    Text(accountLabel(entry)).font(.system(size: 14, weight: .semibold))
                        .lineLimit(1).truncationMode(.tail).help(accountLabel(entry))
                }.buttonStyle(.plain).help("Account details")
                if let plan = entry.state.reading?.usage.planLabel {
                    Text(plan.uppercased()).font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                        .help(plan)
                        .tracking(0.8).foregroundStyle(.white.opacity(0.52))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.08)))
                }
                if let region = entry.account.region,
                    let descriptor = Registry.adapters.first(where: {
                        type(of: $0).descriptor.provider == entry.account.provider
                    }).map({ type(of: $0).descriptor }),
                    let label = descriptor.manualRegions.first(where: { $0.id == region })?.label
                {
                    Text(LocalizedStringKey(label)).font(.system(size: 10)).foregroundStyle(.secondary)
                        .lineLimit(1).help(AppText.text(label))
                }
                if model.snapshot.preferences.notchAccountIDs?.contains(entry.account.id) == true {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary)
                }
                if case .partial = entry.state {
                    Text("Partial").font(.system(size: 9, weight: .medium)).foregroundStyle(.orange)
                        .fixedSize()
                        .help("Some usage data is unavailable.")
                }
                if !entry.isEnabled(in: model.snapshot.preferences) {
                    Text("Paused").font(.caption).foregroundStyle(.secondary)
                }
                Menu {
                    let notchAccounts = Dashboard.notchAccounts(model.snapshot)
                    let shownInNotch = notchAccounts.contains { $0.account.id == entry.account.id }
                    Button(LocalizedStringKey(shownInNotch ? "Remove from notch" : "Show in notch")) {
                        Task { await model.toggleNotchAccount(entry.account.id) }
                    }
                    Button(LocalizedStringKey(entry.preferences.enabled ? "Pause account" : "Resume account")) {
                        Task { await model.setEnabled(entry, enabled: !entry.preferences.enabled) }
                    }
                    if entry.state.reading?.usage.unsupportedReason == nil {
                        Button("Reconnect") { Task { await model.reconnect(entry) } }
                    }
                    Button("Remove", role: .destructive) { Task { await model.remove(entry.account.id) } }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton).fixedSize().help("Account actions")
                .disabled(model.isVerification)
                Spacer()
                if let url = Registry.adapters.first(where: {
                    type(of: $0).descriptor.provider == entry.account.provider
                })
                .map({ type(of: $0).descriptor.consoleURL(for: entry.account.region) }) {
                    Link(destination: url) { Image(systemName: "arrow.up.right") }
                        .disabled(model.isVerification)
                        .foregroundStyle(.secondary).help("Open console").accessibilityLabel("Open console")
                }
            }
            if let reading = entry.state.reading {
                let amountWindows = reading.usage.quotaWindows.filter { $0.unit == "USD" && $0.usedFraction == nil }
                let detailGroups = Dashboard.detailWindowGroups(reading.usage)
                    .map { $0.filter { !($0.unit == "USD" && $0.usedFraction == nil) } }
                    .filter { !$0.isEmpty }
                if let reason = reading.usage.unsupportedReason {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Not supported").font(.system(size: 13, weight: .medium))
                        Text(AppText.text(reason)).font(.caption).foregroundStyle(.white.opacity(0.60))
                    }
                } else if detail {
                    VStack(spacing: 20) {
                        ForEach(Array(detailGroups.enumerated()), id: \.offset) { _, windows in
                            LazyVGrid(
                                columns: Array(
                                    repeating: GridItem(.flexible(), spacing: 22, alignment: .topLeading),
                                    count: min(2, windows.count)),
                                spacing: 20
                            ) {
                                ForEach(Array(windows.enumerated()), id: \.offset) { _, window in
                                    metric(
                                        window, provider: entry.account.provider,
                                        fresh: isLive(entry)
                                            && window.isCurrent(
                                                at: Date(), fallbackObservation: reading.observedAt,
                                                interval: model.snapshot.preferences.refreshInterval)
                                    )
                                }
                            }
                        }
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 22, alignment: .topLeading),
                                count: min(2, max(1, reading.usage.balances.count))),
                            spacing: 20
                        ) {
                            ForEach(reading.usage.balances, id: \.currency) { balance in
                                let current =
                                    isLive(entry)
                                    && balance.isCurrent(
                                        at: Date(), fallbackObservation: reading.observedAt,
                                        interval: model.snapshot.preferences.refreshInterval)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(
                                        balance.basis == .postedLedger
                                            ? AppText.format("Posted prepaid credit · %@", balance.currency)
                                            : balance.currency
                                    ).font(.caption).foregroundStyle(.secondary)
                                    Text(balance.amount.description).font(.system(size: 23, weight: .medium))
                                        .monospacedDigit()
                                        .foregroundStyle(current ? Color.white : .gray)
                                    if !current {
                                        Text(
                                            AppText.format(
                                                "Earlier reading · %@",
                                                (balance.observedAt ?? reading.observedAt).formatted(
                                                    date: .omitted, time: .shortened))
                                        )
                                        .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    overviewMetrics(entry, reading: reading)
                }
                if detail && !amountWindows.isEmpty {
                    DisclosureGroup("Billing details") {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(amountWindows, id: \.id) { window in
                                metric(
                                    window, provider: entry.account.provider,
                                    fresh: isLive(entry)
                                        && window.isCurrent(
                                            at: Date(), fallbackObservation: reading.observedAt,
                                            interval: model.snapshot.preferences.refreshInterval)
                                )
                            }
                        }.padding(.top, 8)
                    }.font(.caption).foregroundStyle(.secondary)
                }
                if !detail, reading.usage.quotaWindows.count > Dashboard.overviewWindows(reading.usage).count {
                    Button(
                        AppText.format(
                            "+%@ more items",
                            String(reading.usage.quotaWindows.count - Dashboard.overviewWindows(reading.usage).count))
                    ) {
                        selectedAccount = entry.account.id
                    }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
                }
                if detail {
                    ForEach(reading.usage.componentFailures, id: \.id) { failure in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(
                                AppText.format(
                                    "%@ · %@", AppText.text(reading.usage.label(for: failure)),
                                    AppText.text(failure.error.message))
                            )
                            .font(.caption).foregroundStyle(.orange)
                            DisclosureGroup("Diagnostic details") {
                                Text(AppText.format("Component: %@", failure.id))
                                if case .schemaChanged(let field) = failure.error {
                                    Text(AppText.format("Field: %@", field))
                                }
                            }.font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    if !reading.usage.componentFailures.isEmpty, let deadline = entry.schedule?.serverDeadline,
                        deadline > Date()
                    {
                        Text(
                            AppText.format(
                                "Next allowed refresh: %@", deadline.formatted(date: .abbreviated, time: .shortened))
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if selectedAccount == entry.account.id {
                    if !reading.usage.balances.isEmpty { BalanceHistoryView(entry: entry, model: model) }

                }
            }
            switch entry.state {
            case .pending: Text("Checking…").foregroundStyle(.secondary)
            case .unavailable(let error):
                connectionError(error, entry: entry)
            case .stale(_, let error):
                Text("Showing the previous reading").foregroundStyle(.secondary)
                connectionError(error, entry: entry)
            case .expired: Text("Earlier reading · awaiting update").foregroundStyle(.secondary)
            case .partial:
                if detail { Text("Partial data · some readings are older").foregroundStyle(.orange) }
            case .fresh: EmptyView()
            }
        }
    }

    private func overviewMetrics(_ entry: AccountEntry, reading: Reading) -> some View {
        let windows = Dashboard.overviewWindows(
            reading.usage, now: Date(), fallbackObservation: reading.observedAt,
            interval: model.snapshot.preferences.refreshInterval)
        return VStack(alignment: .leading, spacing: 8) {
            if let primary = windows.first {
                metric(
                    primary, provider: entry.account.provider,
                    fresh: isLive(entry)
                        && primary.isCurrent(
                            at: Date(), fallbackObservation: reading.observedAt,
                            interval: model.snapshot.preferences.refreshInterval)
                )
            }
            ForEach(Array(windows.dropFirst().enumerated()), id: \.offset) { _, window in
                let current =
                    isLive(entry)
                    && window.isCurrent(
                        at: Date(), fallbackObservation: reading.observedAt,
                        interval: model.snapshot.preferences.refreshInterval)
                HStack {
                    Text(AppText.text(window.label)).lineLimit(1).layoutPriority(-1)
                    if !current { Text("Awaiting update").font(.caption2).fixedSize() }
                    Spacer()
                    if let fraction = window.usedFraction {
                        Text(fraction, format: .percent.precision(.fractionLength(0...1))).monospacedDigit()
                    } else if let amount = Dashboard.usageAmount(window) {
                        Text(amount).monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(current ? Color.white : .gray)
                .accessibilityElement(children: .combine)
            }
            ForEach(reading.usage.balances, id: \.currency) { balance in
                let current =
                    isLive(entry)
                    && balance.isCurrent(
                        at: Date(), fallbackObservation: reading.observedAt,
                        interval: model.snapshot.preferences.refreshInterval)
                let label =
                    balance.basis == .postedLedger
                    ? AppText.format("Posted prepaid credit · %@", balance.currency) : balance.currency
                if windows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label).font(.caption).foregroundStyle(.secondary)
                        Text(balance.amount.description).font(.system(size: 23, weight: .medium)).monospacedDigit()
                    }.foregroundStyle(current ? Color.white : .gray)
                } else {
                    HStack {
                        Text(label).foregroundStyle(.secondary)
                        Spacer()
                        Text(balance.amount.description).monospacedDigit()
                    }.font(.system(size: 13, weight: .medium)).foregroundStyle(current ? Color.white : .gray)
                }
                if !current {
                    Text(
                        AppText.format(
                            "Earlier reading · %@",
                            (balance.observedAt ?? reading.observedAt).formatted(date: .omitted, time: .shortened))
                    )
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func connectionError(_ error: FetchError, entry: AccountEntry) -> some View {
        if case .schemaChanged = error, entry.account.optionalCredentialSource != nil {
            Text("Credential source could not be read.").font(.caption).foregroundStyle(.orange)
        } else {
            Text(AppText.text(error.message)).font(.caption).foregroundStyle(.orange)
        }
        if let deadline = entry.schedule?.serverDeadline, deadline > Date() {
            Text(AppText.format("Next allowed refresh: %@", deadline.formatted(date: .abbreviated, time: .shortened)))
                .font(.caption).foregroundStyle(.secondary)
        }
        if entry.operation == .connecting {
            ProgressView("Connecting…").controlSize(.small)
        } else if error.needsConnect {
            if entry.account.optionalCredentialSource != nil {
                Text("Check the source configuration, then check this source again.").font(.caption).foregroundStyle(
                    .secondary)
                Button("Check source") { Task { await model.reconnect(entry) } }.buttonStyle(.bordered)
            } else if entry.account.credential == .manual && error != .keychainLocked {
                Button("Update key in Settings") {
                    close(); NSApplication.shared.activate(); openSettings()
                }.buttonStyle(.bordered)
            } else {
                Text("Connect reads the saved login. macOS may ask for access.").font(.caption).foregroundStyle(
                    .secondary)
                Button("Connect") { Task { await model.reconnect(entry) } }.buttonStyle(.bordered)
            }
        }
    }

    private var visibleAccounts: [AccountEntry] {
        Dashboard.overviewAccounts(model.snapshot, frozenIDs: pointerInside || keyboardActive ? frozenOrder : nil)
    }

    private var preferredAccounts: [AccountEntry] {
        Dashboard.ordered(model.snapshot.accounts, preferences: model.snapshot.preferences)
    }

    private func accountLabel(_ entry: AccountEntry) -> String {
        if let label = entry.preferences.label { return label }
        let siblings = model.snapshot.accounts.filter { $0.account.provider == entry.account.provider }
            .sorted { $0.account.id.rawValue < $1.account.id.rawValue }
        guard siblings.count > 1, let index = siblings.firstIndex(where: { $0.account.id == entry.account.id }) else {
            return entry.account.provider.displayName
        }
        return "\(entry.account.provider.displayName) \(index + 1)"
    }

    private func isLive(_ entry: AccountEntry) -> Bool {
        guard entry.isEnabled(in: model.snapshot.preferences)
        else { return false }
        return entry.state.hasCurrentResponse
    }

    private func metric(_ window: UsageWindow, provider: Provider, fresh: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(AppText.text(window.label)).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58)).lineLimit(2)
                Spacer(minLength: 2)
                if let fraction = window.usedFraction {
                    Text(fraction, format: .percent.precision(.fractionLength(0...1)))
                        .font(.system(size: 23, weight: .medium)).monospacedDigit().fixedSize()
                }
            }
            if let fraction = window.usedFraction {
                SegmentedMeter(
                    fraction: fraction,
                    color: !fresh
                        ? .gray
                        : fraction >= model.snapshot.preferences.windowCritical
                            ? .red : fraction >= model.snapshot.preferences.windowWarning ? .orange : accent(provider))
            }
            if window.note == "Disabled" { Text("Disabled").font(.caption).foregroundStyle(.secondary) }
            if let amount = Dashboard.usageAmount(window) {
                Text(amount)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if !fresh, let observedAt = window.observedAt {
                Text(AppText.format("Earlier reading · %@", observedAt.formatted(date: .omitted, time: .shortened)))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            if let reset = window.resetsAt {
                Group {
                    if reset > Date() {
                        Text("Resets \(reset, style: .relative)")
                    } else {
                        Text("Awaiting update")
                    }
                }
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.56))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var accountColumns: Int { width >= 600 && visibleAccounts.count > 1 ? 2 : 1 }
}
