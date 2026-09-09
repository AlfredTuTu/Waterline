# AGENTS.md

Waterline is a macOS notch/menu-bar app showing subscription usage reported for
accounts discovered on this machine. It has no backend or telemetry. Credentials go only to the
appropriate provider endpoints. Missing data stays missing; deterministic calculations are allowed,
and predictions must be labelled as estimates.

## Scope and documentation

Apply Occam's razor: do not add an entity, abstraction, file, feature or workflow unless needed for
the current task. Consolidate duplicate rules; keep one authoritative home for each concern.

This file owns product scope, architecture, development and acceptance. `docs/ui.md` owns detailed
presentation; `docs/providers/` owns source/endpoint/mapping contracts and dated evidence;
`docs/decisions.md` records material decisions. Update affected references together. Later owner
instructions supersede old plans. Requirements are not evidence of implementation: inspect the
current checkout and distinguish targets, completed code and actual verification.

Current scope is five native subscriptions: ChatGPT/Codex, Claude Code, Cursor, independent
Grok/SuperGrok and Antigravity. Discover saved logins directly on first use under macOS authorization.
Hide confirmed nonmembers; a failed read does not prove absent membership. Keep one compact pinned
account, persistent manual card order, shortest reported window first (5h before 7d), and language
selection. No enlargement on hover without additional information.

API-key/balance integrations, estimates, alerts, session activity, Token records, launch at login,
standalone settings/account/onboarding pages and the old milestone roadmap are outside current scope.
Do not restore them without a new request. Preserve existing private account data during UI cleanup.
GitHub Issues track issue-driven work; a direct owner request needs no extra issue.

## Source layout

- `Sources/WaterlineKit` — everything testable: `Model`, `Providers`, `Host`, `Engine`, `Snapshot`,
  `Presentation`. Never imports AppKit or SwiftUI.
- `Sources/WaterlineKit/Providers/<Name>/` — one folder per provider, one line in `Providers/Registry.swift`.
- `Sources/WaterlineCLI` — `waterline`, the engine's second client and the way to verify without the UI.
- `Sources/WaterlineApp` — SwiftUI app lifecycle, the notch `NSPanel`, views. Thin; logic goes in the kit.
- `Tests/WaterlineKitTests` — Swift Testing. `Fixtures/<provider>/` holds reviewed responses and labelled synthetic cases.

## Working loop

1. Read the requested task and relevant documents. For issue-driven work, select the lowest open
   issue in the current milestone assigned to this agent whose dependencies are closed; read its body.
2. Inspect the working tree and preserve unrelated work. For issue-driven implementation, branch from
   an up-to-date `main`; an explicitly local documentation task does not require remote operations.
3. Implement with suitable verification. Use tests for logic and regressions; native app checks for
   UI and OS integration that unit tests cannot establish.
4. Run `make verify` and check applicable acceptance items. Documentation-only work needs no new
   tests; check references, consistency and the existing gate. Report checks that could not run.
5. Update affected contracts and append changed architectural decisions to `docs/decisions.md`.
6. When delivery through GitHub is requested, use the PR template, reference the issue if present,
   ensure CI is green, and add `status:review`. An end-to-end release request authorizes squash merge
   after required checks, tagging, verified artifact upload and Release publication. Use PRs; direct/
   force pushes to the default branch or repository visibility changes need specific authorization.

Latest owner instructions define scope; authorization persists across turns. Do not ask again for
approved actions. Platform permission controls still apply: explain a rejection and never bypass it.
Authorization does not waive verification, data protection or truthful reporting.

Resolve routine implementation choices within the authorised scope and record material trade-offs.
If a change needs an owner decision about product scope, privacy or an incompatible interface, explain
the concrete choice and continue unaffected work. Do not stop the entire task for every discrepancy.
For issue-driven work, record scope changes on the issue and use `status:needs-decision` where needed.

## Complete workflows and external assistance

The frontend and the local backend must form complete working flows. The backend is the kit's engine,
provider, account and persistence logic. A visible action must reach that logic, expose progress and
success/failure, update the UI and persist the result where applicable. Verify restoration after
relaunch. An isolated view, parser, mock response or passing unit test does not complete a user flow.

