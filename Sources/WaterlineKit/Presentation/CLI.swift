import Foundation

public struct CLIResult: Sendable {
    public let exitCode: Int32
    public let output: String
    public let error: String
}

public enum WaterlineCLI {
    public static let help = """
        usage: waterline <command>
          snapshot [--json]
          analyze-codex-log <path> [--json]
          accounts [--json]
          refresh [--provider <provider>] [--json]
          connect <provider> [--json]
          source enable|disable|check <source> [--json]
          source list [--json]
          sources: deepseek-env, deepseek-claude-settings, antigravity-cli, zhipu-claude-settings
          account enable|disable|pin|unpin|remove <id>
          account rename <id> <name>
          account add <provider> --stdin [--region <region>] [--team <id>] [--json]
          account key <id> --stdin [--json]
          version
        """

    public static func run(
        _ arguments: [String], dependencies: Engine.Dependencies = .init(), inputSecret: Secret? = nil
    ) async -> CLIResult {
        guard let command = arguments.first else { return CLIResult(exitCode: 0, output: help + "\n", error: "") }
        if command == "--help" { return CLIResult(exitCode: 0, output: help + "\n", error: "") }
        switch command {
        case "version":
            guard arguments.count == 1 else { return invalid() }
            return CLIResult(exitCode: 0, output: "waterline \(WaterlineVersion.current)\n", error: "")
        case "analyze-codex-log":
            guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--json") else { return invalid() }
            return analyzeCodexLog(URL(fileURLWithPath: arguments[1]), json: arguments.contains("--json"))
        case "snapshot", "accounts":
            guard arguments.count == 1 || arguments.dropFirst() == ["--json"] else { return invalid() }
            do {
                guard let snapshot = try dependencies.store.load() else {
                    return CLIResult(exitCode: 2, output: "", error: "No saved snapshot. Run waterline refresh.\n")
                }
                return CLIResult(
                    exitCode: 0, output: try render(snapshot, json: arguments.contains("--json")), error: "")
            } catch { return failure(error) }
        case "refresh":
            var selected: Provider?
            var json = false
            var remaining = Array(arguments.dropFirst())
            while !remaining.isEmpty {
                let option = remaining.removeFirst()
                if option == "--json", !json { json = true; continue }
                guard option == "--provider", selected == nil, !remaining.isEmpty,
                    let provider = Provider(rawValue: remaining.removeFirst())
                else { return invalid() }
                selected = provider
            }
            var scoped = dependencies
            if let selected {
                scoped.adapters = dependencies.adapters.filter { type(of: $0).descriptor.provider == selected }
                guard !scoped.adapters.isEmpty else { return invalid("Provider is not implemented.\n") }
            }
            return await execute(scoped, json: json, provider: selected, checksFetch: true) { engine in
                try await engine.start()
                try await engine.refreshAll()
                return nil
            }
        case "connect":
            guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--json"),
                let provider = Provider(rawValue: arguments[1]),
                dependencies.adapters.contains(where: { type(of: $0).descriptor.provider == provider })
            else { return invalid() }
            // The executable announces interactive access before invoking this command.
            var scoped = dependencies
            scoped.adapters = dependencies.adapters.filter { type(of: $0).descriptor.provider == provider }
            return await execute(
                scoped, json: arguments.contains("--json"), provider: provider, checksFetch: true
            ) { engine in
                try await engine.connect(provider: provider, interactive: true)
                return nil
            }
        case "source":
            if arguments.count >= 2, arguments[1] == "list" {
                guard arguments.count == 2 || (arguments.count == 3 && arguments[2] == "--json") else {
                    return invalid()
                }
                do {
                    let preferences =
                        try ConfigurationStore(
                            url: dependencies.store.url.deletingLastPathComponent().appending(
                                path: "configuration.json")
                        )
                        .load()?.preferences ?? dependencies.store.load()?.preferences ?? UserPreferences()
                    let statuses = OptionalCredentialSource.allCases.map { source in
                        SourceStatus(
                            source: source.commandName,
                            enabled: preferences.enabledCredentialSources?.contains(source) == true,
                            providerEnabled: !preferences.disabledProviders.contains(source.provider))
                    }
                    let output =
                        arguments.contains("--json")
                        ? String(decoding: try SnapshotStore.encoder.encode(statuses), as: UTF8.self)
                        : statuses.map {
                            "\($0.source)  \($0.enabled ? "enabled" : "disabled")\($0.providerEnabled ? "" : "  [provider paused]")"
                        }.joined(separator: "\n")
                    return CLIResult(exitCode: 0, output: output + "\n", error: "")
                } catch { return failure(error) }
            }
            guard arguments.count == 3 || (arguments.count == 4 && arguments[3] == "--json"),
                ["enable", "disable", "check"].contains(arguments[1]),
                let source = OptionalCredentialSource.allCases.first(where: { $0.commandName == arguments[2] })
            else { return invalid() }
            var scoped = dependencies
            scoped.adapters = dependencies.adapters.filter { type(of: $0).descriptor.provider == source.provider }
            guard !scoped.adapters.isEmpty else { return invalid("Provider is not implemented.\n") }
            return await execute(
                scoped, json: arguments.contains("--json"), provider: source.provider,
                checksFetch: arguments[1] != "disable", source: source
            ) { engine in
                if arguments[1] == "check" {
                    try await engine.connectOptionalCredentialSource(source)
                } else {
                    try await engine.setOptionalCredentialSource(source, enabled: arguments[1] == "enable")
                }
                return nil
            }
        case "account":
            if arguments.count >= 2, arguments[1] == "add" || arguments[1] == "key" {
                guard arguments.count >= 4, let inputSecret else {
                    return invalid("Supply the key through piped stdin.\n")
                }
                var tail = Array(arguments.dropFirst(3))
                var region: String?
                var teamID: String?
                var stdin = false
                var json = false
                while !tail.isEmpty {
                    switch tail.removeFirst() {
                    case "--stdin" where !stdin: stdin = true
                    case "--json" where !json: json = true
                    case "--region" where region == nil && arguments[1] == "add" && !tail.isEmpty:
                        region = tail.removeFirst()
                    case "--team" where teamID == nil && arguments[1] == "add" && !tail.isEmpty:
                        teamID = tail.removeFirst()
                    default: return invalid()
                    }
                }
                guard stdin else { return invalid("Supply the key through piped stdin.\n") }
                if arguments[1] == "add" {
                    guard let provider = Provider(rawValue: arguments[2]),
                        dependencies.adapters.contains(where: {
                            type(of: $0).descriptor.provider == provider && type(of: $0).descriptor.supportsManualKey
                        })
                    else { return invalid("Provider does not support manual keys.\n") }
                    var scoped = dependencies
                    scoped.adapters = dependencies.adapters.filter { type(of: $0).descriptor.provider == provider }
                    return await execute(
                        scoped, json: arguments.contains("--json"), provider: provider, checksFetch: true
                    ) { engine in
                        return try await engine.addManualAccount(
                            provider: provider, key: inputSecret, region: region, teamID: teamID)
                    }
                }
                let id = AccountID(rawValue: arguments[2])
                return await execute(
                    dependencies, json: arguments.contains("--json"), provider: nil, checksFetch: true
                ) { engine in
                    try await engine.start()
                    try await engine.replaceManualKey(id, key: inputSecret)
                    return id
                }
            }
            guard arguments.count >= 3 else { return invalid() }
            let action = arguments[1]
            guard ["enable", "disable", "pin", "unpin", "remove", "rename"].contains(action),
                arguments.count == (action == "rename" ? 4 : 3)
            else { return invalid() }
            let id = AccountID(rawValue: arguments[2])
            return await execute(dependencies, json: false, provider: nil, checksFetch: false) { engine in
                try await engine.start()
                switch action {
                case "enable", "disable": try await engine.setAccountEnabled(id, enabled: action == "enable")
                case "pin", "unpin": try await engine.setAccountPinned(id, pinned: action == "pin")
                case "rename": try await engine.renameAccount(id, label: arguments[3])
                case "remove": try await engine.removeAccount(id)
                default: break
                }
                return nil
            }
        default: return invalid()
        }
    }

