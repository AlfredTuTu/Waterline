import Foundation

extension Engine {
    public func updateAccount(_ id: AccountID, preferences: AccountPreferences) throws {
        guard started else { throw SettingsError.engineNotStarted }
        guard let index = configuration.accounts.firstIndex(where: { $0.account.id == id }) else {
            throw SettingsError.accountNotFound
        }
        let previouslyEnabled = configuration.accounts[index].preferences.enabled
        var next = configuration
        var validated = preferences
        validated.label = preferences.label?.trimmingCharacters(in: .whitespacesAndNewlines)
        if validated.label?.isEmpty == true { validated.label = nil }
        next.accounts[index].preferences = validated
        try saveConfiguration(next)
        if !validated.enabled {
            invalidate(id)
        } else if !previouslyEnabled {
            var schedule = schedules[id, default: RefreshSchedule()]
            schedule.nextAutomatic = .distantPast
            schedules[id] = schedule
        }
        restartScheduler()
        try publish()
    }

    public func setAccountEnabled(_ id: AccountID, enabled: Bool) throws {
        guard var preferences = configuration.accounts.first(where: { $0.account.id == id })?.preferences else {
            throw SettingsError.accountNotFound
        }
        preferences.enabled = enabled
        try updateAccount(id, preferences: preferences)
    }

    public func setAccountPinned(_ id: AccountID, pinned: Bool) throws {
        guard var preferences = configuration.accounts.first(where: { $0.account.id == id })?.preferences else {
            throw SettingsError.accountNotFound
        }
        preferences.pinned = pinned
        try updateAccount(id, preferences: preferences)
    }

    public func renameAccount(_ id: AccountID, label: String) throws {
        guard var preferences = configuration.accounts.first(where: { $0.account.id == id })?.preferences else {
            throw SettingsError.accountNotFound
        }
        preferences.label = label
        try updateAccount(id, preferences: preferences)
    }

    public func removeAccount(_ id: AccountID) throws {
        guard started else { throw SettingsError.engineNotStarted }
        guard let index = configuration.accounts.firstIndex(where: { $0.account.id == id }) else {
            throw SettingsError.accountNotFound
        }
        var next = configuration
        let removed = next.accounts.remove(at: index).account
        if let selected = next.preferences.notchAccountIDs {
            let retained = selected.filter { $0 != id }
            next.preferences.notchAccountIDs = retained
        }
        next.removed.append(removed)
        try saveConfiguration(next)
        invalidate(id)
        secrets[id] = nil
        credentialFailures[id] = nil
        states[id] = nil
        schedules[id] = nil
        cleanRemovedSecrets()
        restartScheduler()
        try publish()
        if pendingSecretCleanup.contains(id) { throw ManualKeyError.cleanupPending }
    }

    public func setSource(_ provider: Provider, enabled: Bool) async throws {
        var next = configuration.preferences
        if enabled { next.disabledProviders.remove(provider) } else { next.disabledProviders.insert(provider) }
        try await updatePreferences(next)
    }

    public func updatePreferences(_ preferences: UserPreferences) async throws {
        guard started else { throw SettingsError.engineNotStarted }
        try preferences.validate()
        let old = configuration.preferences
        let changedSourceProviders = Set(
            (preferences.enabledCredentialSources ?? []).symmetricDifference(old.enabledCredentialSources ?? []).map(
                \.provider))
        let interruptedDiscoveries = changedSourceProviders.intersection(pendingDiscovery)
        var next = configuration
        next.preferences = preferences
        try saveConfiguration(next)
        for account in accounts {
            if !preferences.allowsSource(for: account) {
                invalidate(account.id)
                secrets[account.id] = nil
                discoveryVersions[account.provider] = UUID()
            } else if old.refreshInterval != preferences.refreshInterval {
                var schedule = schedules[account.id, default: RefreshSchedule()]
                schedule.nextAutomatic = dependencies.now().addingTimeInterval(preferences.refreshInterval)
                schedules[account.id] = schedule
            }
        }
        try publish()
        for provider in old.disabledProviders.subtracting(preferences.disabledProviders) {
            await discover(provider: provider, interactive: false, restoreRemoved: false)
        }
        for provider in interruptedDiscoveries where !preferences.disabledProviders.contains(provider) {
            await discover(provider: provider, interactive: false, restoreRemoved: false)
        }
        for source in (preferences.enabledCredentialSources ?? []).subtracting(old.enabledCredentialSources ?? []) {
            if !preferences.disabledProviders.contains(source.provider),
                !old.disabledProviders.subtracting(preferences.disabledProviders).contains(source.provider),
                !interruptedDiscoveries.contains(source.provider)
            {
                await discover(
                    provider: source.provider, interactive: false, restoreRemoved: false, sourceFilter: source)
            }
        }
        restartScheduler()
        try publish()
    }

