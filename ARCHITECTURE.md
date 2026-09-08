# Architecture

Target product contract. Decisions and reasons live in `docs/decisions.md`; UI rules in `docs/ui.md`;
provider evidence in `docs/providers/`. The implementation status below distinguishes targets from code.

## Purpose

One glance answers how much of an AI coding account's allowance is in use, when it resets, or how much
prepaid balance remains. Discover credentials already stored by supported tools; support manual keys
where needed. No Waterline backend, telemetry or crash-upload service. Authentication and necessary
account identifiers go only to the corresponding provider's documented endpoints.

## Implementation status

As of 2026-09-08, the repository implements the local engine, persisted account management and
refresh scheduling, manual key flows, balance history, CLI and native notch/settings surfaces.
Registered adapters are Codex (ChatGPT display), Claude Code, Cursor, DeepSeek, Moonshot,
Kimi Code, Zhipu, MiniMax, xAI, independent Grok and Antigravity. Scoped real account
checks exist for Claude Pro, ChatGPT/Codex, Cursor Pro, Moonshot CN, Grok and Antigravity;
consult the provider contracts for exact scope and later authentication limitations.
Real failed requests for DeepSeek, GLM CN and MiniMax CN do not establish usable quota
or balance support. xAI and Kimi Code lack successful real-account validation. Qwen
has a reviewed capability boundary and remains unregistered. Native multi-account,
localisation, onboarding and distribution acceptance are still incomplete.

New accounts use opaque UUIDs and optional billing identities, with reconciliation independent of secrets.
Quota fraction/reset fields are optional. The fetch interface remains `fetch(...) -> Usage`. Snapshot schema 13 carries explicit configuration-source provenance and optional-source consent and distinguishes verification observations and carries balance basis and persists per-account request deadlines and authentication parking, and includes pending app-owned secret cleanup counts and retains account preferences, operation state and last-attempt time, with explicit partial states and component observation metadata, preserves legacy files before
upgrade and refuses unsupported versions. Engine regressions now cover repeated start, isolated
discovery failure, superseded late requests, stop invalidation and writer ownership. Subscriptions are
bounded and immediately receive state; storage errors do not suppress their updates. These are partial
foundations, not proof of complete scheduling, account management or native flows. The remaining scaffold interfaces are not exceptions to the target
requirements. Evolve them with the relevant implementation and migration tests. Do not claim a new
API exists merely because its required behaviour is described here.

## Process and modules

One `LSUIElement` app runs an engine actor in-process. The CLI can run the same engine headlessly.
`snapshot.json` plus the CLI is the local integration surface; no daemon, socket or local HTTP service.

| Target | Responsibility |
|---|---|
| `WaterlineKit` | Model, providers, host boundaries, engine, persistence and pure presentation logic. No AppKit, SwiftUI or Cocoa. |
| `WaterlineCLI` | Implemented: `snapshot`, `version`. Planned: `accounts`, `refresh`, `account add/remove`. |
| `WaterlineApp` | SwiftUI lifecycle, menu bar item, notch `NSPanel`, native interactions and rendering. |
| `WaterlineKitTests` | Swift Testing with synthetic files, fake clocks, clients and Keychain; reviewed fixtures. |

Providers are folders in the kit, registered in `Providers/Registry.swift`. Move logic into the kit
when it can be tested without the OS UI; native window behaviour remains in the app.

## Accounts and credentials

- An account is a provider billing/quota identity, including region and team/organisation scope where
  applicable. Separate subscriptions, regions and billing scopes stay separate even within one vendor.
- `AccountID` is a stable local opaque ID. When the provider reports a stable identity, use the tuple
  of provider, region and billing identity to reconcile discovery with that ID. Before identification,
  persist a provisional local ID keyed to the documented credential source/item, so a locked Keychain
  account can appear without reading the secret.
- Reconcile a provisional row when identity becomes available; transfer its settings/history only
  when the match is established. A source switching to a different provider account gets a different
  identity. Ambiguous matches stay separate; do not merge by email, model name or vendor alone.
- Credentials are replaceable references to a tool file, a specific Keychain item, an opted-in config
  source or an app-owned manual entry. Multiple sources may resolve to one account. A fingerprint can
  help deduplicate credentials but is neither the account ID nor proof of a billing identity.
