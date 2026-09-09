public enum Provider: String, CaseIterable, Codable, Sendable {
    case claudeCode = "claude-code"
    case codex
    case cursor
    case grok
    case xai
    case antigravity
    case zhipu
    case kimiCode = "kimi-code"
    case moonshot
    case minimax
    case deepseek
    case qwen

    public var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "ChatGPT"
        case .cursor: "Cursor"
        case .grok: "Grok"
        case .xai: "xAI"
        case .antigravity: "Antigravity"
        case .zhipu: "Zhipu GLM"
        case .kimiCode: "Kimi Code"
        case .moonshot: "Moonshot"
        case .minimax: "MiniMax"
        case .deepseek: "DeepSeek"
        case .qwen: "Qwen"
        }
    }
}