    private struct SourceStatus: Encodable {
        let source: String
        let enabled: Bool
        let providerEnabled: Bool
    }

    private static func execute(
        _ dependencies: Engine.Dependencies, json: Bool, provider: Provider?, checksFetch: Bool,
        source: OptionalCredentialSource? = nil,
        action: (Engine) async throws -> AccountID?
    ) async -> CLIResult {
        let engine = Engine(dependencies: dependencies)
        do {
            let requestedAccount = try await action(engine)
            let snapshot = await engine.snapshot()
            let output = try render(snapshot, json: json)
            await engine.stop()
            let failed =
                checksFetch && hasFetchFailure(snapshot, provider: provider, account: requestedAccount, source: source)
            let missingSourceAccount =
                source.map { requested in
                    !snapshot.accounts.contains { $0.account.optionalCredentialSource == requested }
                } ?? false
            return CLIResult(
                exitCode: snapshot.historyFailed ? 1 : failed ? 2 : 0, output: output,
                error: snapshot.historyFailed
                    ? "Readings are available, but balance history could not be saved.\n"
                    : failed
                        ? (missingSourceAccount
                            ? "No account was found for the requested optional source. Check the source configuration.\n"
                            : "One or more requested accounts could not be refreshed.\n") : "")
        } catch {
            let snapshot = await engine.snapshot()
            await engine.stop()
            let result = failure(error)
            if json, snapshot.storageFailed, let output = try? render(snapshot, json: true) {
                return CLIResult(exitCode: result.exitCode, output: output, error: result.error)
            }
            return result
        }
    }