    public func setOptionalCredentialSource(_ source: OptionalCredentialSource, enabled: Bool) async throws {
        try await start()
        var preferences = configuration.preferences
        var sources = preferences.enabledCredentialSources ?? []
        if enabled { sources.insert(source) } else { sources.remove(source) }
        preferences.enabledCredentialSources = sources
        try await updatePreferences(preferences)
        if enabled && !preferences.disabledProviders.contains(source.provider) {
            for account in accounts where account.optionalCredentialSource == source {
                try await refreshAccount(account.id)
            }
        }
    }

    public func connectOptionalCredentialSource(_ source: OptionalCredentialSource) async throws {
        try await start()
        guard configuration.preferences.enabledCredentialSources?.contains(source) == true,
            !configuration.preferences.disabledProviders.contains(source.provider)
        else { throw EngineError.sourceDisabled }
        await discover(provider: source.provider, interactive: false, restoreRemoved: true, sourceFilter: source)
        try publish()
        for account in accounts where account.optionalCredentialSource == source {
            try await refreshAccount(account.id)
        }
    }

    /// Interactive access is only for a UI/CLI Connect action that has announced the scoped read.
    public func connect(provider: Provider, interactive: Bool = false) async throws {
        try await start()
        if provider == .antigravity,
            configuration.preferences.enabledCredentialSources?.contains(.antigravityCLI) != true
        {
            throw EngineError.sourceDisabled
        }
        guard !configuration.preferences.disabledProviders.contains(provider) else { throw EngineError.sourceDisabled }
        await discover(provider: provider, interactive: interactive, restoreRemoved: true)
        try publish()
        try await refreshAll(provider: provider)
    }

    func saveConfiguration(_ next: Configuration) throws {
        var next = next
        next.schemaVersion = 5
        if let order = next.preferences.accountOrder {
            let ids = next.accounts.map(\.account.id)
            let known = Set(ids)
            let retained = order.filter { known.contains($0) }
            let positioned = Set(retained)
            next.preferences.accountOrder = retained + ids.filter { !positioned.contains($0) }
        }
        do { try configurationStore.save(next) } catch { configurationFailed = true; broadcast(); throw error }
        configuration = next
        configurationFailed = false
    }

