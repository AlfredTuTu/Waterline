import Foundation

extension DeepSeekAdapter {
    func discoverOpenCode(in environment: DiscoveryEnvironment) -> [Discovered] {
        let url = environment.home.appending(path: ".local/share/opencode/auth.json")
        guard environment.fileSystem.exists(url) else { return [] }
        let reference = CredentialRef.configuration(source: .deepSeekOpenCode, path: url.path, key: "deepseek")
        do {
            // A named provider can be overridden. Never probe the vendor with an ambiguously routed key.
            for name in ["OPENCODE_CONFIG", "OPENCODE_CONFIG_CONTENT", "XDG_CONFIG_HOME", "XDG_DATA_HOME"] {
                if let value = environment.processEnvironment[name], !value.isEmpty {
                    throw FetchError.schemaChanged(detail: "opencode.customConfiguration")
                }
            }
            for name in ["opencode.json", "opencode.jsonc"] {
                let config = environment.home.appending(path: ".config/opencode/\(name)")
                if environment.fileSystem.exists(config) {
                    let data = try environment.fileSystem.contents(of: config, maximumBytes: 1_048_576)
                    guard
                        let root = try JSONSerialization.jsonObject(with: data, options: [.json5Allowed])
                            as? [String: Any]
                    else { throw FetchError.schemaChanged(detail: "opencode.settings") }
                    if let providers = root["provider"] {
                        guard let entries = providers as? [String: Any], entries["deepseek"] == nil else {
                            throw FetchError.schemaChanged(detail: "opencode.provider.deepseek.override")
                        }
                    }
                }
            }
            let data = try environment.fileSystem.contents(of: url, maximumBytes: 1_048_576)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FetchError.schemaChanged(detail: "opencode.auth")
            }
            guard let selected = root["deepseek"] else { return [] }
            guard let auth = selected as? [String: Any], let type = auth["type"] as? String else {
                throw FetchError.schemaChanged(detail: "opencode.auth.deepseek.type")
            }
            guard type == "api" else { return [] }
            guard let key = auth["key"] as? String else { throw FetchError.credentialMissing }
            return [Self.credential(key, reference: reference, field: "opencode.auth.deepseek.key")]
        } catch {
            return [
                Discovered(
                    account: Account(provider: .deepseek, credential: reference), secret: nil,
                    connectionError: (error as? FetchError) ?? .schemaChanged(detail: "opencode.configuration"))
            ]
        }
    }
}
