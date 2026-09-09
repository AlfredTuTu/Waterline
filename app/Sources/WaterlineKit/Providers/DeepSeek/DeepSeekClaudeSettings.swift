import Foundation

extension DeepSeekAdapter {
    func discoverClaudeSettings(in environment: DiscoveryEnvironment) -> [Discovered] {
        let url = environment.home.appending(path: ".claude/settings.json")
        guard environment.fileSystem.exists(url) else { return [] }
        let reference = CredentialRef.configuration(
            source: .deepSeekClaudeSettings, path: url.path, key: "ANTHROPIC_AUTH_TOKEN")
        do {
            let data = try environment.fileSystem.contents(of: url, maximumBytes: 1_048_576)
            let routing = try JSONDecoder().decode(Routing.self, from: data)
            guard let raw = routing.env?.ANTHROPIC_BASE_URL, let base = URL(string: raw),
                base.scheme?.lowercased() == "https", base.host()?.lowercased() == "api.deepseek.com",
                base.user == nil, base.password == nil, base.port == nil || base.port == 443,
                base.query == nil, base.fragment == nil, ["/anthropic", "/anthropic/"].contains(base.path)
            else { return [] }
            let settings = try JSONDecoder().decode(Credentials.self, from: data)
            guard let value = settings.env?.ANTHROPIC_AUTH_TOKEN else {
                return [
                    Discovered(
                        account: Account(provider: .deepseek, credential: reference), secret: nil,
                        connectionError: .credentialMissing)
                ]
            }
            return [Self.credential(value, reference: reference, field: "claude-settings.env.ANTHROPIC_AUTH_TOKEN")]
        } catch {
            return [
                Discovered(
                    account: Account(provider: .deepseek, credential: reference), secret: nil,
                    connectionError: schemaError(error, prefix: "claude-settings"))
            ]
        }
    }

    private struct Routing: Decodable {
        struct Environment: Decodable { let ANTHROPIC_BASE_URL: String? }
        let env: Environment?
    }
    private struct Credentials: Decodable {
        struct Environment: Decodable { let ANTHROPIC_AUTH_TOKEN: String? }
        let env: Environment?
    }
}