    private static func hasFetchFailure(
        _ snapshot: Snapshot, provider: Provider?, account: AccountID?,
        source: OptionalCredentialSource?
    ) -> Bool {
        let targetProvider = provider ?? snapshot.accounts.first(where: { $0.account.id == account })?.account.provider
        if snapshot.sourceFailures.contains(where: { targetProvider == nil || $0.provider == targetProvider }) {
            return true
        }
        let relevant = snapshot.accounts.filter {
            (account == nil || $0.account.id == account) && (provider == nil || $0.account.provider == provider)
                && (source == nil || $0.account.optionalCredentialSource == source)
                && $0.isEnabled(in: snapshot.preferences)
        }
        if relevant.isEmpty { return true }
        return relevant.contains { entry in
            switch entry.state {
            case .fresh: false;
            default: true
            }
        }
    }

    private static func render(_ snapshot: Snapshot, json: Bool) throws -> String {
        if json { return String(decoding: try SnapshotStore.encoder.encode(snapshot), as: UTF8.self) + "\n" }
        var lines = ["Snapshot \(snapshot.generatedAt.formatted(.iso8601))"]
        for entry in snapshot.accounts {
            let name = entry.preferences.label ?? entry.account.provider.displayName
            lines.append(
                "\(printable(name))  \(entry.account.id)\(entry.isEnabled(in: snapshot.preferences) ? "" : "  [paused]")\(entry.preferences.pinned ? "  [pinned]" : "")"
            )
            if let reading = entry.state.reading {
                for window in reading.usage.quotaWindows {
                    let fraction = window.usedFraction.map { String(format: "%.1f%%", $0 * 100) } ?? "Not reported"
                    lines.append(
                        "  \(printable(window.label)): \(fraction)\(window.error == nil ? "" : " [earlier reading]")")
                }
                for window in reading.usage.quotaWindows where window.limit != nil {
                    lines.append(
                        "  \(printable(window.label)): \(window.used.map { $0.description } ?? "Not reported") / \(window.limit!.description) \(printable(window.unit ?? "units"))"
                    )
                }
                for balance in reading.usage.balances {
                    lines.append(
                        "  \(balance.basis == .postedLedger ? "Posted prepaid credit: " : "")\(balance.amount) \(printable(balance.currency))\(balance.error == nil ? "" : " [earlier reading]")"
                    )
                }
                if case .unsupported(let reason) = reading.usage { lines.append("  \(printable(reason))") }
                for failure in reading.usage.componentFailures {
                    lines.append("  \(printable(failure.id)): \(failure.error.message)")
                }
            }
            switch entry.state {
            case .unavailable(let error), .stale(_, let error): lines.append("  \(error.message)")
            case .expired: lines.append("  Earlier reading; refresh required")
            case .pending: lines.append("  Not refreshed")
            case .fresh, .partial: break
            }
        }
        for source in snapshot.sourceFailures {
            lines.append("\(source.provider.displayName): \(source.error.message)")
        }
        if snapshot.storageFailed { lines.append("State could not be saved") }
        if snapshot.historyFailed { lines.append("Balance history could not be saved") }
        if snapshot.pendingSecretCleanup > 0 {
            lines.append("Saved-key deletion is pending; unlock Keychain and retry cleanup in Settings.")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func printable(_ text: String) -> String {
        String(text.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) })
    }

    private static func invalid(_ detail: String = "") -> CLIResult {
        CLIResult(exitCode: 64, output: "", error: detail + help + "\n")
    }

    private static func failure(_ error: any Error) -> CLIResult {
        switch error {
        case WriterLockError.busy:
            CLIResult(
                exitCode: 3, output: "", error: "Waterline is running. Use the app to change or refresh accounts.\n")
        case SettingsError.accountNotFound:
            CLIResult(exitCode: 2, output: "", error: "Account not found. Run waterline accounts.\n")
        case EngineError.sourceDisabled:
            CLIResult(exitCode: 2, output: "", error: "Enable the requested source before connecting or checking it.\n")
        case ManualKeyError.invalidTeam:
            CLIResult(exitCode: 64, output: "", error: "Provide a valid team ID with --team.\n")
        case ManualKeyError.invalidRegion:
            CLIResult(exitCode: 64, output: "", error: "Choose a supported account region with --region.\n")
        case ManualKeyError.invalidKey:
            CLIResult(exitCode: 64, output: "", error: "Key is empty or contains invalid characters.\n")
        case ManualKeyError.saveFailed:
            CLIResult(
                exitCode: 1, output: "",
                error: "Could not save the key. Unlock Keychain and update the pending account’s key.\n")
        case ManualKeyError.cleanupPending:
            CLIResult(
                exitCode: 1, output: "",
                error: "Account removed; saved-key deletion is pending. Retry cleanup in Settings.\n")
        case SettingsError.invalidLabel:
            CLIResult(exitCode: 64, output: "", error: "Use a single-line account name of at most 80 characters.\n")
        default:
            CLIResult(
                exitCode: 1, output: "",
                error: "Waterline could not complete the operation. Check source access and storage.\n")
        }
    }
}
