# AGENTS.md

Waterline is a macOS notch/menu-bar app. For every AI coding tool account it finds on this machine it
shows either the subscription window in use (percent used, reset time) or the prepaid balance.
Local-first: it reads credentials other tools already stored, uploads nothing, and never shows a number
the provider did not report.

## Where things are

- `ARCHITECTURE.md` — what to build: process model, modules, data model, adapter contract, engine,
  credential discovery, persistence, testing, toolchain.
- `ACCEPTANCE.md` — what "done" means: the verification gates and each milestone's checklist.
- `docs/ui.md` — the notch UI: states, rows, colours, interactions, geometry.
- `docs/providers/<name>.md` — one contract per provider: credentials, endpoints, response mapping,
  allowed hosts, last verified date. `docs/providers/README.md` has the matrix and how to add one.
- `docs/decisions.md` — why things are the way they are. Append a row when a decision changes.
- GitHub Issues and milestones — the work queue. Nothing to do lives anywhere else.

## Source layout

- `Sources/WaterlineKit` — everything testable: `Model`, `Providers`, `Host`, `Engine`, `Snapshot`,
  `Presentation`. Never imports AppKit or SwiftUI.
- `Sources/WaterlineKit/Providers/<Name>/` — one folder per provider, one line in `Providers/Registry.swift`.
- `Sources/WaterlineCLI` — `waterline`, the engine's second client and the way to verify without the UI.
- `Sources/WaterlineApp` — SwiftUI app lifecycle, the notch `NSPanel`, views. Thin; logic goes in the kit.
- `Tests/WaterlineKitTests` — Swift Testing. `Fixtures/<provider>/` holds redacted real responses.

## Working loop

1. `gh issue list --milestone "<current milestone>" --label agent:codex --state open --json number,title,body`
   Take the lowest number whose "Blocked by" issues are closed. The issue body is the spec; read all of it.
2. `git switch -c codex/<number>-<slug>` from an up-to-date `main`.
3. Implement with tests. Run `make verify` until it passes.
4. Audit the result against the issue's acceptance list and ACCEPTANCE.md; tighten until every line holds.
5. Update the docs the issue names. Adapter work always updates its `docs/providers/<name>.md`.
6. Open a PR with the template; first line `Closes #<number>`. CI must be green. Add the label `status:review`.
7. The owner squash-merges. Never push to `main`.

Scope changes go through the issue: comment and stop when the task turns out different from its
description; label `status:needs-decision` when the choice is the owner's. A changed architectural
decision appends a row to `docs/decisions.md` in the same PR.

## Code rules

- No defensive code. Validate at boundaries — network responses, files on disk, user input — and trust
  the types inside the process: no nil checks on non-optionals, no `try?` around calls that cannot fail,
  no branches for states the type system already rules out.
- No redundant code. No helper used once, no wrapper that only forwards, no comment restating the line
  below it, no dead code, no abstraction or setting for a need that does not exist yet.
- Adapters report what the API returned and throw `FetchError` otherwise. A changed response shape is
  `.schemaChanged`, never a guessed value. Zero is a number, never a placeholder.
- A secret travels only to a host in the adapter's `allowedHosts`; `URLSessionHTTPClient` enforces it.
- Background work never shows a Keychain prompt; only a user-initiated connect may.
- Tests never touch the network or the real Keychain. Fixtures are redacted; `Scripts/audit.sh` checks.
- No new dependency unless the issue says so; then add it to the allowlist in `Scripts/audit.sh`.
- Swift 6 strict concurrency. `WaterlineKit` is nonisolated by default; `WaterlineApp` is `MainActor` by default.
- User-facing text is short and free of implementation words.

## Commands

- `make verify` — build, test, `swift-format lint --strict`, whitespace check, `Scripts/audit.sh`. The one gate; CI runs exactly this.
- `make test`, `xcrun swift test --filter <Name>` — focused runs while iterating.
- `make format` — apply the formatter before committing.
- `make app`, `make run` — bundle `build/Waterline.app` and relaunch it. Only for UI checks.
- `.build/debug/waterline snapshot --json` — what the app last wrote.
- `.build/debug/waterline refresh [--provider <p>] --json` — contacts the real provider APIs with this machine's credentials; run it only when the issue asks for a live check. `--connect` allows one Keychain prompt; `--dump <dir>` keeps raw responses for fixtures.
- Every command pins `DEVELOPER_DIR=/Applications/Xcode.app` (Xcode 26.6, Swift 6.3). Do not switch toolchains.

## Git

- Branches: `codex/<n>-<slug>`, `claude/<n>-<slug>`, `alfred/<slug>`.
- Conventional Commits: `feat(providers): deepseek balance adapter`, `fix(engine): honour Retry-After`. Body ends with `Refs #<n>`.
- No attribution trailers. Commit messages end after `Refs #<n>`; no `Co-Authored-By`, no generated-by line in commits or pull request descriptions. The repository owner is the author of every commit.
- Never commit secrets, `.env`, unredacted captures, `build/` or `.build/`.
