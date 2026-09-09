import Foundation

public enum ClaudeStatuslineCapture {
    public static func capture(input: Data, login: Data, accounts: [Account], directory: URL, now: Date) throws {
        let reading = try ClaudeStatusline.parse(input)
        let local = try ClaudeLocalLogin.identity(login)
        let candidates = accounts.filter {
            $0.provider == .claudeCode && $0.identity.map { ClaudeLocalLogin.matches(local, verified: $0) } == true
        }
        guard candidates.count == 1, let identity = candidates.first?.identity else {
            throw FetchError.credentialMissing
        }
        try ClaudeLocalObservationStore(directory: directory).capture(
            reading, localIdentity: local,
            verifiedIdentity: identity, receivedAt: now)
    }

    /// No Keychain or network access. A custom Claude configuration needs its own verified identity route.
    public static func run(input: Data, home: URL, environment: [String: String]) throws {
        let overrides = [
            "CLAUDE_CONFIG_DIR", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL",
            "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY",
        ]
        guard !overrides.contains(where: { environment[$0].map { !$0.isEmpty && $0 != "0" } ?? false }) else {
            throw FetchError.credentialMissing
        }
        let files = RealFileSystem()
        let directory = home.appending(path: "Library/Application Support/Waterline")
        let snapshot = try SnapshotStore.decoder.decode(
            Snapshot.self,
            from: files.contents(of: directory.appending(path: "snapshot.json"), maximumBytes: 16_777_216))
        let login = try files.contents(of: home.appending(path: ".claude.json"), maximumBytes: 4_194_304)
        try capture(
            input: input, login: login, accounts: snapshot.accounts.map(\.account),
            directory: directory.appending(path: "claude-local-observations"), now: Date())
    }
}
