# Waterline

English · [简体中文](README.zh-CN.md)

A native macOS notch and menu-bar app for checking your coding-assistant subscription usage.

## Install

Download **Waterline-0.1.0-arm64.dmg** from [Releases](https://github.com/AlfredTuTu/Waterline/releases/latest),
open it, and drag Waterline to Applications. Requires Apple Silicon and macOS 14 or later.

If macOS blocks the first launch, open **System Settings → Privacy & Security → Open Anyway**.
To update, quit Waterline and replace it with the newer app.

## Everyday use

- The compact island shows your chosen account's icon and remaining percentage.
- Click to expand the account cards. Drag cards to reorder; changes save automatically.
- Choose the daily account from the pin menu.
- Use the Waterline footer menu to reorder accounts, collapse the island or quit.
- Switch language from the macOS menu-bar menu.

Waterline connects to saved native logins on first launch. Approve Keychain access when macOS asks.

## Supported accounts

| Account | Login source | Usage |
| --- | --- | --- |
| ChatGPT / Codex | Saved Codex login | Subscription windows |
| Claude Code | Saved login, Claude desktop history and CLI status line | 5-hour, weekly and additional reported windows |
| Cursor | Local Cursor login | Plan and model usage pools |
| Grok / SuperGrok | Saved Grok Build consumer login | Subscription usage |
| Antigravity | Running, signed-in native CLI | Gemini and Claude/GPT quota groups |

## Refresh

Accounts normally refresh every 60 seconds. Claude also reads matching desktop history and new
Claude Code sessions' status-line data; its network fallback runs at most once every five minutes.
Existing custom Claude status lines are preserved. Updates resume automatically after provider rate limits.

Waterline runs locally without a backend or telemetry. Credentials go to the corresponding provider;
local quota capture does not save conversations. See [provider contracts](docs/providers/README.md)
for source details and refresh behavior.

## Build

Use Xcode 26.6 / Swift 6.3 at `/Applications/Xcode.app`.

```sh
make verify
CONFIGURATION=release make app
make run
```

The app is generated at `build/Waterline.app`. `make verify` runs the build, tests, formatting and
repository checks. Tests use isolated fixtures. To read the stored snapshot:

```sh
.build/debug/waterline snapshot --json
```

## Project

- `Sources`: shared engine, native app and CLI.
- `Tests`: logic and regression tests.
- `Resources`: localized strings, icons and installation text.
- `Scripts`: build, packaging and verification tools.
- `docs`: provider contracts, UI behavior and release evidence.

[Project rules](AGENTS.md) · [UI behavior](docs/ui.md) ·
[Release evidence](docs/release-readiness.md) · [License](LICENSE)
