import SwiftUI
import WaterlineKit

struct OptionalSourcesView: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optional sources").font(.headline)
            ForEach(OptionalCredentialSource.allCases, id: \.self) { source in row(source) }
        }
    }

    private func row(_ source: OptionalCredentialSource) -> some View {
        let enabled = model.snapshot.preferences.enabledCredentialSources?.contains(source) == true
        return VStack(alignment: .leading, spacing: 8) {
            Toggle(
                LocalizedStringKey(title(source)),
                isOn: Binding(
                    get: { enabled },
                    set: { value in
                        Task { await model.setOptionalSource(source, enabled: value) }
                    })
            ).disabled(model.changingOptionalSource != nil)
            if source == .deepSeekEnvironment {
                Text(
                    "Reads only the environment inherited by this app. The key is sent only to api.deepseek.com; shell startup files are not read."
                )
                .font(.caption).foregroundStyle(.secondary)
                Text("If the variable is unavailable in this app session, add a key manually.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if source == .zhipuClaudeSettings {
                Text(
                    "Reads personal GLM Coding Plan credentials only for the official China or international endpoint in ~/.claude/settings.json. Team plans are not verified."
                )
                .font(.caption).foregroundStyle(.secondary)
            } else if source == .antigravityCLI {
                Text(
                    "Reads quota from the running Antigravity CLI on this Mac. Open the CLI and sign in there first; Waterline does not launch it or copy its tokens."
                )
                .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(
                    "Reads ~/.claude/settings.json only when it declares the direct DeepSeek endpoint. Commands, helpers and project overrides are not evaluated."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Check source") { Task { await model.checkOptionalSource(source) } }
                    .disabled(
                        !enabled || model.changingOptionalSource != nil
                            || model.snapshot.preferences.disabledProviders.contains(source.provider))
                if model.changingOptionalSource == source { ProgressView().controlSize(.small) }
            }
            if enabled && model.changingOptionalSource == nil
                && !model.snapshot.accounts.contains(where: { $0.account.optionalCredentialSource == source })
            {
                Text("No account is available from this source.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func title(_ source: OptionalCredentialSource) -> String {
        switch source {
        case .antigravityCLI: "Read Antigravity CLI quota"
        case .zhipuClaudeSettings: "Read GLM from Claude Code settings"
        case .deepSeekEnvironment: "Read DEEPSEEK_API_KEY"
        case .deepSeekClaudeSettings: "Read DeepSeek from Claude Code settings"
        }
    }
}
