import Foundation

extension Engine {
    var fileCredentialChecks: [(provider: Provider, source: OptionalCredentialSource?)] {
        var checks: [(Provider, OptionalCredentialSource?)] = [(.codex, nil), (.cursor, nil)]
        if configuration.preferences.enabledCredentialSources?.contains(.deepSeekOpenCode) == true {
            checks.append((.deepseek, .deepSeekOpenCode))
        }
        if configuration.preferences.enabledCredentialSources?.contains(.deepSeekClaudeSettings) == true {
            checks.append((.deepseek, .deepSeekClaudeSettings))
        }
        if configuration.preferences.enabledCredentialSources?.contains(.antigravityCLI) == true {
            checks.append((.antigravity, .antigravityCLI))
        }
        if configuration.preferences.enabledCredentialSources?.contains(.zhipuClaudeSettings) == true {
            checks.append((.zhipu, .zhipuClaudeSettings))
        }
        return checks.filter { adapters[$0.0] != nil && !configuration.preferences.disabledProviders.contains($0.0) }
    }

    /// Read-only file or opted-in local-service discovery; never permits interactive Keychain access.
    func checkChangedFileCredentials() async {
        guard started, !suspended else { return }
        nextCredentialCheck = dependencies.now().addingTimeInterval(60)
        let session = lifecycle
        let environment = dependencies.environment
        for (provider, source) in fileCredentialChecks {
            guard let adapter = adapters[provider], !configuration.preferences.disabledProviders.contains(provider),
                !pendingDiscovery.contains(provider)
            else { continue }
            let version = discoveryVersions[provider]
            let background = DiscoveryEnvironment(
                home: environment.home, processEnvironment: environment.processEnvironment,
                fileSystem: environment.fileSystem, keychain: environment.keychain, allowsUserInteraction: false,
                credentialDatabase: environment.credentialDatabase,
                enabledCredentialSources: source.map { Set([$0]) } ?? [])
            do {
                let discovered = try await adapter.discover(
                    in: background,
                    http: limitedHTTPClient(allowedHosts: type(of: adapter).descriptor.allowedHosts))
                guard started, !suspended, lifecycle == session else { return }
                guard discoveryVersions[provider] == version,
                    !configuration.preferences.disabledProviders.contains(provider),
                    source.map({ configuration.preferences.enabledCredentialSources?.contains($0) == true }) ?? true
                else { continue }
                let candidates = discovered.filter { candidate in
                    (source == nil || candidate.account.optionalCredentialSource == source)
                        && !configuration.removed.contains { sameAccount($0, candidate.account) }
                }
                let existing = configuration.accounts.filter {
                    $0.account.provider == provider && $0.account.credential != .manual
                        && (source == nil || $0.account.optionalCredentialSource == source)
                }
                let matches: (ManagedAccount, Discovered) -> Bool = { known, candidate in
                    self.sameAccount(known.account, candidate.account)
                        || (candidate.secret == nil && candidate.account.identity == nil
                            && known.account.credential == candidate.account.credential
                            && (candidate.account.region == nil || known.account.region == candidate.account.region)
                            && (candidate.account.teamID == nil || known.account.teamID == candidate.account.teamID))
                }
                let changed =
                    candidates.contains { candidate in
                        guard
                            let known = existing.first(where: { matches($0, candidate) })
                        else { return true }
                        return secrets[known.account.id]?.revision != candidate.secret?.revision
                            || credentialFailures[known.account.id] != candidate.connectionError
                            || ((candidate.secret != nil || adapter is any LocalProviderAdapter)
                                && (known.account.identity != candidate.account.identity
                                    || known.account.plan != candidate.account.plan))
                    }
                    || existing.contains { known in
                        !candidates.contains(where: { matches(known, $0) })
                            && (secrets[known.account.id] != nil
                                || credentialFailures[known.account.id] != .credentialMissing)
                    }
                if changed || discoveryErrors[provider] != nil {
                    await discover(
                        provider: provider, interactive: false, restoreRemoved: false, prepared: discovered,
                        sourceFilter: source)
                }
            } catch {
                guard started, !suspended, lifecycle == session, discoveryVersions[provider] == version,
                    !configuration.preferences.disabledProviders.contains(provider),
                    source.map({ configuration.preferences.enabledCredentialSources?.contains($0) == true }) ?? true
                else {
                    continue
                }
                setDiscoveryError(safeError(error), provider: provider)
                for account in accounts
                where account.provider == provider && account.credential != .manual
                    && (source == nil || account.optionalCredentialSource == source)
                {
                    invalidate(account.id)
                    secrets[account.id] = nil
                    credentialFailures[account.id] = safeError(error)
                    states[account.id] = credentialFailureState(account.id, error: safeError(error))
                }
                broadcast()
            }
        }
    }
}