- `Secret` stays in memory. It is not serialised; debug descriptions and diagnostics must redact it.
  Reconnecting or rotating a credential for the same known account preserves its ID and history.
- Discovery retains enough non-secret metadata to identify the provider, region, source and connection
  state. Authentication data is never used as a display label.

Existing unversioned snapshots need an explicit migration when the ID model changes. Preserve a copy
of legacy state locally, reconcile only identities supported by evidence, and keep unmatched history
separate rather than attaching it to a guessed account.

Regional manual credentials persist an explicit provider-defined region independently of billing
identity. Validate that selection before saving a key; key replacement preserves it. The adapter maps
the selection to one documented host and currency contract and never retries the sibling region.
Changing regional scope requires a separate account, preserving history and credential separation.

Gateway routes (v0.2) describe the harness, base URL and credential source. Query a recognised gateway
only through its own documented contract. An unknown gateway shows that its usage is unavailable;
never send its key to the model vendor or infer which upstream account paid for the call.

## Metrics and evidence

| Data class | Rule |
|---|---|
| Reported | Preserve provider values, units, scope and observation time. |
| Deterministically derived | Allow unit conversion, used/total with a valid positive denominator, remaining = total minus used for matching units/scope, and reset countdowns. Record the formula in the provider contract; no `≈` required. |
| Estimated | History-derived depletion rate and days left are separate from provider metrics, carry `≈`, observation period and method; never presented as a provider quote. |
| Missing or unsupported | Keep absent with a reason where needed. No default zero, fabricated reset, guessed currency or inferred plan allowance. |

Quota windows are account-specific, including differences between plans and teams at the same provider.
A plan label never selects or fabricates a window definition. For example, a Codex Plus response with
5-hour and weekly windows must retain both; a different account returning only one weekly window does
not redefine the provider globally. Missing account fields stay missing, and overview selection must
keep primary windows visible while making additional buckets discoverable.

A quota metric has a stable metric identifier and label, its unit, available reported counts or fraction,
and an optional reset time. A percentage needs either a reported percentage or comparable used/total
values; a missing reset does not invalidate a valid amount or fraction. Finite values outside the
recorded domain are schema errors, unless the contract explicitly permits them (for example overage).
For reported overage above 100%, retain the value in text; only the visual bar fill is capped.

Balances use `Decimal` and a known currency. Preserve separate currency entries instead of discarding
all but the first; never sum or rank raw amounts across currencies. Negative balances are valid only
where documented as debt. An account may contain both quota and balance metrics with one account header.

Each observation records when it was obtained (`fetchedAt`), its effective observation time (`observedAt`)
and origin (live response or local provider record). Use a provider timestamp when it denotes the
measurement; for an undated live response use receipt time. A local record retains its original time;
reading an old file now does not make its contents fresh. Retained metrics retain their own timestamps.

## Adapter and HTTP boundary

The current `ProviderAdapter` exposes a descriptor, `discover(in:http:)` and `fetch(_:secret:http:)`. Discovery may use the injected, allowlisted HTTP boundary for documented profile identification after reading a permitted source.
The target fetch result must carry metrics, observation metadata and any component failures needed
for the partial-result rules below; its final Swift types belong in the implementation.

- Discovery reads only documented locations through injected filesystem and Keychain interfaces.
  A source error is local to that source/account. Return a connection reason without a secret when
  access cannot proceed without interaction; an unreadable source is not evidence of no accounts.
- Map supported fields. Ignore unrelated additions. Distinguish omitted optional fields, explicit
  unsupported metrics and malformed required fields. Incompatible required fields yield
  `FetchError.schemaChanged` with a field path, never raw response content or a leaked `DecodingError`.
- Independent components may succeed separately. Publish valid new components; retain failed
  components' previous readings as stale with their own error/age, or show a reason if none exists.
  Do not relabel an account entirely fresh when a displayed component is stale. An optional omission
  alone does not justify reviving an old value; the provider contract defines omission semantics.
- The HTTP boundary maps documented 401/403 authentication failures to `unauthorized`, 429 to
  `rateLimited(retryAfter:)`, and 5xx/network failures to `transport`. A documented permission-only 403
  should explain missing access rather than imply that the user is signed out.
