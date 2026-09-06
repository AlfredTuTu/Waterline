# Architecture

Current state of the system. History and reasons live in `docs/decisions.md`; the UI in `docs/ui.md`;
each provider's contract in `docs/providers/`.

## Purpose

One glance at the notch answers "how much of my AI coding quota is left, and when does it come back" —
for subscriptions (Claude Code, Codex, Cursor, Zhipu, Kimi Code, MiniMax, Antigravity) and for prepaid
balances (DeepSeek, Moonshot, xAI, MiniMax). Accounts are discovered from credentials the tools already
store on the machine. Nothing leaves the Mac except the provider calls themselves.

## Process model

There is no backend process. One `LSUIElement` app runs the **engine** in-process; the UI is one client
of it and the `waterline` CLI is the other. The engine writes every state change to
`~/Library/Application Support/Waterline/snapshot.json` (atomic replace). That file plus the CLI is the
integration surface: statusline scripts, Raycast, other agents read it; there is no IPC, socket or
local HTTP server. Should data be needed while the app is closed, the engine is already headless and
can be hosted by a LaunchAgent without changing anything below it.

## Modules

| Target | Kind | Contents |
|---|---|---|
| `WaterlineKit` | library | `Model`, `Providers`, `Host`, `Engine`, `Snapshot`, `Presentation`. No AppKit, no SwiftUI (`Scripts/audit.sh` enforces). |
| `WaterlineCLI` | executable `waterline` | `snapshot`, `refresh`, `accounts`, `account add`, `version`. |
| `WaterlineApp` | executable, bundled by `Scripts/bundle-app.sh` | SwiftUI `App` lifecycle, `MenuBarExtra`, the notch `NSPanel`, views. Thin. |
| `WaterlineKitTests` | tests | Swift Testing. `Fixtures/<provider>/` are redacted real responses. |

Adapters are folders inside the kit (`Providers/<Name>/`), not a module. Presentation logic that the UI
derives from state — which metric the collapsed bar shows, ordering, health colour, notch geometry —
lives in `Presentation/` so it is unit-tested; the app target only renders.

## Data model (`Sources/WaterlineKit/Model`)

```swift
enum Provider: String        // claude-code codex cursor xai antigravity zhipu kimi-code moonshot minimax deepseek qwen

struct AccountID             // "<provider>:<8 hex of sha256(secret)>"
enum CredentialRef           // .keychain(service, account) | .file(path) | .env(name, sourceFile) | .manual
struct Account               // id, provider, credential — the secret itself is never persisted
struct Secret                // in-memory only; not Codable, not printable; has `fingerprint`
struct Discovered            // account + secret? (nil when reading it would have prompted)

struct UsageWindow           // label ("5h", "7d", …), usedFraction 0…1, resetsAt
struct Balance               // amount, currency (ISO 4217), gift?
enum Usage                   // .windows(windows:, plan:) | .balance(balance:) | .both(windows:, balance:) | .unsupported(reason:)

struct Reading               // usage + fetchedAt
enum FetchError              // credentialMissing | keychainLocked | unauthorized | rateLimited(retryAfter:) | schemaChanged(detail:) | transport(detail:)
enum AccountState            // pending | fresh(reading:) | stale(reading:, error:) | unavailable(error:)
struct Snapshot              // generatedAt + [AccountEntry(account, state)] — the file on disk
```

The credential is the primary key. One vendor can be zero, one or several accounts on a machine
(a Kimi Code subscription and a Moonshot top-up are two accounts). Calls routed through a gateway
(Hermes, OpenCode Go, a relay) belong to no local account; v0.2 adds
`Route { harness, baseURL, credentialRef? }` so such rows show the gateway's quota labelled "via …".

Adapters answer "what did the API say"; the engine owns freshness. `stale` keeps the last good reading
next to the latest error so the UI can grey it and show its age. `unavailable` means never succeeded;
only the reason is shown. Nothing in the model can express an estimated number.

## Adapter contract (`Providers/ProviderAdapter.swift`)

```swift
protocol ProviderAdapter: Sendable {
    static var descriptor: ProviderDescriptor { get }    // provider, kind, docStatus (official | community), allowedHosts, consoleURL
    func discover(in environment: DiscoveryEnvironment) async throws -> [Discovered]
    func fetch(_ account: Account, secret: Secret, http: any HTTPClient) async throws -> Usage
}
```

- `discover` is read-only against the injected `DiscoveryEnvironment` (home directory, process
  environment, file system, keychain, `allowsUserInteraction`). It returns `secret: nil` when the
  secret sits behind a Keychain prompt and interaction is not allowed.
- `fetch` receives an `HTTPClient` already scoped to `descriptor.allowedHosts`; a request anywhere else
  throws `HostNotAllowed` before it leaves the process.
- Only fields the provider returned are mapped. No plan names guessed, no price tables, no defaults.
  A response that does not match the recorded shape throws `FetchError.schemaChanged`.
- One provider = `Providers/<Name>/` + one entry in `Registry.adapters` + `docs/providers/<name>.md`
  + fixtures.

## Engine (`Engine/Engine.swift`, an actor)

