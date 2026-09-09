# Waterline

A native macOS notch and menu-bar app for checking coding-assistant subscription
usage. Waterline runs on your Mac without a backend or telemetry.

## Everyday use

- Keep one chosen account's icon and remaining percentage in the compact island.
- Click the island to open the account cards; hovering does not enlarge it.
- Drag cards to change their display order. The footer **Waterline → Account display
  order** opens the native ordering list. Changes save automatically.
- Choose the daily account from the pin menu.
- Language selection is in the macOS menu-bar menu. Waterline does not register for launch at login.
- Collapse the island or quit from its Waterline menu.

There is no separate settings page, Token records window, API-key entry screen or
connection wizard. The first launch attempts to connect saved native logins.
macOS may require you to approve access to protected credentials. Later background
work never presents a Keychain prompt; failed authorization has a conditional
Connect action. Existing account data is preserved during updates.

## Supported sources

| Account | Source | Current scope |
| --- | --- | --- |
| ChatGPT / Codex | Saved Codex login | Reported subscription windows |
| Claude Code | Saved login, matching desktop GUI history and official CLI status-line data | Reported 5h/7d windows and additional server-reported windows |
| Cursor | Local Cursor login database | Reported plan/model pools and other available usage windows |
| Grok / SuperGrok | Grok Build's saved consumer login | Consumer subscription usage; not Cursor Grok Bot or developer API billing |
| Antigravity | Already-running, signed-in native CLI | Reported Gemini and Claude/GPT quota groups |

Provider contracts and evidence limits are in [docs/providers](docs/providers/README.md).
Not every tier, OS version or login arrangement has been live-tested. Missing
values stay unavailable, and old observations retain their age. A zero is only
shown when the provider reports it or its documented representation implies it.
Standalone API-balance integrations are deferred; previous local keys, records
and history are not deleted by this product simplification.

## Claude updates

For an identified Claude account, Waterline also reads the matching desktop app's
local usage history. It checks both the current desktop user and the latest sample's
organization, keeps the original sample time, and never fabricates reset times.
The desktop app controls its own updates (observed 5-minute active / 15-minute idle
polling with additional native pause conditions). GUI records expire after 30 minutes;
unchanged file reads do not extend freshness. Valid local data is not invalidated
merely because a fallback server request fails.

Waterline's installed CLI can receive the official Claude Code `rate_limits`
status-line payload. With a supported default login and no existing custom status
line, Waterline adds its receiver and makes a private backup of Claude's settings.
Existing status lines and disabled-hook settings are preserved. Custom credential
or provider overrides are not silently attributed to the default account.

A new Claude Code session establishes its account binding before the first model
request. A normal model response can then deliver quota data locally without an
additional quota HTTP request. Receiving the same cached values again does not
make them newer. Existing sessions first attached after they have already made
requests are not guessed into an account; start a new session for local capture.
Only quotas, reset times and the association needed for correctness are stored,
with a maximum of 128 session records. No transcript or workspace content is saved.

Ordinary Claude network fallback runs no more frequently than every five minutes;
opening the island does not shorten this interval. Reset boundaries and explicit
manual requests remain subject to backoff. Other providers use their current
automatic policy, normally 60 seconds. Provider rate limits retry silently and
progressively back off; cached values remain distinguishable from new observations.
**Five minutes is Waterline policy, not a published Anthropic API allowance.**

## Build and verify

Requires the project's pinned Xcode 26.6 / Swift 6.3 toolchain at
`/Applications/Xcode.app`. The deployment target is macOS 14; that declaration is
not a claim that every supported OS has been tested.

```sh
make verify
CONFIGURATION=release make app
make run
```

`make verify` builds, runs Swift tests, checks formatting and whitespace, and runs
repository audit/script checks. Tests inject files, HTTP and Keychain implementations;
they never query real providers or the real Keychain.

The app bundle is generated at `build/Waterline.app`. The CLI's read-only snapshot
and account commands are useful while the app owns the engine's writer lock:

```sh
.build/debug/waterline snapshot --json
.build/debug/waterline accounts --json
```

Live refresh/connect commands use real saved logins and must be run intentionally.
The app and CLI cannot concurrently mutate the same engine state.

## Performance and release status

Final acceptance is tracked in [ACCEPTANCE.md](ACCEPTANCE.md). Measurements must
identify the exact installed binary, account configuration and observation period.
To measure an already-running real-account app without restarting it:

```sh
python3 Scripts/measure-runtime.py \
  --pid <WaterlineApp-PID> \
  --executable /absolute/path/Waterline.app/Contents/MacOS/WaterlineApp \
  --snapshot "$HOME/Library/Application Support/Waterline/snapshot.json" \
  --output build/verification/runtime.json --scope real
```

The protocol uses a 10-minute warmup and 10-minute sample. The targets are mean CPU
below 1% of one core and physical memory below 120 MB. Do not substitute RSS for
physical footprint or divide CPU usage by the number of cores.

Version 0.1.0 uses owner-approved, ad-hoc-signed, unnotarized distribution. If macOS blocks its first launch, use **System Settings → Privacy &
Security → Open Anyway** and confirm the system prompt. Do not disable Gatekeeper.
Updates are manual. See [release readiness](docs/release-readiness.md) for artifact
checks; Developer ID signing, notarization and automatic update delivery are not
claimed. Repository visibility remains private unless explicitly changed.

## Repository map

- `Sources/WaterlineKit`: model, provider adapters, engine, persistence and presentation logic.
- `Sources/WaterlineApp`: native scenes, notch panel and thin UI integration.
- `Sources/WaterlineCLI`: command-line entry point and local quota receiver.
- `Tests/WaterlineKitTests`: offline logic and regression coverage.
- `Resources`: localized strings and shipping assets.
- `Scripts`: reproducible builds, verification, packaging and performance measurement.
- `docs`: current contracts and decisions. Superseded records remain in Git history.

[Architecture](ARCHITECTURE.md) · [UI behavior](docs/ui.md) ·
[Decisions](docs/decisions.md) · [License](LICENSE)
