import Foundation

extension Engine {
    func discoveryMatch(_ discovered: Discovered, in managed: [ManagedAccount]) -> Int? {
        let candidate = discovered.account
        if candidate.optionalCredentialSource == .deepSeekOpenCode, let revision = discovered.secret?.revision {
            if let exact = managed.firstIndex(where: { sameAccount($0.account, candidate) }) { return exact }
            let matchingManual = managed.indices.filter {
                let known = managed[$0]
                return known.account.provider == candidate.provider && known.account.credential == .manual
                    && known.account.region == candidate.region && known.account.teamID == candidate.teamID
                    && known.account.identity == nil && known.credentialRevision == revision
            }
            if matchingManual.count == 1 { return matchingManual[0] }
        }
        let unknownScope = candidate.identity == nil && discovered.secret == nil
        let sameSource = managed.indices.filter {
            candidate.credential != .manual && managed[$0].account.provider == candidate.provider
                && managed[$0].account.credential == candidate.credential
                && ((unknownScope && candidate.region == nil) || managed[$0].account.region == candidate.region)
                && ((unknownScope && candidate.teamID == nil) || managed[$0].account.teamID == candidate.teamID)
        }
        if candidate.identity == nil, discovered.secret == nil {
            let identified = sameSource.filter { managed[$0].account.identity != nil }
            if identified.count == 1 { return identified[0] }
        }
        if let exact = managed.firstIndex(where: { sameAccount($0.account, candidate) }) { return exact }
        if candidate.identity != nil {
            let placeholders = sameSource.filter { managed[$0].account.identity == nil }
            if placeholders.count == 1 { return placeholders[0] }
        }
        return nil
    }

    /// Only reconcile empty, untouched source placeholders. Known identities and user data stay separate.
    func obsoletePlaceholders(in managed: [ManagedAccount], provider: Provider) -> Set<AccountID> {
        guard historyLoaded else { return [] }
        return Set(
            managed.compactMap { row in
                let account = row.account
                guard account.provider == provider, account.credential != .manual, account.identity == nil,
                    !(configuration.preferences.notchAccountIDs?.contains(account.id) ?? false),
                    row.preferences == AccountPreferences(), states[account.id]?.reading == nil,
                    !pendingSecretCleanup.contains(account.id),
                    !historyRecords.contains(where: { $0.accountID == account.id }),
                    !historyPending.contains(where: { $0.accountID == account.id })
                else { return nil }
                let identified = managed.filter {
                    $0.account.provider == provider && $0.account.credential == account.credential
                        && $0.account.identity != nil
                }
                return identified.count == 1 ? account.id : nil
            })
    }
}
