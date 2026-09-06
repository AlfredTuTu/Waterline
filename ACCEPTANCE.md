# Acceptance

Two layers: gates that run on every change, and a checklist per milestone. A task is done when its
issue's acceptance list holds, `make verify` passes, and the milestone checklist items it touches can be
ticked without caveats.

## Gates — `make verify`

| Gate | Command | Passes when |
|---|---|---|
| Build | `xcrun swift build` | no errors; new deprecation warnings are explained in the PR |
| Tests | `xcrun swift test` | every test passes; no test opens a socket or reads the real Keychain |
| Format | `xcrun swift-format lint --strict --recursive Package.swift Sources Tests` | no findings |
| Whitespace | `git diff --check`, `git diff --cached --check` | no trailing whitespace or conflict markers |
| Audit | `Scripts/audit.sh` | `WaterlineKit` imports no AppKit/SwiftUI; no secret-shaped strings in `Sources`, `Tests`, `docs`, `README.md`; every `Package.swift` dependency is on the allowlist |

CI (`.github/workflows/ci.yml`) runs exactly `make verify` on `macos-26` with Xcode 26.6.

## Standards every change meets

- A number on screen or in `snapshot.json` came from a provider response or is marked as an estimate (`≈`, secondary colour). Never a placeholder zero.
- A secret is only sent to an `allowedHosts` entry, is never logged, never written outside the app's own Keychain entries.
- No Keychain prompt unless the user clicked something that says it will read the Keychain.
- Idle app: CPU under 1 %, memory under 120 MB, no timer faster than the documented refresh intervals.
- New behaviour has a test that fails without the change.

## v0.1 — engine, notch, Claude Code / Codex / Cursor / xAI

- [ ] `main` is green on CI.
- [ ] `Registry.adapters` contains `claudeCode`, `codex`, `cursor`, `xai`; each folder has fixtures for a good reading, an auth failure and a changed schema, and tests for each.
- [ ] `waterline refresh --provider <p> --json` on the owner's machine returns `fresh` for all four; every `resetsAt` is in the future; xAI also returns a balance.
- [ ] Airplane mode: the app keeps showing the last reading greyed with its age; `snapshot.json` holds `stale` entries with the transport error; nothing shows zero.
- [ ] Launch after login shows no Keychain prompt; the Claude Code row reads "needs connect" until Connect is clicked, then reads normally.
- [ ] Collapsed panel height equals `safeAreaInsets.top`; hover expands after about 150 ms and leaving collapses; click pins; an external display gets the floating capsule; only one panel exists across displays.
- [ ] Collapsed bar shows exactly one metric — the highest window fraction, or the smallest balance when no windows exist — with the colours in `docs/ui.md`.
- [ ] Expanded panel: one row per account, window rows and balance rows visually distinct, stale rows greyed with age, unavailable rows show only the reason.
- [ ] Bundle launches with no Dock icon; the menu bar item offers Refresh and Quit; idle CPU under 1 %, memory under 120 MB after ten minutes.
- [ ] Disk writes are limited to `~/Library/Application Support/Waterline/` (checked with `fs_usage -f filesys` during a refresh cycle).
- [ ] `docs/providers/claude-code.md`, `codex.md`, `cursor.md`, `xai.md` have the response mapping filled in and a `last verified` date.
- [ ] `v0.1.0` tagged on `main`.

## v0.2 — Chinese providers, Tier-2 discovery, gateways

- [ ] Zhipu, Kimi Code, Moonshot, MiniMax and DeepSeek adapters meet the v0.1 adapter bar (fixtures, live check, docs).
- [ ] A Kimi Code subscription and a Moonshot top-up on one machine appear as two rows.
- [ ] Tier-2 sources are off by default; enabling one is a single toggle per source and discovery shows the file each key came from.
- [ ] A harness configured with a gateway `baseURL` shows the gateway's quota with a "via" label and never attributes it to a local account.
- [ ] `history.jsonl` grows by one line per balance reading; burn rate and days-left appear only after two readings and are marked as estimates.

## v0.3 — onboarding, settings, public

- [ ] First launch explains what is read and where it is sent, per provider, with Tier 1 on and Tier 2 off; the Keychain prompt is announced before it appears.
- [ ] Settings covers accounts (source, enable, add manual key), thresholds, intervals, privacy (per-host allowlist shown), language, launch at login.
- [ ] Antigravity adapter meets the adapter bar; Qwen shows as unsupported with the reason.
- [ ] Every string is localised zh-Hans and en and follows the system.
- [ ] Every `docs/providers/*.md` has a `last verified` within 30 days of the release.
- [ ] Repository is public with CONTRIBUTING and a bug template.

## v0.4 — alerts and activity

- [ ] A window crossing the threshold or a balance below its threshold expands the panel for 3 s once per account per hour and posts a system notification.
- [ ] Balance rows show a 7-day sparkline from `history.jsonl`.
- [ ] Claude Code `Stop` / `Notification` hooks drive the activity state without heuristics.

## v1.0 — distribution

- [ ] Sparkle updates with an EdDSA-signed appcast; Homebrew cask; notarised DMG.
- [ ] A person who has never seen the repository installs from the README and sees data within one minute.