- `start()` — run every adapter's `discover`, seed each account's state from the previous snapshot
  (so the UI shows something within a second) and publish.
- `refreshAll()` — fetch every account, map `FetchError` (and any transport error) into
  `stale`/`unavailable`, publish.
- `updates` — `AsyncStream<Snapshot>`; `snapshot()` — current value. Every publish writes the file.
- `Dependencies` injects adapters, environment, HTTP client factory, store and clock; tests drive the
  whole engine with fakes and a fixed `now`.

Scheduling (v0.1, issue-tracked): window accounts refresh every 60 s while a harness is active
(`~/.claude/projects`, `~/.codex/sessions`, Cursor's workspace storage written within the last
10 minutes), otherwise every 5 minutes; balance accounts every 5 minutes. HTTP 429 honours
`Retry-After`, else exponential backoff capped at 30 minutes. 401/403 parks the account as
`unavailable(.unauthorized)` until its credential source changes (file mtime, Keychain re-read on
connect). Manual refresh from the menu or CLI bypasses the schedule.

## Credential discovery (`Host/DiscoveryEnvironment.swift`, adapters' `discover`)

| Tier | Source | Default |
|---|---|---|
| 1 — tool login state | Claude Code: Keychain item `Claude Code-credentials` or `~/.claude/.credentials.json`. Codex: `~/.codex/auth.json`. Cursor: `state.vscdb` (system `SQLite3`, opened read-only). Antigravity: its accounts file. | on |
| 2 — config scanning | `~/.claude/settings.json` `env`; `export NAME=value` lines in `~/.zshrc`, `~/.zprofile`, `~/.bash_profile` (regex, never executed); vendor fallback chains such as `ZAI_API_KEY → ZHIPU_API_KEY → BIGMODEL_API_KEY`. | off, opt-in per source |
| 3 — manual | `waterline account add <provider>` (v0.1) and Settings (v0.3), stored in this app's own Keychain entries. | — |

A GUI process launched from Finder does not inherit shell `export`s, which is why Tier 2 reads files
instead of the environment. Keychain policy: background reads run with user interaction disabled and
map a would-be prompt to `FetchError.keychainLocked`; a user-initiated connect reads once with
interaction allowed and keeps the secret in memory. Waterline never writes to or refreshes another
tool's credentials.

## Persistence

| What | Where | Notes |
|---|---|---|
| State | `~/Library/Application Support/Waterline/snapshot.json` | atomic replace; ISO-8601 dates; sorted keys |
| Balance history (v0.2) | `…/Waterline/history.jsonl` | one line per balance reading, feeds burn rate, days-left and sparkline |
| Settings | `UserDefaults` (bundle id `io.github.alfredtutu.waterline`) | thresholds, intervals, Tier-2 opt-ins, disabled accounts |
| Manual secrets | Keychain, service = bundle id, account = `AccountID` | the only Keychain writes the app makes |

## Presentation

`Presentation/NotchGeometry` computes the panel frame from screen metrics (`safeAreaInsets.top`,
`auxiliaryTopLeftArea`, `auxiliaryTopRightArea`) — notch layout when a housing exists, a floating
capsule otherwise. `Dashboard` (v0.1) derives the collapsed metric, ordering and health colour from a
`Snapshot`. Both are pure and tested. The app hosts SwiftUI views in a borderless non-activating
`NSPanel` above the menu bar; see `docs/ui.md`.

## Testing

- Parsers: fixtures per provider — a good reading, an auth failure, a rate limit, a changed schema.
- Discovery: a synthetic home directory built in a temporary folder; a fake `KeychainReading`.
- Engine: fake clock, fake HTTP client, in-memory store; assert state transitions and backoff.
- Presentation: table-driven derivations.
- Live checks only through `waterline refresh …`, only on request; never in `make verify` or CI.

## Toolchain and build

Xcode 26.6 / Swift 6.3, `swift-tools-version: 6.2`, macOS 14 minimum, Swift Testing, `xcrun swift-format`.
Pure SwiftPM: no `.xcodeproj`. `Scripts/bundle-app.sh` wraps the executable into `build/Waterline.app`
with `Resources/Info.plist` (`LSUIElement`, version from `Version.swift`) and ad-hoc signs it. No
third-party dependencies before v1.0; the allowlist lives in `Scripts/audit.sh`. CI runs `make verify`
on `macos-26` with `DEVELOPER_DIR=/Applications/Xcode_26.6.app`.

## Roadmap

| Milestone | Scope |
|---|---|
| v0.1 | Kit model, engine, snapshot, HTTP allowlist, Keychain policy; CLI; notch panel with collapsed and expanded states; Claude Code, Codex, Cursor, xAI |
| v0.2 | Zhipu, Kimi Code, Moonshot, MiniMax, DeepSeek; Tier-2 opt-in scanning and fallback chains; gateway routes ("via"); balance history, burn rate, days left |
| v0.3 | Onboarding, Settings window, Antigravity, Qwen as unsupported, zh-Hans + en, every provider verified, repository public |
| v0.4 | Threshold alerts with the activity state and system notifications; sparklines; session activity from Claude Code hooks |
| v1.0 | Sparkle updates, Homebrew cask, DMG, Developer ID notarisation |
