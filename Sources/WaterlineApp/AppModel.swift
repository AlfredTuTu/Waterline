import Darwin
import Foundation
import Observation
import WaterlineKit

@Observable
final class AppModel {
    let isVerification: Bool
    #if WATERLINE_VERIFICATION
        let verificationDirectory: URL
    #endif
    private(set) var snapshot = Snapshot(generatedAt: Date(), accounts: [])
    var refreshing: Bool { snapshot.accounts.contains { $0.operation != .idle } }
    private(set) var error: String?
    private(set) var loaded = false
    func setNotchAccounts(_ ids: [AccountID]?) async {
        await perform { try await engine.setNotchAccounts(ids) }
    }
    func toggleNotchAccount(_ id: AccountID) async {
        await perform { try await engine.toggleNotchAccount(id) }
    }
    private(set) var retryingHistory = false
    private(set) var historyRetryError: String?
    private(set) var changingOptionalSource: OptionalCredentialSource?
    private let engine: Engine
    private var observation: Task<Void, Never>?
    private var claudeLocalMonitor: ClaudeLocalMonitor?

    init() {
        #if WATERLINE_VERIFICATION
            guard Bundle.main.bundleIdentifier == "io.github.alfredtutu.waterline.verification" else {
                FileHandle.standardError.write(Data("Verification build requires its separate app bundle.\n".utf8))
                exit(64)
            }
            var runID = UUID()
            if let index = CommandLine.arguments.firstIndex(of: "--verification-run-id") {
                guard CommandLine.arguments.indices.contains(index + 1),
                    let value = UUID(uuidString: CommandLine.arguments[index + 1])
                else {
                    FileHandle.standardError.write(Data("Verification run ID must be a UUID.\n".utf8))
                    exit(64)
                }
                runID = value
            }
            let directory = VerificationEnvironment.directory(runID: runID)
            verificationDirectory = directory
            if CommandLine.arguments.contains("--verification-history-render") {
                do {
                    try VerificationEnvironment.seedLongHistory(
                        directory: directory,
                        incompatible: CommandLine.arguments.contains("--verification-history-invalid"))
                } catch {
                    FileHandle.standardError.write(Data("Verification history setup failed.\n".utf8))
                    exit(1)
                }
            }
            engine = Engine(
                dependencies: VerificationEnvironment.dependencies(
                    directory: directory, empty: CommandLine.arguments.contains("--verification-empty")))
            isVerification = true
        #else
            guard !CommandLine.arguments.contains(where: { $0.hasPrefix("--verification") }) else {
                FileHandle.standardError.write(
                    Data("Use the separate Waterline Verification app for verification runs.\n".utf8))
                exit(64)
            }
            engine = Engine()
            isVerification = false
        #endif
    }

    func start() {
        guard observation == nil else { return }
        observation = Task { [weak self, engine] in
            let updates = await engine.updates
            for await snapshot in updates {
                guard let self else { return }
                self.snapshot = isVerification ? snapshot : snapshot.includingProviders(Registry.activeProviders)
                if !snapshot.historyFailed, let previous = self.historyRetryError {
                    if self.error == previous { self.error = nil }
                    self.historyRetryError = nil
                }
            }
        }
        Task {
            do {
                try await engine.start()
                let preferences = await engine.snapshot().preferences
                let automatic = preferences.forAutomaticMonitoring()
                if automatic != preferences { try await engine.updatePreferences(automatic) }
            } catch { self.error = "Could not load or save account state." }
            loaded = true
            await connectOnFirstLaunch()
            await startClaudeLocalMonitor()
            installClaudeStatusline()
            await refresh(manual: false)
            await engine.startAutomaticRefresh()
        }
    }

    private func installClaudeStatusline() {
        guard !isVerification else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard FileManager.default.fileExists(atPath: home.appending(path: ".claude.json").path),
            let executable = Bundle.main.executableURL?.deletingLastPathComponent().appending(path: "waterline"),
            FileManager.default.isExecutableFile(atPath: executable.path)
        else { return }
        do {
            _ = try ClaudeStatuslineSetup.install(
                settingsURL: home.appending(path: ".claude/settings.json"),
                executable: executable)
        } catch { self.error = "Could not enable local Claude quota." }
    }