When useful, use one bounded consultation with Claude Code CLI or explicitly selected Grok through
Cursor CLI for technical/design work. Verify Cursor's exact Grok model ID and available allowance;
model availability is not proof of quota. Cursor Grok Bot consultation quota is separate from the
product's independent Grok account. Antigravity CLI and Figma are frontend design aids only.
These aids are authorized; send minimum redacted context, use read-only permissions for advice and
review any bounded delegated edits. Do not buy credits or enable extra billing without explicit
approval. If quota is unknown, limit calls; unavailable helper quota does not block local work.

Do not presume a blocker before investigating. Inspect code, reproduce the issue, consult primary
documentation and, where useful, consult one of the authorised assistants for alternatives; then test
the selected solution.
Unavailable helper quota does not block local implementation or verification. Escalate only a concrete
remaining dependency requiring owner action, while continuing independent work. Do not invent access,
live evidence or successful verification to avoid reporting an actual limitation.

Close each problem with evidence: establish the failing behaviour or unmet requirement, identify its
cause, implement the correction, repeat the relevant failing scenario and verify the affected user flow.
Advice, a code edit or a green unrelated test is not a resolution. Do not suppress errors, replace real
results with mocks, disable features, weaken assertions or relax acceptance criteria to make a problem
appear fixed. An accurate error message improves handling but does not prove the underlying integration
works. Keep unresolved or unverified items open and report exactly which behaviour remains to be proven.

## Code rules

- Validate network responses, files, OS results and user input at boundaries; trust validated types
  inside the process. Avoid redundant guards, swallowed errors and checks for impossible states.
  Recovery from actual external failures is required, including isolating one failed account.
- Keep abstractions proportionate. A helper used once is useful when it clarifies intent, isolates a
  boundary or enables testing. Remove dead code, forwarding-only wrappers without a purpose, and
  comments that merely restate the code. Do not build for hypothetical needs.
- Map supported provider fields and documented deterministic calculations. Ignore unrelated added
  fields; incompatible required fields produce `FetchError.schemaChanged` naming the field path.
  Retain independently valid metrics when the contract supports partial results. Zero is never a placeholder.
- Keep account identity separate from credentials; rotating a secret must not reset history or settings.
- Send secrets only over HTTPS to the account's documented provider/region endpoints, within the
  adapter's `allowedHosts`. Enforce this on redirects too; never forward credentials to another origin.
- Recurring background work never shows a Keychain prompt. Interactive reads belong only to the
  authorized initial connection or explicit recovery; cancellation must not trigger repeated prompts.
- Automated tests never contact live services or the real Keychain. Fixtures are reviewed and redacted;
  `Scripts/audit.sh` is an additional pattern check, not proof that all private data was removed.
- Prefer system libraries. A new dependency needs a concrete benefit, licence and maintenance review,
  and a decision entry; update the audit allowlist in the same implementation change. Do not introduce
  dependencies during documentation-only work.
- Swift 6 strict concurrency. `WaterlineKit` is nonisolated by default; `WaterlineApp` is `MainActor` by default.
- Main UI text is short and plain. Optional diagnostics may include redacted technical details needed
  to understand a failure; never include credentials, raw headers or raw response bodies.

## Commands

- `make verify` — build, test, `swift-format lint --strict`, whitespace check, `Scripts/audit.sh`. The one gate; CI runs exactly this.
- `make test`, `DEVELOPER_DIR=/Applications/Xcode.app xcrun swift test --filter <Name>` — focused runs while iterating.
- `make format` — apply the formatter before committing.
- `make app`, `make run` — bundle `build/Waterline.app` and relaunch it. Only for UI checks.
- `.build/debug/waterline snapshot --json` — read the last stored snapshot; `version` is also implemented.
- Inspect `Sources/WaterlineCLI` before using additional commands; a planned interface is not an
  implemented command. Authorized real-account checks are bounded and read-only. Raw capture is
  separate and follows `docs/providers/README.md`; secrets never go in command arguments.
- Reference toolchain: Xcode 26.6, Swift 6.3.x. `make` defaults to `/Applications/Xcode.app`; CI selects
  `/Applications/Xcode_26.6.app`. Direct `xcrun` and bundle-script calls need `DEVELOPER_DIR` explicitly.
  Verify versions at these paths; do not silently switch toolchains to make a check pass.

## Git

- Branches: `codex/<n>-<slug>`, `claude/<n>-<slug>`, `alfred/<slug>`; omit the number for authorised work without an issue.
- Conventional Commits: `feat(providers): deepseek balance adapter`, `fix(engine): honour Retry-After`.
  End the body with `Refs #<n>` when there is an issue; never invent a reference.