- Use the one real `URLSessionHTTPClient`, with an owned ephemeral session, 15-second request and
  30-second resource timeouts, no persistent response cache or cookie store. Credentials must not
  enter OS request logs or error text.
- Validate HTTPS, exact allowed host and the account's region/endpoint selection before sending.
  Reject redirects by default. An explicitly documented same-origin redirect can be followed only
  after revalidation; never forward secrets across origins. A provider-wide host list is an outer
  limit, not permission to try one key against every regional endpoint.
- One provider change updates its adapter, registration, provider contract and test fixtures.

## Engine and freshness

- Load a valid saved snapshot for immediate display without waiting for discovery or the network;
  then reconcile accounts and refresh. Isolate individual provider failures. Preserve an invalid
  snapshot for local diagnosis and allow discovery to proceed with a visible storage warning.
- `pending` means no result yet. A usable reading is fresh only while within its freshness period.
  Failures retain the last good value as stale; without a value, show unavailable and its reason.
  Lack of a supported metric is an explicit capability state, not a network error.
- Freshness expires after twice the account's normal refresh interval, measured from `observedAt`;
  a documented provider-specific limit may override this. Backoff does not extend freshness. A passed
  reset time triggers an eligible refresh and makes that quota stale until confirmed; never reset it
  to zero locally. Expiry need not invent a transport error. Wall-clock jumps must not cause bursts.
- A cached successful reading followed by 401 stays visible as stale with a reconnect action; park
  further requests until the credential changes or Connect succeeds. Never reclassify it as a new
  account merely because its secret rotated.
- Publish one snapshot per externally visible state transition; persist that snapshot once when this
  engine owns the store. Clock-driven label rendering is not a state change requiring a disk write.
  A failed write does not suppress in-memory updates; surface the persistence failure separately.
- Inject providers, filesystem, Keychain, HTTP client, store, wall time and a monotonic scheduler clock.
  Tests advance time without sleeping. Stop cancels scheduled work and releases subscriptions.

### Scheduling and recovery

One engine-wide HTTP limiter allows at most four active requests, including profile/discovery
requests and overlapping provider refresh operations. Per-refresh task groups remain bounded too,
but do not define the global network limit. Queued cancellation removes the waiter without sending
the request; completion, failure and active cancellation return the slot. Host/redirect policy remains
the responsibility of the wrapped HTTP client.

A reported future quota reset can advance the normal refresh deadline. It cannot advance an error
backoff or server Retry-After and cannot release authentication parking. Only reset times later than
the last fetched response schedule that early refresh; an unchanged past reset returned by the
provider must not create a tight retry loop. Passed windows become expired/partial presentation and
leave headline, healthy-state and alert eligibility while their last values remain visible.

The native app automatically checks all enabled accounts every 60 seconds, including while idle.
It migrates saved longer intervals to this policy on startup and preserves account identity,
source consent, display order and daily selection. Viewing can request an earlier check under
its existing minimum interval. Reset deadlines still advance eligible refreshes; server backoff,
authentication parking and suspend/recovery take precedence. No input-idle polling or tool-session
hooks are needed for this cadence.

429 honours numeric or HTTP-date `Retry-After`; without it use 60-second exponential backoff capped
at 30 minutes. Transport/5xx failures use the same fallback backoff; success resets it. Coalesce
overlapping refreshes for an account. Manual refresh bypasses the normal interval and fallback backoff,
but never an active server `Retry-After`, authentication parking or a request already in progress.

Implemented request-state persistence stores the usage-fetch deadline, fallback deadline and parked
state in each snapshot entry. Ordinary startup and account enablement do not clear server deadlines.
The private configuration keeps a full SHA-256 credential revision to detect actual credential changes;
it is neither an account identity nor a display label and contains no plaintext key. A changed revision,
explicit Connect, or successful recovery of an unreadable source can release authentication parking.
Profile/discovery request scheduling and native wake/network recovery still need complete verification.

