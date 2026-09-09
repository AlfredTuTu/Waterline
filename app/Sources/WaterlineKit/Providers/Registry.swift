public enum Registry {
    /// Current product scope: native subscription accounts only. API adapters remain deferred in the kit.
    public static let adapters: [any ProviderAdapter] = [
        CodexAdapter(), ClaudeCodeAdapter(), GrokAdapter(), CursorAdapter(), AntigravityAdapter(),
    ]
    public static var activeProviders: Set<Provider> {
        Set(adapters.map { type(of: $0).descriptor.provider })
    }
}
