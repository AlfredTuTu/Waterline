import Foundation

public enum EngineError: Error { case snapshotWriteFailed, sourceDisabled }

/// Single owner of account configuration, request acceptance and stored readings.
public actor Engine {
    public struct Dependencies: Sendable {
        public var adapters: [any ProviderAdapter]
        public var environment: DiscoveryEnvironment
        public var makeHTTPClient: @Sendable (Set<String>) -> any HTTPClient
        public var ownedSecrets: any OwnedSecretStoring
        public var store: SnapshotStore
        public var now: @Sendable () -> Date
        public var observationOrigin: ObservationOrigin

        public init(
            adapters: [any ProviderAdapter] = Registry.adapters,
            environment: DiscoveryEnvironment = .current(),
            makeHTTPClient: @escaping @Sendable (Set<String>) -> any HTTPClient = {
                URLSessionHTTPClient(allowedHosts: $0)
            },
            store: SnapshotStore = .default(),
            ownedSecrets: any OwnedSecretStoring = SystemOwnedSecretStore(),
            now: @escaping @Sendable () -> Date = Date.init,
            observationOrigin: ObservationOrigin = .live
        ) {
            self.adapters = adapters
            self.environment = environment
            self.makeHTTPClient = makeHTTPClient
            self.store = store
            self.ownedSecrets = ownedSecrets
            self.now = now
            self.observationOrigin = observationOrigin
        }
    }

    let dependencies: Dependencies
    let requestLimiter = HTTPRequestLimiter()
    let adapters: [Provider: any ProviderAdapter]
    let configurationStore: ConfigurationStore
    var configuration = Configuration()
    var accounts: [Account] { configuration.accounts.map(\.account) }
    var secrets: [AccountID: Secret] = [:]
    var credentialFailures: [AccountID: FetchError] = [:]
    var states: [AccountID: AccountState] = [:]
    var writerLock: WriterLock?
    var started = false
    var lifecycle = UUID()
    var pendingDiscovery: Set<Provider> = []
    var nextCredentialCheck = Date.distantFuture
    var discoveryVersions: [Provider: UUID] = [:]
    var schedules: [AccountID: RefreshSchedule] = [:]
    var scheduler: Task<Void, Never>?
    var recoveryTask: Task<Void, any Error>?
    var suspended = false
    var userActive = false
    func effectiveRefreshInterval(for id: AccountID) -> TimeInterval {
        if accounts.first(where: { $0.id == id })?.provider == .claudeCode {
            return max(300, configuration.preferences.refreshInterval)
        }
        guard userActive, let account = accounts.first(where: { $0.id == id }),
            let adapter = adapters[account.provider], type(of: adapter).descriptor.kind != .balance
        else {
            return configuration.preferences.refreshInterval
        }
        return min(60, configuration.preferences.refreshInterval)
    }
    var startup: Task<Void, any Error>?
    var startupID: UUID?
    var generations: [AccountID: UUID] = [:]
    var inFlight: [AccountID: Task<Void, Never>] = [:]
    var lastAttemptAt: Date?
    var operations: [AccountID: AccountOperation] = [:]
    public private(set) var discoveryErrors: [Provider: FetchError] = [:]
    public internal(set) var storageFailed = false
    var configurationFailed = false
    let tokenStore: TokenLedgerStore
    var tokenImport: Task<CodexTokenLogReport, any Error>?
    var tokenImportID: UUID?
    let historyStore: HistoryStore
    var historyRecords: [BalanceObservation] = []
    var historyKeys: Set<BalanceObservationKey> = []
    var historyPending: [BalanceObservation] = []
    var historyFailed = false
    var historyTailIncomplete = false
    var historyRepairNotice: String?
    var historyLoaded = false
    var historyLoadError: HistoryError?
    var pendingSecretCleanup: Set<AccountID> = []
    var subscribers: [UUID: AsyncStream<Snapshot>.Continuation] = [:]

    public init(dependencies: Dependencies = Dependencies()) {
        self.dependencies = dependencies
        pendingDiscovery = Set(dependencies.adapters.map { type(of: $0).descriptor.provider })
        tokenStore = TokenLedgerStore(
            url: dependencies.store.url.deletingLastPathComponent().appending(path: "token-history.json"))
        historyStore = HistoryStore(
            url: dependencies.store.url.deletingLastPathComponent().appending(path: "history.jsonl"))
        configurationStore = ConfigurationStore(
            url: dependencies.store.url.deletingLastPathComponent().appending(path: "configuration.json"))
        adapters = Dictionary(
            uniqueKeysWithValues: dependencies.adapters.map { (type(of: $0).descriptor.provider, $0) })
    }

    public func start() async throws {
        if let startup { return try await startup.value }
        guard !started else { return }
        let id = UUID()
        let session = lifecycle
        let task = Task {
            try Task.checkCancellation()
            try await self.loadAndDiscover(session: session)
        }
        startupID = id
        startup = task
        defer { if startupID == id { startup = nil; startupID = nil } }
        try await task.value
    }

    private func loadAndDiscover(session: UUID) async throws {
        guard lifecycle == session else { throw CancellationError() }
        writerLock = try WriterLock(directory: dependencies.store.url.deletingLastPathComponent())
        let previous: [AccountEntry]
        do {
            let saved = try dependencies.store.load()
            previous = saved?.accounts ?? []
            lastAttemptAt = saved?.lastAttemptAt
        } catch { previous = []; storageFailed = true }
        do {
            if let saved = try configurationStore.load() {
                configuration = saved
            } else {
                var imported = Configuration()
                for entry in previous where !imported.accounts.contains(where: { $0.account.id == entry.account.id }) {
                    imported.accounts.append(ManagedAccount(account: entry.account, preferences: entry.preferences))
                }
                try configurationStore.save(imported)
                configuration = imported
            }
        } catch {
            configurationFailed = true
            configuration.accounts = previous.map { ManagedAccount(account: $0.account, preferences: $0.preferences) }
            states = Dictionary(previous.map { ($0.account.id, $0.state) }, uniquingKeysWith: { first, _ in first })
            writerLock = nil
            broadcast()
            throw error
        }
        states = Dictionary(
            previous.filter { entry in accounts.contains { $0.id == entry.account.id } }.map {
                ($0.account.id, $0.state)
            }, uniquingKeysWith: { first, _ in first })
        schedules = Dictionary(
            previous.compactMap { entry in entry.schedule.map { (entry.account.id, $0) } },
            uniquingKeysWith: { first, _ in first })
        for account in accounts where states[account.id] == nil { states[account.id] = .pending }
        started = true
        nextCredentialCheck = dependencies.now().addingTimeInterval(60)
        pendingDiscovery = Set(dependencies.adapters.map { type(of: $0).descriptor.provider })
        if dependencies.adapters.contains(where: { type(of: $0).descriptor.kind != .window }) { loadHistory() }
        cleanRemovedSecrets()
        broadcast()
        for adapter in dependencies.adapters {
            guard started, lifecycle == session else { return }
            let provider = type(of: adapter).descriptor.provider
            guard !configuration.preferences.disabledProviders.contains(provider) else { continue }
            await discover(provider: provider, interactive: false, restoreRemoved: false)
        }
        if started, lifecycle == session { try publish() }
    }

    /// Coalesce each account and bound independent providers to four requests at once.
    public func refreshAll(superseding: Bool = false, manual: Bool = true, provider: Provider? = nil) async throws {
        try await start()
        let session = lifecycle
        let ids = accounts.filter { adapters[$0.provider] != nil && (provider == nil || $0.provider == provider) }.map(
            \.id)
        await withTaskGroup(of: Void.self) { group in
            var iterator = ids.makeIterator()
            for _ in 0..<4 {
                if let id = iterator.next() {
                    group.addTask { await self.refresh(id, superseding: superseding, manual: manual, session: session) }
                }
            }
            while await group.next() != nil {
                if let id = iterator.next() {
                    group.addTask { await self.refresh(id, superseding: superseding, manual: manual, session: session) }
                }
            }
        }
        if storageFailed || configurationFailed { throw EngineError.snapshotWriteFailed }
    }

    public func refreshAccount(_ id: AccountID) async throws {
        try await start()
        guard accounts.contains(where: { $0.id == id }) else { throw SettingsError.accountNotFound }
        await refresh(id, superseding: false, manual: true, session: lifecycle)
        if storageFailed || configurationFailed { throw EngineError.snapshotWriteFailed }
    }

    private func refresh(_ id: AccountID, superseding: Bool, manual: Bool, session: UUID) async {
        guard started, !suspended, lifecycle == session, let account = accounts.first(where: { $0.id == id }),
            isEnabled(id)
        else {
            return
        }
        if let task = inFlight[id], !superseding { await task.value; return }
        guard
            schedules[id, default: RefreshSchedule()].eligible(
                at: dependencies.now(), manual: manual, resetAt: quotaReset(id))
        else { return }
        invalidate(id)
        let generation = UUID()
        generations[id] = generation
        operations[id] = .refreshing
        lastAttemptAt = dependencies.now()
        let task = Task {
            let result = await self.fetch(account)
            self.accept(result, for: id, generation: generation)
        }
        inFlight[id] = task
        broadcast()
        await task.value
    }

    private func accept(_ result: AccountState, for id: AccountID, generation: UUID) {
        guard generations[id] == generation, isEnabled(id) else { return }
        states[id] = result
        recordHistory(result, accountID: id)
        var schedule = schedules[id, default: RefreshSchedule()]
        switch result {
        case .fresh:
            schedule.succeeded(at: dependencies.now(), interval: effectiveRefreshInterval(for: id))
        case .partial(let reading):
            schedule.partiallySucceeded(
                at: dependencies.now(), interval: effectiveRefreshInterval(for: id),
                errors: reading.usage.componentFailures.map(\.error))
        case .stale(_, let error), .unavailable(let error): schedule.failed(error, at: dependencies.now())
        case .pending, .expired: break
        }
        schedules[id] = schedule
        inFlight[id] = nil
        generations[id] = nil
        operations[id] = .idle
        do { try publish() } catch { storageFailed = true }
    }

    func invalidate(_ id: AccountID) {
        inFlight[id]?.cancel()
        inFlight[id] = nil
        generations[id] = nil
        operations[id] = .idle
    }

    func isEnabled(_ id: AccountID) -> Bool {
        guard let managed = configuration.accounts.first(where: { $0.account.id == id }) else { return false }
        return adapters[managed.account.provider] != nil && managed.preferences.enabled
            && configuration.preferences.allowsSource(for: managed.account)
    }

    public func stop() {
        scheduler?.cancel(); scheduler = nil
        recoveryTask?.cancel(); recoveryTask = nil
        suspended = false
        startup?.cancel(); startup = nil
        tokenImport?.cancel(); tokenImport = nil; tokenImportID = nil
        lifecycle = UUID()
        for id in Array(inFlight.keys) { invalidate(id) }
        generations.removeAll()
        discoveryVersions.removeAll()
        operations.removeAll()
        secrets.removeAll()
        for continuation in subscribers.values { continuation.finish() }
        subscribers.removeAll()
        writerLock = nil
        started = false
    }

    public func suspendForSleep() {
        suspended = true
        lifecycle = UUID()
        scheduler?.cancel(); scheduler = nil
        recoveryTask?.cancel(); recoveryTask = nil
        startup?.cancel(); startup = nil
        tokenImport?.cancel(); tokenImport = nil; tokenImportID = nil
        for id in Array(inFlight.keys) { invalidate(id) }
        generations.removeAll()
        discoveryVersions.removeAll()
        operations.removeAll()
        broadcast()
    }

    public func recoverAfterInterruption() async throws {
        guard started || suspended else { return }
        if let recoveryTask { return try await recoveryTask.value }
        suspended = false
        if !started { try await start() }
        let session = lifecycle
        let task = Task {
            for provider in self.pendingDiscovery.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard !self.suspended, self.lifecycle == session else { return }
                if !self.configuration.preferences.disabledProviders.contains(provider) {
                    await self.discover(provider: provider, interactive: false, restoreRemoved: false)
                }
            }
            await self.checkChangedFileCredentials()
            try await self.refreshAll(manual: false)
            guard self.started, self.lifecycle == session else { return }
            self.startAutomaticRefresh()
            self.broadcast()
        }
        recoveryTask = task
        defer { if lifecycle == session { recoveryTask = nil } }
        try await task.value
    }

    public func startAutomaticRefresh() {
        guard started, !suspended, scheduler == nil else { return }
        scheduler = Task { [weak self] in
            while !Task.isCancelled {
                let delay = await self?.nextRefreshDelay() ?? 300
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self else { return }
                await self.automaticRefresh()
            }
        }
    }

    func restartScheduler() {
        guard scheduler != nil else { return }
        scheduler?.cancel(); scheduler = nil
        startAutomaticRefresh()
    }

    private func nextRefreshDelay() -> TimeInterval {
        var due = accounts.compactMap { account -> Date? in
            guard isEnabled(account.id) else { return nil }
            let schedule = schedules[account.id, default: RefreshSchedule()]
            return schedule.nextAutomaticDate(resetAt: quotaReset(account.id))
        }.min()
        if !fileCredentialChecks.isEmpty {
            let now = dependencies.now()
            if nextCredentialCheck.timeIntervalSince(now) > 300 { nextCredentialCheck = now.addingTimeInterval(300) }
            due = min(due ?? nextCredentialCheck, nextCredentialCheck)
        }
        return max(1, due?.timeIntervalSince(dependencies.now()) ?? 300)
    }

    private func automaticRefresh() async {
        if dependencies.now() >= nextCredentialCheck { await checkChangedFileCredentials() }
        do { try await refreshAll(manual: false) } catch { storageFailed = true; broadcast() }
    }

    public func snapshot() -> Snapshot {
        let entries = configuration.accounts.map { managed in
            AccountEntry(
                account: managed.account, state: visibleState(managed.account.id),
                preferences: managed.preferences, operation: operations[managed.account.id] ?? .idle,
                schedule: schedules[managed.account.id])
        }
        return Snapshot(
            generatedAt: dependencies.now(), accounts: entries,
            sourceFailures: discoveryErrors.map { SourceFailure(provider: $0.key, error: $0.value) }.sorted {
                $0.provider.rawValue < $1.provider.rawValue
            },
            storageFailed: storageFailed || configurationFailed, preferences: configuration.preferences,
            lastAttemptAt: lastAttemptAt, pendingSecretCleanup: pendingSecretCleanup.count,
            historyFailed: historyFailed,
            historyRepairNotice: historyRepairNotice
        )
    }

    func visibleState(_ id: AccountID) -> AccountState {
        var state = states[id] ?? .pending
        if case .stale(let reading, _) = state, reading.origin == .local,
            reading.usage.quotaWindows.contains(where: {
                $0.isCurrent(
                    at: dependencies.now(), fallbackObservation: reading.observedAt,
                    interval: configuration.preferences.refreshInterval)
            })
        {
            // A failed fallback does not invalidate an independently current local observation.
            state = reading.usage.componentFailures.isEmpty ? .fresh(reading: reading) : .partial(reading: reading)
        }
        if state.hasCurrentResponse, let reading = state.reading,
            !reading.isCurrent(at: dependencies.now(), interval: configuration.preferences.refreshInterval)
        {
            return .expired(reading: reading)
        }
        if state.hasCurrentResponse, let reading = state.reading {
            let windows = reading.usage.quotaWindows
            if windows.contains(where: {
                $0.error == nil
                    && !$0.isCurrent(
                        at: dependencies.now(), fallbackObservation: reading.observedAt,
                        interval: configuration.preferences.refreshInterval)
            })
                || reading.usage.balances.contains(where: {
                    $0.error == nil
                        && !$0.isCurrent(
                            at: dependencies.now(), fallbackObservation: reading.observedAt,
                            interval: configuration.preferences.refreshInterval)
                })
            {
                let hasCurrent =
                    windows.contains {
                        $0.isCurrent(
                            at: dependencies.now(), fallbackObservation: reading.observedAt,
                            interval: configuration.preferences.refreshInterval)
                    }
                    || reading.usage.balances.contains {
                        $0.isCurrent(
                            at: dependencies.now(), fallbackObservation: reading.observedAt,
                            interval: configuration.preferences.refreshInterval)
                    }
                return hasCurrent ? .partial(reading: reading) : .expired(reading: reading)
            }
        }
        return state
    }

    private func quotaReset(_ id: AccountID) -> Date? {
        guard let reading = states[id]?.reading else { return nil }
        return reading.usage.quotaWindows.filter { $0.error == nil }.compactMap(\.resetsAt)
            .filter { $0 > reading.fetchedAt }.min()
    }

    public var updates: AsyncStream<Snapshot> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            continuation.yield(snapshot())
            subscribers[id] = continuation
            continuation.onTermination = { [weak self] _ in Task { await self?.removeSubscriber(id) } }
        }
    }

    private func fetch(_ account: Account) async -> AccountState {
        let previous = states[account.id]?.reading
        guard let adapter = adapters[account.provider] else { return degraded(previous, .credentialMissing) }
        do {
            let usage: Usage
            if let local = adapter as? any LocalProviderAdapter {
                usage = try await local.fetchLocal(
                    account, requestBudget: limitedHTTPClient(allowedHosts: []))
            } else {
                guard let secret = secrets[account.id] else {
                    return degraded(previous, credentialFailures[account.id] ?? .credentialMissing)
                }
                let http = limitedHTTPClient(allowedHosts: type(of: adapter).descriptor.allowedHosts)
                usage = try await adapter.fetch(account, secret: secret, http: http)
            }
            let receivedAt = dependencies.now()
            let accepted = usage.accepting(at: receivedAt, previous: previous)
            let reading = Reading(usage: accepted, fetchedAt: receivedAt, origin: dependencies.observationOrigin)
            return accepted.componentFailures.isEmpty ? .fresh(reading: reading) : .partial(reading: reading)
        } catch { return degraded(previous, safeError(error)) }
    }

    func limitedHTTPClient(allowedHosts: Set<String>) -> any HTTPClient {
        LimitedHTTPClient(client: dependencies.makeHTTPClient(allowedHosts), limiter: requestLimiter)
    }

    func degraded(_ previous: Reading?, _ error: FetchError) -> AccountState {
        previous.map { .stale(reading: $0, error: error) } ?? .unavailable(error: error)
    }

    func credentialFailureState(_ id: AccountID, error: FetchError) -> AccountState {
        if schedules[id]?.authenticationParked == true, let previous = states[id] {
            switch previous {
            case .unavailable(.unauthorized), .unavailable(.permissionDenied),
                .stale(_, .unauthorized), .stale(_, .permissionDenied):
                return previous
            default: break
            }
        }
        return degraded(states[id]?.reading, error)
    }

    func safeError(_ error: any Error) -> FetchError {
        (error as? FetchError) ?? .transport(detail: "Operation failed")
    }

    func setDiscoveryError(_ error: FetchError?, provider: Provider) { discoveryErrors[provider] = error }

    func publish() throws {
        do {
            storageFailed = false
            try dependencies.store.save(snapshot())
        } catch {
            storageFailed = true
            broadcast()
            throw error
        }
        broadcast()
    }

    func broadcast() {
        let snapshot = snapshot()
        for continuation in subscribers.values { continuation.yield(snapshot) }
    }

    private func removeSubscriber(_ id: UUID) { subscribers[id] = nil }
}