    private func startClaudeLocalMonitor() async {
        guard !isVerification, claudeLocalMonitor == nil else { return }
        let directory = SnapshotStore.default().url.deletingLastPathComponent().appending(
            path: "claude-local-observations")
        do {
            claudeLocalMonitor = try ClaudeLocalMonitor(directory: directory) { [weak self] in
                Task { @MainActor in await self?.readClaudeLocalObservations(directory: directory) }
            }
            await readClaudeLocalObservations(directory: directory)
        } catch { self.error = "Could not monitor local Claude quota." }
    }

    private func readClaudeLocalObservations(directory: URL) async {
        let identities = snapshot.accounts.filter { $0.account.provider == .claudeCode }.compactMap(\.account.identity)
        guard !identities.isEmpty else { return }
        do {
            let observations = try await Task.detached(priority: .utility) {
                let store = ClaudeLocalObservationStore(directory: directory)
                let observations = try identities.compactMap { try store.latest(matching: $0) }
                guard !observations.isEmpty else { return [ClaudeLocalObservation]() }
                let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude.json")
                let local = try ClaudeLocalLogin.identity(RealFileSystem().contents(of: url, maximumBytes: 4_194_304))
                return observations.filter { ClaudeLocalLogin.matches(local, verified: $0.identity) }
            }.value
            for observation in observations { try await engine.receiveClaudeObservation(observation) }
        } catch { self.error = "Could not read local Claude quota." }
    }

