import Foundation

public enum ManualKeyError: Error {
    case invalidTeam
    case invalidRegion
    case invalidKey
    case unsupportedProvider
    case notManualAccount
    case saveFailed
    case cleanupPending
}

extension Engine {
    public func addManualAccount(
        provider: Provider, key: Secret, label: String? = nil, region: String? = nil, teamID: String? = nil
    ) async throws -> AccountID {
        try validateManualKey(key)
        guard let adapter = adapters[provider], type(of: adapter).descriptor.supportsManualKey else {
            throw ManualKeyError.unsupportedProvider
        }
        let regions = type(of: adapter).descriptor.manualRegions
        guard regions.isEmpty ? region == nil : regions.contains(where: { $0.id == region }) else {
            throw ManualKeyError.invalidRegion
        }
        let team = teamID?.trimmingCharacters(in: .whitespacesAndNewlines)
        if type(of: adapter).descriptor.requiresTeamID {
            guard let team, !team.isEmpty, team.count <= 128,
                team.unicodeScalars.allSatisfy({
                    CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
                        .contains($0)
                })
            else { throw ManualKeyError.invalidTeam }
        } else if teamID != nil {
            throw ManualKeyError.invalidTeam
        }
        try await start()
        guard !configuration.preferences.disabledProviders.contains(provider) else { throw EngineError.sourceDisabled }
        let account = Account(provider: provider, credential: .manual, region: region, teamID: team)
        var next = configuration
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines)
        next.accounts.append(
            ManagedAccount(
                account: account,
                preferences: AccountPreferences(label: trimmedLabel?.isEmpty == true ? nil : trimmedLabel)))
        next.accounts[next.accounts.count - 1].credentialRevision = key.revision
        try saveConfiguration(next)
        states[account.id] = .pending
        do {
            try dependencies.ownedSecrets.save(key, for: account.id)
        } catch {
            states[account.id] = .unavailable(error: .credentialMissing)
            try publish()
            throw ManualKeyError.saveFailed
        }
        secrets[account.id] = key
        try publish()
        try await refreshAccount(account.id)
        return account.id
    }

    public func replaceManualKey(_ id: AccountID, key: Secret) async throws {
        try validateManualKey(key)
        guard started else { throw SettingsError.engineNotStarted }
        guard let index = configuration.accounts.firstIndex(where: { $0.account.id == id }),
            configuration.accounts[index].account.credential == .manual
        else {
            throw ManualKeyError.notManualAccount
        }
        guard adapters[configuration.accounts[index].account.provider] != nil else {
            throw ManualKeyError.unsupportedProvider
        }
        do { try dependencies.ownedSecrets.save(key, for: id) } catch { throw ManualKeyError.saveFailed }
        invalidate(id)
        secrets[id] = key
        var next = configuration
        next.accounts[index].credentialRevision = key.revision
        do { try saveConfiguration(next) } catch {
            schedules[id, default: RefreshSchedule()].parked = true; broadcast(); throw error
        }
        credentialFailures[id] = nil
        var schedule = schedules[id, default: RefreshSchedule()]
        schedule.parked = false
        schedule.authenticationParked = false
        schedule.nextAutomatic = .distantPast
        schedules[id] = schedule
        try publish()
        try await refreshAccount(id)
    }

    public func reconnectManualAccount(_ id: AccountID) async throws {
        guard started else { throw SettingsError.engineNotStarted }
        guard let account = accounts.first(where: { $0.id == id }), account.credential == .manual else {
            throw ManualKeyError.notManualAccount
        }
        guard adapters[account.provider] != nil, !configuration.preferences.disabledProviders.contains(account.provider)
        else {
            throw EngineError.sourceDisabled
        }
        invalidate(id)
        let operation = UUID()
        generations[id] = operation
        operations[id] = .connecting
        broadcast()
        defer {
            if generations[id] == operation {
                generations[id] = nil
                operations[id] = .idle
                broadcast()
            }
        }
        let key: Secret
        do {
            key = try await dependencies.ownedSecrets.readAsync(id, interactive: true)
            try Task.checkCancellation()
            guard started, generations[id] == operation else { throw CancellationError() }
        } catch {
            guard started, generations[id] == operation, !Task.isCancelled else { throw CancellationError() }
            let failure = (error as? FetchError) ?? .keychainLocked
            secrets[id] = nil
            credentialFailures[id] = failure
            states[id] = credentialFailureState(id, error: failure)
            try publish()
            throw error
        }
        var next = configuration
        if let index = next.accounts.firstIndex(where: { $0.account.id == id }) {
            next.accounts[index].credentialRevision = key.revision
        }
        try saveConfiguration(next)
        secrets[id] = key
        credentialFailures[id] = nil
        schedules[id, default: RefreshSchedule()].parked = false
        schedules[id, default: RefreshSchedule()].authenticationParked = false
        try publish()
        try await refreshAccount(id)
    }

    public func retrySecretCleanup() throws {
        guard started else { throw SettingsError.engineNotStarted }
        cleanRemovedSecrets()
        try publish()
        if !pendingSecretCleanup.isEmpty { throw ManualKeyError.cleanupPending }
    }

    func cleanRemovedSecrets() {
        // Only an explicit account removal authorizes deletion, including a retained old manual key.
        // Following a source never adds the account to configuration.removed.
        for account in configuration.removed
        where adapters[account.provider] != nil
            && (account.credential == .manual || configuration.retainedManualSecrets?.contains(account.id) == true)
        {
            do {
                try dependencies.ownedSecrets.delete(account.id)
                pendingSecretCleanup.remove(account.id)
            } catch { pendingSecretCleanup.insert(account.id) }
        }
    }

    func manualDiscoveries(provider: Provider, interactive: Bool) async -> [Discovered] {
        let session = lifecycle
        let selected = accounts.filter { $0.provider == provider && $0.credential == .manual }
        var discovered: [Discovered] = []
        for account in selected {
            guard started, lifecycle == session else { return [] }
            do {
                let secret = try await dependencies.ownedSecrets.readAsync(account.id, interactive: interactive)
                discovered.append(Discovered(account: account, secret: secret))
            } catch {
                discovered.append(
                    Discovered(
                        account: account, secret: nil, connectionError: (error as? FetchError) ?? .keychainLocked))
            }
        }
        return discovered
    }

    private func validateManualKey(_ key: Secret) throws {
        guard !key.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            key.value.count <= 8192,
            !key.value.unicodeScalars.contains(where: {
                CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.controlCharacters.contains($0)
            })
        else {
            throw ManualKeyError.invalidKey
        }
    }
}
