import Foundation

public enum OptionalCredentialSource: String, Codable, CaseIterable, Sendable {
    case deepSeekEnvironment
    case deepSeekClaudeSettings
    case deepSeekOpenCode
    case antigravityCLI
    case zhipuClaudeSettings
    public var provider: Provider {
        switch self {
        case .antigravityCLI: .antigravity
        case .zhipuClaudeSettings: .zhipu
        case .deepSeekEnvironment, .deepSeekClaudeSettings, .deepSeekOpenCode: .deepseek
        }
    }
    public var commandName: String {
        switch self {
        case .antigravityCLI: "antigravity-cli"
        case .zhipuClaudeSettings: "zhipu-claude-settings"
        case .deepSeekOpenCode: "deepseek-opencode"
        case .deepSeekEnvironment: "deepseek-env"
        case .deepSeekClaudeSettings: "deepseek-claude-settings"
        }
    }
}

extension Account {
    public var optionalCredentialSource: OptionalCredentialSource? {
        if provider == .antigravity, credential == .localService(name: "antigravity-cli") { return .antigravityCLI }
        if case .configuration(let source, _, _) = credential, source.provider == provider { return source }
        if provider == .deepseek, credential == .env(name: "DEEPSEEK_API_KEY", sourceFile: "process") {
            return .deepSeekEnvironment
        }
        return nil
    }
}

extension UserPreferences {
    public func allowsSource(for account: Account) -> Bool {
        guard !disabledProviders.contains(account.provider) else { return false }
        switch account.credential {
        case .env, .configuration, .localService:
            guard let source = account.optionalCredentialSource else { return false }
            return enabledCredentialSources?.contains(source) == true
        default: return true
        }
    }
}

extension AccountEntry {
    public func isEnabled(in preferences: UserPreferences) -> Bool {
        self.preferences.enabled && preferences.allowsSource(for: account)
    }
}