    private func connectOnFirstLaunch() async {
        guard !isVerification else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "initialConnectionAttempted") else { return }
        defaults.set(true, forKey: "initialConnectionAttempted")
        // Existing installations have already had their authorization opportunity.
        guard !defaults.bool(forKey: "connectionGuidePresented"),
            !defaults.bool(forKey: "connectionGuideCompleted")
        else { return }
        for provider in Registry.adapters.map({ type(of: $0).descriptor.provider }) {
            let current = await engine.snapshot()
            if current.preferences.disabledProviders.contains(provider) { continue }
            let accounts = current.accounts.filter { $0.account.provider == provider }
            if !accounts.isEmpty, accounts.allSatisfy({ $0.state.hasCurrentResponse }) { continue }
            await connectManagedProvider(provider)
        }
    }

    func refresh(manual: Bool = true) async {
        error = nil
        do { try await engine.refreshAll(manual: manual) } catch WriterLockError.busy {
            error = "Another Waterline process is updating accounts."
        } catch { self.error = "Could not save the latest account state." }
    }

    func refreshWhenViewed() {
        Task { await engine.refreshWhenViewed() }
    }

    func suspendForSleep() {
        Task { await engine.suspendForSleep() }
    }

    func recoverConnection() {
        Task {
            do { try await engine.recoverAfterInterruption() } catch {
                self.error = "Could not restore the latest account state."
            }
        }
    }

    func setEnabled(_ entry: AccountEntry, enabled: Bool) async {
        await perform { try await engine.setAccountEnabled(entry.account.id, enabled: enabled) }
        if enabled { await refresh() }
    }

    func setPinned(_ entry: AccountEntry, pinned: Bool) async {
        await perform { try await engine.setAccountPinned(entry.account.id, pinned: pinned) }
    }

    func rename(_ entry: AccountEntry, label: String) async {
        await perform { try await engine.renameAccount(entry.account.id, label: label) }
    }

    func connectManagedProvider(_ provider: Provider) async {
        await perform {
            try await engine.start()
            let preferences = await engine.snapshot().preferences
            if preferences.disabledProviders.contains(provider) {
                try await engine.setSource(provider, enabled: true)
            }
            if provider == .antigravity {
                if preferences.enabledCredentialSources?.contains(.antigravityCLI) != true {
                    try await engine.setOptionalCredentialSource(.antigravityCLI, enabled: true)
                } else {
                    try await engine.connectOptionalCredentialSource(.antigravityCLI)
                }
            } else {
                try await engine.connect(provider: provider, interactive: true)
            }
        }
    }

    func connect(_ provider: Provider) async {
        await perform { try await engine.connect(provider: provider, interactive: true) }
    }

    func checkOptionalSource(_ source: OptionalCredentialSource) async {
        guard changingOptionalSource == nil else { return }
        changingOptionalSource = source
        defer { changingOptionalSource = nil }
        await perform { try await engine.connectOptionalCredentialSource(source) }
    }

    func reconnect(_ entry: AccountEntry) async {
        if entry.account.credential == .manual {
            await perform { try await engine.reconnectManualAccount(entry.account.id) }
        } else if let source = entry.account.optionalCredentialSource {
            await checkOptionalSource(source)
        } else {
            await connect(entry.account.provider)
        }
    }

    func retryHistoryPersistence() async {
        guard !retryingHistory else { return }
        retryingHistory = true
        historyRetryError = nil
        error = nil
        defer { retryingHistory = false }
        do {
            try await engine.retryHistoryPersistence()
        } catch {
            let message: String
            switch error {
            case HistoryError.malformedRecord, HistoryError.conflictingObservation, is DecodingError:
                message = "History contains incompatible records. The original file was preserved."
            default:
                message = "History could not be saved. Check disk space and data-folder access."
            }
            historyRetryError = message
            self.error = message
        }
    }

    func tokenHistory() async throws -> [TokenImport] { try await engine.tokenHistory() }

    func importCodexLog(_ url: URL) async throws -> TokenImportResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try await engine.importCodexLog(url)
    }

    func balanceHistory(for id: AccountID, period: HistoryPeriod = .week) async -> [BalanceObservation] {
        await engine.balanceHistory(for: id, period: period)
    }

    func setAccountOrder(_ ids: [AccountID]?) async {
        let visible = isVerification ? nil : Registry.activeProviders
        await perform { try await engine.setAccountOrder(ids, visibleProviders: visible) }
    }

    private func perform(_ operation: () async throws -> Void) async {
        error = nil
        do { try await operation() } catch SettingsError.invalidInterval {
            error = "Refresh interval must be between 60 and 3600 seconds."
        } catch SettingsError.invalidThresholds {
            error = "Use positive balance thresholds and warning below critical."
        } catch SettingsError.invalidAccountOrder {
            error = "Account list changed. Try ordering it again."
        } catch SettingsError.invalidNotchSelection {
            error = "Choose one account for the notch."
        } catch SettingsError.invalidLabel {
            error = "Use a single-line account name, up to 80 characters."
        } catch HistoryError.persistenceFailed {
            error = "History could not be saved. Check disk space and data-folder access."
        } catch ManualKeyError.invalidTeam {
            error = "Enter the team ID for this management key."
        } catch ManualKeyError.invalidRegion {
            error = "Choose the region where this key was created."
        } catch ManualKeyError.invalidKey {
            error = "Enter a non-empty key without spaces or line breaks."
        } catch ManualKeyError.saveFailed {
            error = "Key could not be saved. Unlock Keychain, then update the pending account’s key."
        } catch ManualKeyError.cleanupPending {
            error = "Account removed; saved-key deletion is pending. Retry cleanup in Privacy settings."
        } catch EngineError.sourceDisabled { error = "Connect this account to resume." } catch {
            self.error = "Could not save the change. Check account state and storage."
        }
    }

    var hasProblems: Bool {
        error != nil || snapshot.storageFailed || snapshot.historyFailed || snapshot.pendingSecretCleanup > 0
            || !snapshot.sourceFailures.isEmpty
            || snapshot.accounts.contains { entry in
                guard entry.isEnabled(in: snapshot.preferences) else { return false }
                switch entry.state {
                case .stale, .expired, .unavailable, .partial: return true
                case .fresh(let reading):
                    return !reading.usage.componentFailures.isEmpty
                        || reading.usage.quotaWindows.contains {
                            !$0.isCurrent(
                                at: Date(), fallbackObservation: reading.observedAt,
                                interval: snapshot.preferences.refreshInterval)
                        }
                        || reading.usage.balances.contains {
                            !$0.isCurrent(
                                at: Date(), fallbackObservation: reading.observedAt,
                                interval: snapshot.preferences.refreshInterval)
                        }
                case .pending: return false
                }
            }
    }

    func headlineText(_ value: DashboardHeadline) -> String {
        let text = usageHeadline(value)
        return isVerification ? "TEST · " + text : text
    }

    private func usageHeadline(_ value: DashboardHeadline) -> String {
        switch value {
        case .quota(let highest):
            return AppText.format("%@ used", highest.formatted(.percent.precision(.fractionLength(0...1))))
        case .balance(let balance):
            return "\(balance.amount.formatted(.number.precision(.fractionLength(0...2)))) \(balance.currency)"
        case .updated(let date):
            return AppText.format("Updated %@", date.formatted(date: .omitted, time: .shortened))
        case .paused: return AppText.text("Accounts paused")
        case .checking: return AppText.text("Checking…")
        case .connect: return AppText.text("Connect accounts")
        case .attention: return AppText.text("Needs attention")
        case .unsupported: return AppText.text("Not supported")
        case .details: return AppText.text("Details")
        case .awaitingUpdate: return AppText.text("Awaiting update")
        }
    }
}