    func discover(
        provider: Provider, interactive: Bool, restoreRemoved: Bool, prepared: [Discovered]? = nil,
        sourceFilter requestedSource: OptionalCredentialSource? = nil
    ) async {
        guard let adapter = adapters[provider] else { return }
        let expandScope = pendingDiscovery.contains(provider) && requestedSource != nil
        let sourceFilter = expandScope ? nil : requestedSource
        let session = lifecycle
        pendingDiscovery.insert(provider)
        let version = UUID()
        discoveryVersions[provider] = version
        let affected = accounts.filter {
            $0.provider == provider && (sourceFilter == nil || $0.optionalCredentialSource == sourceFilter)
        }
        for account in affected {
            invalidate(account.id)
            secrets[account.id] = nil
            operations[account.id] = .connecting
        }
        broadcast()
        let environment = dependencies.environment
        let scoped = DiscoveryEnvironment(
            home: environment.home, processEnvironment: environment.processEnvironment,
            fileSystem: environment.fileSystem, keychain: environment.keychain, allowsUserInteraction: interactive,
            credentialDatabase: environment.credentialDatabase,
            enabledCredentialSources: sourceFilter.map { Set([$0]) } ?? configuration.preferences
                .enabledCredentialSources ?? [])
        do {
            var discoveries: [Discovered]
            if let prepared, !expandScope {
                discoveries = prepared
            } else {
                discoveries = try await adapter.discover(
                    in: scoped, http: limitedHTTPClient(allowedHosts: type(of: adapter).descriptor.allowedHosts))
            }
            guard started, lifecycle == session, discoveryVersions[provider] == version else { return }
            if let sourceFilter {
                discoveries = discoveries.filter { $0.account.optionalCredentialSource == sourceFilter }
            } else {
                discoveries += await manualDiscoveries(provider: provider, interactive: interactive)
                guard started, lifecycle == session, discoveryVersions[provider] == version else { return }
            }
            var next = configuration
            if restoreRemoved {
                next.removed.removeAll {
                    $0.provider == provider && $0.credential != .manual
                        && (sourceFilter == nil || $0.optionalCredentialSource == sourceFilter)
                }
            }
            var credentials: [(AccountID, Secret?, FetchError?)] = []
            var changedCredentials: Set<AccountID> = []
            var ambiguousSourceFailure: FetchError?
            for discovered in discoveries {
                let candidate = discovered.account
                guard candidate.provider == provider else {
                    throw FetchError.schemaChanged(detail: "discovery.provider")
                }
                guard !next.removed.contains(where: { sameAccount($0, candidate) }) else { continue }
                if candidate.identity == nil, discovered.secret == nil, candidate.credential != .manual {
                    let known = next.accounts.filter {
                        $0.account.provider == provider && $0.account.credential == candidate.credential
                            && $0.account.identity != nil
                    }
                    if known.count > 1 {
                        let failure = discovered.connectionError ?? .credentialMissing
                        ambiguousSourceFailure = failure
                        credentials += known.map { ($0.account.id, nil, failure) }
                        continue
                    }
                }
                let match = discoveryMatch(discovered, in: next.accounts)
                let restoredID =
                    restoreRemoved ? configuration.removed.first(where: { sameAccount($0, candidate) })?.id : nil
                let id = match.map { next.accounts[$0].account.id } ?? restoredID ?? candidate.id
                let previous = match.map { next.accounts[$0].account }
                let previousRevision = match.flatMap { next.accounts[$0].credentialRevision }
                if let revision = discovered.secret?.revision, let previousRevision, revision != previousRevision {
                    changedCredentials.insert(id)
                }
                let account = Account(
                    id: id, provider: provider, credential: candidate.credential,
                    identity: candidate.identity ?? (discovered.secret == nil ? previous?.identity : nil),
                    plan: candidate.plan ?? (discovered.secret == nil ? previous?.plan : nil), region: candidate.region,
                    teamID: candidate.teamID)
                if let match {
                    next.accounts[match].account = account
                } else {
                    next.accounts.append(ManagedAccount(account: account, preferences: AccountPreferences()))
                }
                if let revision = discovered.secret?.revision,
                    let index = next.accounts.firstIndex(where: { $0.account.id == id })
                {
                    next.accounts[index].credentialRevision = revision
                }
                credentials.append((id, discovered.secret, discovered.connectionError))
            }
            let obsolete = obsoletePlaceholders(in: next.accounts, provider: provider)
            next.accounts.removeAll { obsolete.contains($0.account.id) }
            credentials.removeAll { obsolete.contains($0.0) }
            try saveConfiguration(next)
            for id in obsolete {
                invalidate(id)
                operations[id] = nil
                states[id] = nil
                secrets[id] = nil
                schedules[id] = nil
                credentialFailures[id] = nil
            }
            for (id, secret, reason) in credentials {
                let available = secret != nil || (reason == nil && adapter is any LocalProviderAdapter)
                let sourceRecovered = available && credentialFailures[id] != nil
                let sourceWasBlocked: Bool
                switch states[id] {
                case .unavailable(let error), .stale(_, let error):
                    sourceWasBlocked = error == .keychainLocked || error == .credentialMissing
                default: sourceWasBlocked = false
                }
                secrets[id] = secret
                credentialFailures[id] = reason
                if !available {
                    states[id] = credentialFailureState(id, error: reason ?? .credentialMissing)
                } else if states[id] == nil {
                    states[id] = .pending
                }
                var schedule = schedules[id, default: RefreshSchedule()]
                if sourceRecovered && !schedule.parked { schedule.nextAutomatic = .distantPast }
                if restoreRemoved || changedCredentials.contains(id)
                    || (sourceWasBlocked && available && !schedule.authenticationParked)
                {
                    schedule.parked = false
                    schedule.authenticationParked = false
                    schedule.nextAutomatic = .distantPast
                }
                schedules[id] = schedule
            }
            for account in affected
            where accounts.contains(where: { $0.id == account.id })
                && !obsolete.contains(account.id) && !credentials.contains(where: { $0.0 == account.id })
            {
                credentialFailures[account.id] = .credentialMissing
                states[account.id] = credentialFailureState(account.id, error: .credentialMissing)
            }
            setDiscoveryError(ambiguousSourceFailure, provider: provider)
        } catch {
            guard started, lifecycle == session, discoveryVersions[provider] == version else { return }
            setDiscoveryError(safeError(error), provider: provider)
            for account in affected where accounts.contains(where: { $0.id == account.id }) {
                states[account.id] = credentialFailureState(account.id, error: safeError(error))
            }
        }
        pendingDiscovery.remove(provider)
        for account in accounts
        where account.provider == provider && (sourceFilter == nil || account.optionalCredentialSource == sourceFilter)
        {
            operations[account.id] = .idle
        }
        broadcast()
    }

    func sameAccount(_ lhs: Account, _ rhs: Account) -> Bool {
        guard lhs.provider == rhs.provider else { return false }
        if let identity = lhs.identity, let other = rhs.identity { return identity == other }
        if lhs.id == rhs.id { return true }
        return lhs.credential != .manual && lhs.identity == nil && rhs.identity == nil
            && lhs.region == rhs.region && lhs.teamID == rhs.teamID
            && lhs.credential == rhs.credential
    }
}