Codex, Cursor and the explicitly enabled DeepSeek global-settings source receive a local-only credential discovery check every five minutes and during
wake/network recovery. Compare identity/source/secret revision before reconciliation, so unchanged
files do not cancel active requests or reset schedules. Changed credentials can release authentication
parking but never clear a server deadline. A failed local read stops use of the cached secret. These
checks perform no profile HTTP request or interactive Keychain read. Optional file checks are scoped to their own source. Other
providers' credential/profile refresh needs its own cadence before joining it; no general fast poll
of all providers or source directories is implied.

Wake, network recovery and credential-source changes re-evaluate freshness and trigger one eligible
refresh, not catch-up requests for missed intervals. Background Keychain re-reads remain noninteractive;
Connect is the explicit interactive recovery path. Avoid polling faster than needed for a due deadline;
hover delays and visible countdown updates are UI timing, not network or disk polling.

## Credential discovery

Optional-source consent is explicit and off when absent in old preferences. The first implemented
source is the inherited process variable DEEPSEEK_API_KEY. A separate source reads the global Claude
settings env object only for the exact direct DeepSeek Anthropic endpoint, with a bounded regular-file
read and explicit source/path/key provenance. No shell files are evaluated or scanned,
and custom base URLs do not route this dedicated key. Engine and presentation share source eligibility,
so disabling it stops requests, drops the cached secret, mutes/hides the source as appropriate and
excludes alerts/estimates. Scoped source checks preserve manual accounts; overlapping provider
reconciliation completes against the latest consent. Other named config/environment sources remain
open and require their own contracts and tests.

| Tier | Sources | Default |
|---|---|---|
| 1 — tool login state | Provider-specific documented files/Keychain items; Cursor SQLite opened read-only. | on |
| 2 — config scanning | Opted-in tool config fields and literal `export NAME=value` declarations in named shell files; provider-specific names and region selection. | off, opt-in per source |
| 3 — manual | CLI account entry, then Settings; keys stored in this app's own Keychain service. | user initiated |

Never execute or source shell files, expand substitutions, or scan arbitrary directories for secrets.
Record each discovered source and reject ambiguous provider/region attribution rather than probing
endpoints. Fallback credential names do not authorise merging distinct known accounts.

Background Keychain operations disable interaction. If access is already permitted, reading is allowed;
otherwise return `keychainLocked` and offer Connect. Connect announces access and permits one scoped
interactive read. Cancellation must not trigger automatic prompts. Verify the actual mechanism on
supported macOS versions; Waterline never writes or refreshes another tool's credentials. Do not copy
credential-bearing databases to disk to bypass a lock; use read-only access with bounded retry and
report unavailable when access remains blocked.

## Persistence and concurrent clients

| What | Location | Rule |
|---|---|---|
| State | `~/Library/Application Support/Waterline/snapshot.json` | Versioned schema; atomic replacement; ISO-8601 dates; sorted keys; no secrets. |
| Account metadata and writer lock | `…/Waterline/` | Stable local IDs and source associations; lock is released by the OS when its owner exits. |
| Balance history (v0.2) | `…/Waterline/history.jsonl` | One record per successful balance observation, including unchanged values; deduplicate repeated publication of the same observation. |
| Configuration | `…/Waterline/configuration.json` | Versioned atomic account metadata, labels, enablement, pins, removal exclusions, thresholds, intervals and registered source switches. Engine saves before applying mutations; invalid files fail closed. |
| Manual secrets | Keychain service `io.github.alfredtutu.waterline` | App-owned entries keyed by stable account ID; no external services can be named by the write API. |
| Explicit diagnostic export | User-selected directory | Opt-in, restricted permissions; raw-capture rules in `docs/providers/README.md`. |

Configuration and snapshot are separate: configuration is authoritative for accounts/settings, while snapshots carry cached readings and a read-only projection of preferences. Snapshot failure does not roll back a saved configuration change.

Snapshot reads never need a writer lock. A running app holds an exclusive engine/writer lock. If the
CLI cannot acquire it, `refresh` exits with a clear message to use the app's Refresh; it does not fetch
or overwrite the live app's state. With the app closed, the CLI holds the lock from loading/discovery
through refresh and persistence. This avoids competing schedules as well as stale snapshot overwrites
without introducing IPC. Apply the same ownership rule to account/history mutations.

Normal app-controlled state writes stay in the app's support directory, preferences and own Keychain.
System-managed bookkeeping and build products are outside this runtime-state promise; inspect them
separately. Use owner-only access for app state and exports. A snapshot's paths and account metadata
may still be private even when it contains no secrets.