- No attribution trailers or generated-by lines in commits or PR descriptions. Use the owner's configured authorship.
- Never commit secrets, `.env`, unredacted captures, `build/` or `.build/`.

## Architecture

### Process, accounts and discovery

One `LSUIElement` app runs an engine actor in-process; the CLI uses the same engine headlessly.
Snapshot plus CLI is the integration surface: no daemon, socket or local HTTP service.

Account IDs are stable opaque local IDs, reconciled by provider, region and billing identity. Keep
teams, regions and subscriptions separate. Bind provisional IDs to documented sources until identity
is known. Do not merge by email/model/vendor or derive identity from secrets. Same-account credential
rotation preserves settings/history; account switches and ambiguous matches stay separate. Secrets
remain in memory with redacted descriptions, never serialized.

Read documented files and Keychain items through injected boundaries; open tool databases read-only.
Never execute shell config, scan arbitrary directories for secrets, copy credential databases to
bypass locks, refresh another tool's credentials or probe other provider/region endpoints with a key.
Authorized status-line integration follows its contract and preserves existing configuration.
Background Keychain reads disable interaction. Unreadable sources report a source-local failure,
not an empty account list; locked accounts can retain nonsecret source metadata.

### Metrics and HTTP

- Keep metric ID, unit, scope, receipt time (`fetchedAt`), observation time (`observedAt`) and origin.
  Local records retain their original time: rereading does not renew freshness. A missing reset or
  fraction does not invalidate an independently valid metric.
- Derive percentages only from reported fractions or comparable used/positive-total values. Document
  unit conversions, remaining calculations and countdowns in the provider contract. Unknown is absent,
  never zero. Reject nonfinite/out-of-domain values unless documented; retain overage text, cap only
  bar fill. Legacy balances use `Decimal` and known currencies, never mixed-currency totals.
- Fetch results carry metrics, provenance and component failures. Publish valid independent components;
  retain failed previous components as stale with their own age/error. Optional omission alone cannot
  revive an old value. Use the provider contract's omission semantics.
- Map authentication failures to `unauthorized`, 429 to `rateLimited(retryAfter:)`, network/5xx to
  `transport`. Permission-only 403 does not necessarily mean signed out. Schema errors identify field
  paths without raw response bodies or decoding errors. Ignore unrelated added fields.
- Use the shared ephemeral `URLSessionHTTPClient`, 15-second request and 30-second resource timeouts,
  no persistent cookies/cache or secret-bearing diagnostics. Validate HTTPS, exact host and account
  endpoint before sending. Reject redirects by default; documented same-origin exceptions revalidate.
  Never forward secrets across origins. Update adapter, registration, contract and fixtures together.

### Engine and persistence

- Display valid cached state immediately, then discover/refresh. Isolate failures. Preserve corrupt or
  legacy state for recovery; never overwrite unsupported newer schemas.
- Freshness uses each metric's observation time and documented maximum age (default twice the normal
  interval). Backoff never extends freshness. A passed reset expires that metric and schedules an
  eligible refresh, never a fabricated zero. Local success and network failure remain independent.
- The native app checks enabled accounts every 60 seconds; provider contracts define endpoint limits
  and local observation rules. One engine-wide limiter permits at most four active HTTP requests,
  including discovery/profile calls; cancellation releases or removes its slot. Provider contracts own cadence. Coalesce overlapping requests; respect `Retry-After`, fallback backoff
  and authentication parking, including manual refresh. Missing/zero server delay must not cause a
  retry loop. Persist effective server gates across restart. Manual refresh may bypass ordinary
  cadence and transport fallback, never rate-limit gates. Use bounded exponential retry up to
  30 minutes; success resets it. Claude's ordinary
  online fallback minimum is 300 seconds, a Waterline policy rather than a published server limit.
- Credential change/recovery can unpark authentication. Wake, network recovery and source changes
  trigger one eligible refresh, not catch-up bursts. Prefer events/deadlines to unnecessary polling;
  stop cancels work. Inject boundaries and wall/monotonic clocks; tests advance fake time without sleeps.
- Publish/persist once per meaningful state change. Countdown rendering does not write snapshots;
  persistence errors do not erase in-memory results.
