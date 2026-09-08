public enum Registry {
    /// Adding a provider is one folder under `Providers/` and one entry here.
    public static let adapters: [any ProviderAdapter] = [
        CodexAdapter(), ClaudeCodeAdapter(), DeepSeekAdapter(), MoonshotAdapter(), KimiCodeAdapter(), ZhipuAdapter(),
        MiniMaxAdapter(), XAIAdapter(), GrokAdapter(), CursorAdapter(), AntigravityAdapter(),
    ]
}
