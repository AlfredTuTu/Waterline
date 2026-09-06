# Providers

One file per provider is the contract an adapter implements and the place its endpoint's health is
recorded. Endpoints marked *community* were reverse-engineered by open-source tools and can change
without notice; *official* ones are documented by the vendor.

| Provider | `Provider` case | Kind | Doc status | Credential (Tier 1 / 2 / 3) | Milestone |
|---|---|---|---|---|---|
| Claude Code | `claudeCode` | window (5h, 7d) | community | Keychain `Claude Code-credentials`, `~/.claude/.credentials.json` | v0.1 |
| Codex | `codex` | window (5h, weekly) | community | `~/.codex/auth.json` | v0.1 |
| Cursor | `cursor` | window (billing cycle) | community | `state.vscdb` | v0.1 |
| xAI / Grok | `xai` | both | official | manual management key | v0.1 |
| Zhipu GLM | `zhipu` | window (5h, weekly, MCP) | community | `ZAI_API_KEY` → `ZHIPU_API_KEY` → `BIGMODEL_API_KEY` | v0.2 |
| Kimi Code | `kimiCode` | window | community | `KIMI_CODING_API_KEY` → `KIMI_CODE_API_KEY` | v0.2 |
| Moonshot | `moonshot` | balance | official | `MOONSHOT_API_KEY` → `MOONSHOTAI_API_KEY` | v0.2 |
| MiniMax | `minimax` | both | community | `MINIMAX_API_KEY` → `MINIMAX_CN_API_KEY` → `MINIMAX_INTL_API_KEY` | v0.2 |
| DeepSeek | `deepseek` | balance | official | `DEEPSEEK_API_KEY` | v0.2 |
| Antigravity | `antigravity` | window (per model) | community | accounts file | v0.3 |
| Qwen / Bailian | `qwen` | unsupported | — | `DASHSCOPE_API_KEY`, `~/.bailian/config.json` | v0.3 |

Candidate endpoints in these files were collected in September 2026 from public tools that read the same
sources (CodexBar, dsh-provider-balance, claude-token-monitor, dushan-quota). They are notes, not code:
implement from the provider's live behaviour, record what you observed, and set `last verified`.

## Adding a provider

1. Create `Sources/WaterlineKit/Providers/<Name>/<Name>Adapter.swift` conforming to `ProviderAdapter`.
   `descriptor.allowedHosts` lists every host the adapter contacts.
2. `discover(in:)` reads only the locations in this provider's file, through the injected environment,
   and returns `secret: nil` instead of prompting.
3. `fetch(_:secret:http:)` maps the response to `Usage` field by field; anything unexpected throws
   `FetchError.schemaChanged(detail:)`; 401/403 → `.unauthorized`; 429 → `.rateLimited(retryAfter:)`.
4. Capture real responses with `waterline refresh --provider <p> --json --dump <dir>`, redact them
   into `Tests/WaterlineKitTests/Fixtures/<provider>/` (see the README there) and test: good reading,
   auth failure, rate limit, changed schema; discovery from a synthetic home directory.
5. Register in `Providers/Registry.swift`.
6. Fill the response mapping and `last verified` in `docs/providers/<name>.md`.

## Verifying

`last verified` is the day someone ran the live check against a real account and the mapping held.
When a provider changes its response, the fixture test fails first; fix the mapping, add the new shape
as a fixture, bump the date.