- State belongs in `~/Library/Application Support/Waterline/`; `snapshot.json` is versioned, atomic,
  ISO-8601 dated and secret-free. Versioned atomic `configuration.json` holds account metadata,
  source switches, pins and order; save validated configuration before applying mutations. Language
  uses the app AppleLanguages preference; app-owned Keychain entries use
  `io.github.alfredtutu.waterline`. Explicit exports follow provider rules. Keep files owner-only;
  account metadata and paths can be private too. Distinguish OS bookkeeping from app-directed writes.
- One engine owns the writer lock through load/discovery/refresh/persistence. CLI mutations refuse
  while the app owns it; snapshot reads need no lock. Release locks on exit. Test migrations and keep
  unmatched legacy history separate rather than guessing identities.

## Acceptance

Completion means the authorized scope and applicable checks pass, not every historical roadmap item.
Keep evidence in the task/delivery record; do not create duplicate tracking systems. Record unavailable
checks and limitations honestly. A mock, screenshot or unrelated passing test cannot close a real flow.

### Automated gate and change verification

`DEVELOPER_DIR=/Applications/Xcode.app make verify` runs the following; CI runs the same target on
`macos-26` using `/Applications/Xcode_26.6.app`. Record actual toolchain and tested commit. SwiftPM uses
`swift-tools-version: 6.2`, macOS 14 minimum and Swift 6 strict concurrency; declaring an OS minimum does
not prove native execution there. A local pass does not prove remote CI.

| Gate | Pass condition |
|---|---|
| Build/test | `xcrun swift build` and `xcrun swift test` pass; explain new warnings. No real services, sockets or Keychain in automated tests. |
| Format | `xcrun swift-format lint --strict --recursive Package.swift Sources Tests` has no findings. |
| Whitespace | `git diff --check` and `git diff --cached --check` pass; no conflict markers. |
| Scripts | Cask generator, app runner and update-configuration Python checks in `make verify` pass. |
| Audit | `Scripts/audit.sh` passes; separately review redaction and dependencies missed by pattern checks. |

Documentation-only changes check consistency, references and existing gate configuration; no new
behavioural tests or live calls are needed. Logic changes need meaningful regression/failure tests;
UI/OS changes also need the exact native Release app and relevant interactions, including relaunch.

- Identity/discovery: verify locked sources, duplicates, regions/teams, credential rotation, account
  switches and evidence-based legacy migration.
- HTTP/parser: cover 401/403, 429 numeric/date/missing delay, 5xx, timeout, HTTPS/host/redirect rejection,
  genuine zero, absent optional fields, added fields, invalid required fields and partial success.
- Engine/storage: cover observation freshness, reset expiry, isolation, coalescing, retry/parking,
  wake/recovery, cancellation, atomic writes, writer ownership and unsupported schema preservation.
- Native flows: connection reaches actual data or accurate recovery; refresh completes under engine
  rules; pin, card order and language change the rendered app and survive relaunch. Check cancellation
  and no recurring Keychain prompts. Verify compact/expanded, notch/no-notch, Spaces/full-screen,
  one-panel ownership, scrolling, long names, keyboard, VoiceOver, Reduce Motion and both languages.
- Live evidence records date, provider, region, plan kind, metrics and limitations without private
  identifiers. Fixtures are not live verification; unavailable promised scope remains a gap. Use the
  owner's authorized real accounts. For fixes repeat the original scenario and affected flow; if
  reproduction is unavailable, state the alternative evidence and limit.

### Runtime and release

Measure the exact Release build with actual authorized accounts; no separate fixture app is required.
Record commit/executable, toolchain, OS, hardware/RAM, display, account count, cadence and measurement
tool. After 10 minutes warm-up, sample 10 minutes at one-second intervals including normal refreshes:
mean CPU below 1% (100% is one core), peak physical memory below 120 MB. Report peaks, gaps and excluded
events; never silently change thresholds or definitions. Inspect writes across launch, refresh and
preference changes: no unexplained state, credential copies, persistent HTTP bodies/cookies or exports.

For requested releases, verify required CI on the reviewed change, tag, artifact identity/checksum,
installation and relaunch. The owner accepts ad-hoc signed, unnotarized initial distribution with
macOS Privacy & Security allowance on first open. Describe that accurately. Notarization, Homebrew,
self-updates and repository visibility changes are not implied requirements. Do not claim untested
OS versions, plans or provider capabilities are verified.

Release-specific verification evidence remains in `docs/release-readiness.md`; provider-specific
Claude GUI/CLI identity, timestamps, expiry and fallback rules remain in its provider contract.