Version the snapshot before changing public fields; test legacy migration and rejection of unsupported
newer versions without overwriting them. A CLI consumer must check schema compatibility.

## Balance estimates (v0.2)

Implemented foundations: the engine appends accepted balance observations to `history.jsonl`,
deduplicates by account/currency/observation time, and retains unchanged values at distinct times.
History timestamps use numeric Unix seconds to preserve subsecond observations; snapshot dates remain
ISO-8601. Records older than 90 days are compacted on startup and when new records require pruning.
A malformed journal is preserved and reported. Explicit storage retry can repair only an incomplete final line after a byte-preserving backup; interior corruption and complete unknown schemas remain errors. Failed writes remain queued
in memory for retry while the process runs; a process exit during a storage outage can lose unsaved
observations. Current metrics remain available and the failure is visible in UI/CLI.

The detail view queries seven days of stored observations. The standalone native balance-history window selects 7, 30 or 90 days from the same engine-owned journal, preserving account/region scope and separating currency and balance basis. It shows the latest 100 raw observations below each chart; these balances are not actual spending or API-equivalent valuation. Both surfaces render real points,
with breaks for gaps beyond twice the current refresh interval. Native chart/long-history performance
checks remain open. The estimator below has test-clock coverage; no synthetic history is placed in
normal runtime state.

Retain observations for 90 days; estimates use at most the last 7 days in one account/currency segment.
Require at least two distinct observation times spanning 24 hours, and a fresh latest balance. Compute
net balance decrease divided by elapsed days; label it an average decrease per day, not today's spend
or per-request cost. Amount divided by a positive rate gives estimated days left for a nonnegative balance.

An observed increase (top-up, refund or adjustment) starts a new segment. A currency or billing-identity
change also starts a new segment. A posted-ledger observation for the same currency interrupts the
available-balance segment; do not bridge across it or reuse an estimate predating it. A return to
available balances must accumulate two observations spanning 24 hours again. Posted-ledger values
in another simultaneously available currency do not interrupt this currency's segment.
Zero/nonpositive rate or insufficient history means no days estimate,
not infinity or zero. Balance observations cannot reveal deposits and charges that offset between
samples; explain this limit in estimate details. This is a heuristic, never a billing total. Sparklines
show recorded balances with gaps where observations are absent, not invented daily values.

## Presentation and verification

The four-account offline runtime harness is a separately compiled application with the
`WATERLINE_VERIFICATION` condition, separate scratch build directory and `.verification` bundle ID.
Its adapters, filesystem, Keychain, owned-secret and HTTP dependencies are isolated; network/keychain
operations fail rather than touching live services. State/history/alerts stay under a UUID-scoped
system temporary directory. Notifications and external connection/console UI are disabled. Snapshots
mark observations `verification`; production never enables this mode through a runtime flag and
rejects verification arguments. This harness proves fixture behavior only, not provider live support.

Language selection is the native per-app `AppleLanguages` preference, applied by bundle loading on
the next launch. It is not duplicated in engine configuration. The app's own bundle uses standard
UserDefaults; isolated tests use independent suites. Follow system removes only the app override.

The owner retired quota/balance notifications and Claude session activity on 2026-09-08.
The app does not request notification authorization, schedule alerts, or listen for tool-session
events. Startup clears the app's old pending/delivered notifications. Old alerts.json is inert;
no new alert history is written. Upgrade cleanup removes only recorded Waterline hook commands
(and the canonical command for a previously enabled install), preserving foreign hooks/settings.
Failed cleanup retains its owned-command manifest and exposes Retry cleanup. The old CLI hook
subcommand exits silently without reading or broadcasting input until obsolete entries are removed.
Refresh/threshold form controls and account source/time diagnostics are absent from Settings.
Legacy threshold fields remain decode-compatible for stored preferences; the native policy clears
balance thresholds and no threshold can produce a notification.

`NotchGeometry` derives screen frames; `Dashboard` derives metric selection, stable ordering, health
and formatting. Follow `docs/ui.md`, including no-account, partial, both-kind, overflow and keyboard
states. The app renders these results and handles native focus/Space/display behaviour.

