import Foundation

extension ZhipuAdapter {
    func discoverClaudeSettings(in environment: DiscoveryEnvironment) throws -> [Discovered] {
        guard environment.enabledCredentialSources.contains(.zhipuClaudeSettings) else { return [] }
        let url = environment.home.appending(path: ".claude/settings.json")
        guard environment.fileSystem.exists(url) else { return [] }
        let data = try environment.fileSystem.contents(of: url, maximumBytes: 1_048_576)
        let routing: Routing
        do { routing = try JSONDecoder().decode(Routing.self, from: data) } catch {
            throw schemaError(error, prefix: "claude-settings")
        }
        guard let raw = routing.env?.ANTHROPIC_BASE_URL, let base = URL(string: raw),
            base.scheme?.lowercased() == "https", base.user == nil, base.password == nil,
            base.port == nil || base.port == 443, base.query == nil, base.fragment == nil,
            ["/api/anthropic", "/api/anthropic/"].contains(base.path(percentEncoded: true)),
            let region = Self.descriptor.manualRegions.first(where: { $0.host == base.host()?.lowercased() })
        else { return [] }
        let reference = CredentialRef.configuration(
            source: .zhipuClaudeSettings, path: url.path, key: "ANTHROPIC_AUTH_TOKEN")
        let account = Account(provider: .zhipu, credential: reference, region: region.id)
        let credentials: Credentials
        do { credentials = try JSONDecoder().decode(Credentials.self, from: data) } catch {
            return [
                Discovered(
                    account: account, secret: nil,
                    connectionError: schemaError(error, prefix: "claude-settings"))
            ]
        }
        guard let value = credentials.env?.ANTHROPIC_AUTH_TOKEN else {
            return [Discovered(account: account, secret: nil, connectionError: .credentialMissing)]
        }
        guard !value.isEmpty, value.utf8.count <= 8192,
            value.unicodeScalars.allSatisfy({
                !CharacterSet.whitespacesAndNewlines.contains($0) && !CharacterSet.controlCharacters.contains($0)
            })
        else {
            return [
                Discovered(
                    account: account, secret: nil,
                    connectionError: .schemaChanged(detail: "claude-settings.env.ANTHROPIC_AUTH_TOKEN"))
            ]
        }
        return [Discovered(account: account, secret: Secret(value))]
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
