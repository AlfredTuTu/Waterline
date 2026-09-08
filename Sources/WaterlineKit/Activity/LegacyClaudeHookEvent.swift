/// Retained only to remove entries written by older Waterline versions.
public enum LegacyClaudeHookEvent: String, CaseIterable, Sendable {
    case began = "UserPromptSubmit"
    case stopped = "Stop"
    case failed = "StopFailure"
    case ended = "SessionEnd"
}

public enum HookActivityError: Error, Equatable { case invalidSettings, hooksDisabled }