Launch at login is owned by macOS ServiceManagement (`SMAppService.mainApp`), not by the engine's
configuration file. Only the General settings control registers or unregisters the main app; app
startup never silently registers it. Read system status on opening the settings view and returning
from System Settings. A pending approval is distinct from enabled, and errors remain visible.

Automated tests cover boundary validation, partial results, identity reconciliation, freshness,
scheduling, persistence ownership, migration and presentation with fakes. No live service or real
Keychain access in tests. Native UI, Keychain policy, resource usage and authorised live provider checks
have separate evidence in `ACCEPTANCE.md`; passing unit tests does not establish those behaviours.

## Toolchain and build

Reference: Xcode 26.6 / Swift 6.3.x; `swift-tools-version: 6.2`, macOS 14 minimum. Locally verified on
2026-09-06 at `/Applications/Xcode.app`: Xcode 26.6 (17F113), Apple Swift 6.3.3. The package uses Swift
Testing, strict concurrency and the app target's default MainActor isolation. Pure SwiftPM, no `.xcodeproj`.

`make` defaults `DEVELOPER_DIR` to `/Applications/Xcode.app` and respects an existing value. Direct
`xcrun` or `Scripts/bundle-app.sh` invocations need the variable explicitly. CI is configured for
`macos-26` and `/Applications/Xcode_26.6.app`; that remote installation is not verified by a local check.
Record actual versions when verifying; do not silently choose another toolchain.

The bundle script creates an ad-hoc signed `build/Waterline.app`. Prefer system libraries; a dependency
needs a concrete benefit, licence/maintenance review, decision record and audit allowlist entry. The
current allowlist contains Sparkle 2.9.6 for native app updates only; the kit and CLI
have no external dependencies. See `docs/software-updates.md` for its boundaries.

## Roadmap

All entries are targets, subject to provider evidence and the acceptance gates.

| Milestone | Scope |
|---|---|
| v0.1 | Account model, engine, snapshot, HTTP boundary, Keychain policy; CLI; usable notch/menu UI; Claude Code, Codex, Cursor, xAI where supported by verified contracts. |
| v0.2 | Zhipu, Kimi Code, Moonshot, MiniMax, DeepSeek; Tier-2 opt-ins; recognised gateway routes; balance history and estimates. |
| v0.3 | Full onboarding and Settings, Antigravity, reviewed Qwen capability status, zh-Hans/en, current provider evidence, public repository. |
| v0.4 | Sparklines. Notifications and session activity withdrawn by owner on 2026-09-08. |
| v1.0 | Signed/notarised distribution, optional signed updates, Homebrew cask and DMG. Update hosts and downloads require a documented network-policy extension before implementation. |

## Local Token imports — 2026-09-07

The native Token records window offers explicit single-file Codex JSONL import. It does not scan automatically or attribute task usage to the currently logged-in account. Parsing runs off the engine actor; cancellation is checked at stream-buffer boundaries. Stop/sleep invalidate the operation and prevent a late commit after the writer lifecycle changes.

The engine owns `token-history.json` beside the existing snapshot. This is a separate version-2 atomic document (64 MiB supported limit; version 1 loads without pricing eligibility), loaded only when requested. It stores thread IDs, observed times, model identifiers, counters and coverage flags, never source paths or prompt/response bodies. Counts remain account-unassigned. A dated Standard API-equivalent reference can price eligible exact-model Astra and Sol/Terra/Luna records; it is not a bill. See docs/token-reference-pricing.md. This file is not the balance journal and has no automatic retention deletion.

A repeated source analysis must contain all previously accepted samples unchanged before it can append. Identical imports do not write or add counts; shorter/conflicting sources and unknown ledger versions preserve the saved file and fail explicitly. Period filters (7/30/90/all) only change display; cached input remains a subset of input rather than another additive total. Native file-picker interaction and real user-selected persistence acceptance remain separate from fixture validation.

## Software update preparation — 2026-09-08

`docs/software-updates.md` records the reviewed Sparkle 2.9.6 candidate, license,
target opt-in flow and release network/signature boundaries. The app target now embeds this exact dependency and native controls. No feed/public key
is configured, so the updater remains uninitialized. Exact feed routing and signed
installation acceptance remain required.
