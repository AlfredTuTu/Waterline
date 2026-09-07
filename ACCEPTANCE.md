# Acceptance

Target verification contract. No unchecked item is implemented or verified merely because it appears
here. A task is complete when its authorised scope and applicable checks hold; a milestone is complete
only when all its release requirements hold. Documentation changes do not require implementing the
behaviours they specify. Record unavailable checks honestly, without ticking them or inventing evidence.

Historical `build/verification/` and `design-previews/` references below are ignored local
evidence, not files included in the public repository or distribution. Public contracts
record verification scope; private account details stay in local evidence.

## Local development evidence — 2026-09-06

The inherited 22 documentation/template edits were present at task start. Reference toolchain checked:
Xcode 26.6 (17F113), Swift 6.3.3. Baseline `make verify` passed five tests. Four formal regressions then
failed against the scaffold: repeated start duplicated an account, a discovery exception hid a healthy
provider, a late old request replaced balance 20 with 10, and description/reflection/dump exposed a
synthetic secret. After correction those same behavioural tests pass (the race now explicitly requests
supersession; normal refreshes coalesce).

Additional isolated tests cover immediate subscription delivery, valid reading delivery despite disk
failure, diagnostic propagation, legacy backup/version upgrade, newer-schema preservation, forbidden
HTTP/port/user-info URLs, writer contention/release and stop invalidation. These do not contact a real
service or Keychain. HTTP redirect policy is implemented but native redirect testing remains open.
The Keychain global-interaction API has been replaced with per-query LAContext policy; native
noninteractive/interactive verification remains open. A first Codex CLI query at 2026-09-06T13:26:28Z returned four real quota windows and saved the snapshot.
This verifies that request path only; no complete Provider or native user-flow acceptance item is checked.

Native Release iteration: one actual Codex account was displayed; the Refresh control updated the
visible observation time from 23:33 to 23:34. A concurrent CLI refresh returned exit code 3 while the
app owned the lock. Quitting/relaunching the app restored the same single account, without a duplicate.
The later black overview iteration opens additional windows through `+3 more windows`, and Back returns
to overview in the same panel. Multi-account ordering uses 11 synthetic account entries in unit tests;
11-account native rendering, hover timing, screen transitions and accessibility remain unverified.
Latest full gate: 26 tests passed, plus strict format, whitespace and audit. Release remains ad-hoc
signed and development-only; no installed distribution, notarisation or public release is claimed.

Account-management iteration (2026-09-07): native Release Settings opened from the island. Rename,
pin and disable were reflected in configuration.json and snapshot schema 2. After quit/relaunch,
Settings restored the test label, pin and disabled state; lastAttemptAt stayed 2026-09-06T14:05:22Z,
showing no startup refresh of the disabled account. Re-enable obtained another real reading. Lowering
the warning threshold from 70% to 30% changed the real 36% meter and collapsed dot to orange; restoring
70% restored the preference. A zero-second interval was rejected with an inline error; 300 seconds
saved and cleared the error. All test preferences were restored (enabled, unpinned, unnamed, 70/90%).
The panel's child height was corrected to match its computed content height; the full header/footer
were visible in the subsequent native screenshot.

New offline tests prove config-write failure leaves the requested account change unapplied; removal
survives restart until explicit Connect; credential rotation retains stable identity and preferences;
old cached observations expire without timestamp rewriting. These do not establish every provider's
reconnection, native Keychain prompt policy, or the complete release checklist.

Visual follow-up (2026-09-07): the owner supplied a native screenshot showing a capsule stacked on a
rectangular body. Independent child backgrounds were the cause. A shared IslandSilhouette now clips
and paints both surfaces; the rebuilt Release screenshot shows continuous single-account sides and
no capsule bottom edge at the junction. Wider curved shoulders are implemented but still need native
multi-account rendering evidence. Latest gate: 36 tests pass, including synthetic per-account Plus
5-hour+weekly and other-plan weekly-only shapes. The live account remains a single observed scope.

Component/CLI iteration (2026-09-07): snapshot schema 3 records stable component IDs, per-component
observation times and errors, plus an explicit partial account state. Offline tests verify repeated
partial failures retain the original observation date, optional omissions do not revive old values,
independent currencies stay separate, and a fresh critical component still signals in a partial account.
Injected CLI tests cover JSON refresh/account mutation/re-read, busy writer, invalid flags and nonzero
status for discovery failures. The real locked-Claude refresh now exits 2 and prints the access reason;
other-provider cached readings remain intact and visibly aged. Latest gate: 49 tests pass.

Claude native-boundary evidence: an initial LAContext-only noninteractive read remained blocked inside
SecItemCopyMatching_osx / SecKeychainItemCopyContent (one-second sample of the exact test process).
That process was terminated without a credential dump. With serialized legacy UI policy disabled and
the prior setting restored, the same noninteractive command returned keychainLocked in about 0.2 s.
Three deprecation warnings for the public legacy get/set functions are expected and retained; tests do
not touch the real Keychain. The machine then locked; native interactive Connect and Claude profile/
quota verification remain pending manual unlock and any required OS authorisation. This is not a
successful Claude quota integration claim. Other development remains possible; the goal is active.

Isolation follow-up (2026-09-07): two new regressions failed before correction. Connect on one
provider unnecessarily refreshed another provider; refresh now accepts a provider scope and Connect
uses it. A component-group name that was a prefix of another name revived an unrelated old window;
retention now uses explicitly declared parent scopes and exact IDs. Positive parent-retention and
negative similar-name tests cover both sides. DeepSeek's endpoint parser now has offline tests for
independent CNY/USD balances, zero, malformed totals/gifts and duplicate currencies. Its manual-key
account flow and live verification remain incomplete; it is intentionally not yet registered.

Manual-key iteration (2026-09-07): DeepSeek is now registered behind a manual-key flow. The engine
uses a restricted app-owned secret-store interface; config/snapshot tests prove that supplied keys
are absent from persisted files and output. Isolated tests cover add, replacement with stable identity,
two manual accounts surviving rediscovery separately, deletion, visible cleanup failure and retry on
restart, config failure before any secret write, recoverable secret-write failure, and rejected-key
nonzero CLI status while keeping prior readings. Balance-only headline selection is tested by health
and currency, without comparing raw mixed-currency amounts. Latest gate: 63 tests pass.

Executable checks: empty piped stdin and a PTY invocation of `--stdin` both returned exit code 64
before any credential write. Settings now has a SecureField add/update sheet and a pending-cleanup
retry action. These native surfaces and actual app-owned Keychain writes have not been verified while
the Mac is locked. No real DeepSeek key was used or balance response obtained in this iteration.

History iteration (2026-09-07): balance recording now happens at engine result acceptance, before
subscriber consumption. Tests cover distinct unchanged observations, duplicate publication, restart
loading, 90-day retention, disk failure with valid current readings, and replay after storage recovery.
The estimator tests exact/sub-24-hour spans, flat values, top-up segmentation and subsequent recovery,
seven-day exclusion, stale latest data, debt, currency switches and simultaneous currencies. Journal
subseconds round-trip, and a malformed tail is rejected without overwriting it. A history write failure
returns CLI exit code 1 while preserving JSON readings. Latest gate: 74 tests pass.

A seven-day trend and labelled average-decrease/days-left estimate are wired into native account
details. They have not been rendered with real historical balances while the Mac is locked. Long-term
resource/retention performance, interrupted-write repair and durable outage recovery remain unverified;
no history/forecast acceptance checkbox is marked complete by the current tests alone.

Regional-provider iteration (2026-09-07): Moonshot CN/global is registered with explicit region
selection in manual entry and `--region` in CLI creation. Primary vendor references document CNY/USD
units and independent keys. Offline tests verify missing-region rejection before storage/HTTP, exact
selected-host routing, currency mapping, zero, negative-cash non-double-counting, optional voucher
failure isolation, dual-region restart recovery and region-specific console links. A separate source-
lock regression preserves last verified identity through temporary access failure and recovery.
Neither Moonshot region has a real-key/live balance check yet; native regional entry remains unverified.

Live regression check (2026-09-07 01:55 Melbourne): after regional-account changes, the actual
`waterline refresh --provider codex` returned exit 0 in about 0.9 s with four real quota windows.
The existing Codex local account ID remained unchanged. The stored Claude access-needed row remained
visible without causing this scoped Codex request to fail. No inference request or plan/billing change
was made. Moonshot still has no live-key evidence.

Request-persistence iteration (2026-09-07): new regression tests first demonstrated that restart
and disable/enable bypassed Retry-After, and 401 parking disappeared on restart. Snapshot schema 5 now
persists per-account schedules; enablement preserves server deadlines. Tests cover waiting before/
after the exact deadline, persistent authentication parking, explicit Connect recovery, unchanged-
credential restart, fallback backoff on automatic startup and real credential-revision change. Private
configuration stores a credential digest for revision comparison; snapshots do not contain that digest
or plaintext keys. Native profile/discovery backoff and wake/network-recovery coverage remain open.

System-recovery iteration (2026-09-07): NSWorkspace sleep/wake notifications and NWPathMonitor
unsatisfied-to-satisfied transitions are wired to the shared model/engine. Sleep cancels scheduled and
in-flight work, invalidates acceptance generations, and retains the writer lock/subscription state.
Recovery coalesces, uses automatic eligibility (including server waits), and resumes interrupted
startup discovery. Offline tests cover late old results, paused requests, repeated recovery, waiting
limits, and discovery interrupted by sleep. An additional manual-key regression keeps the saved
credential revision aligned after replacement so a rejected new key does not get retried on every
restart. Native OS event delivery and real sleep/network transitions remain unverified.

Kimi Code iteration (2026-09-07): registered the manual Code API-key flow separately from Moonshot.
Offline tests cover subscription/window counts, deterministic remaining-to-used conversion, zero
limits without fabricated percentages, missing reset times, independent malformed windows, membership
labels and the exact coding endpoint. Native input and real quota checks remain unverified. The default
CLI credential file was absent in a presence-only check; OAuth/device-header discovery and monthly
membership enrichment remain open. Derived fractions use decimal division and correctly rounded Double
conversion; display allows one decimal place near warning boundaries.

Zhipu/Z.ai iteration (2026-09-07): personal Coding Plan manual keys now use explicit CN/global
regions, matching console links and the existing owned-key lifecycle. Offline tests cover weekly,
5-hour, credit and MCP components; count-derived percentages; epoch-millisecond reset conversion;
unknown additions; sibling failure isolation; preservation of a malformed known component; and CLI
regional creation through a fake HTTP boundary. No actual key or quota request was used. Team scope,
model statistics, monetary balances, Tier-2 discovery and native/live checks remain open.

MiniMax iteration (2026-09-07): current official CN/global Token Plan endpoint selection replaces
the original unverified candidate route. Regional manual-key entry uses Subscription Keys. Offline
tests distinguish legacy remaining-count fields from modern remaining-percent fields, preserve real
zero/exhaustion semantics, avoid fake percentages for unquantified lanes, isolate weekly failures and
exercise the CLI path through a fake exact-host HTTP boundary. No live Subscription Key was used;
credits, browser sessions, native input and real quota comparisons remain unverified.

History-retry follow-up (2026-09-07): Privacy settings now invokes a dedicated engine persistence
retry that performs no Provider fetch. A test first leaves storage unavailable and verifies a failure,
then restores storage and advances the clock; the pending observation is written with its original
time and lastAttemptAt is unchanged. This removes the dependency on another successful network query
for in-process recovery. Native button delivery and damaged-journal repair remain unverified.

History-tail recovery (2026-09-07): explicit persistence retry now validates all complete records,
backs up the exact original file, and repairs a non-newline-terminated tail. A complete final record
is retained; a syntactically incomplete fragment is preserved in the backup. Tests confirm byte-identical
backup, unchanged observation times, no additional Provider request, and refusal to discard malformed
interior records or well-formed unknown schemas. Recovery produces a visible notice. Native button
interaction and actual process-kill/power-loss scenarios remain unverified.

xAI iteration (2026-09-07): Management Key and validated Team ID are wired through native manual
entry, CLI `--team`, configuration and the exact read-only team-balance endpoint. Offline tests verify
signed-cent conversion, missing-total errors, path-injection rejection, 403 permission classification,
team persistence, and exclusion of posted-ledger values from available-balance health/headlines and
history forecasts. The UI/CLI explicitly label the posted basis. No actual Management Key or live
Console reconciliation has been performed; real available credit and spend analytics remain open.

## Automated gate — `make verify`

| Gate | Command | Passes when |
|---|---|---|
| Build | `xcrun swift build` | No errors; new warnings are explained in the delivery record. |
| Tests | `xcrun swift test` | All tests pass; no live service, network socket or real Keychain access. |
| Format | `xcrun swift-format lint --strict --recursive Package.swift Sources Tests` | No findings. |
| Whitespace | `git diff --check`, `git diff --cached --check` | No whitespace errors or conflict markers. |
| Audit | `Scripts/audit.sh` | Current import, secret-pattern and dependency checks pass. Review remains necessary for redaction and dependencies the pattern checks might miss. |

The gate is configured in `.github/workflows/ci.yml` for `macos-26`, Xcode 26.6. Locally, use
`DEVELOPER_DIR=/Applications/Xcode.app make verify`; record the actual Xcode/Swift versions. Direct
`xcrun` commands also need this variable. A local pass does not establish remote CI status.

## Verification appropriate to the change

- Logic changes: tests for meaningful behaviour and failures, using boundary fixtures/fakes. Prefer
  a regression test that fails without the fix; do not add tests merely restating implementation.
- UI and OS integration: test pure derivations, then inspect the exact native app build and record
  the relevant interactions/screenshots. Unit tests do not prove Keychain prompt or window behaviour.
- Documentation only: check consistency, file/section references, target-versus-current claims and
  the existing gate. No new behavioural tests or live account calls are needed.
- Live checks: only with task/owner authorisation, using the implemented CLI. Record provider,
  date, region, account/plan kind without private identifiers, observed capabilities and limitations.
  Fixture tests do not prove that a live endpoint remains available.

## Standards every applicable change meets

- Provider values and deterministic calculations have documented units and provenance. Estimates
  are distinct and labelled `≈`. Unknown fields never become zero; genuine zero remains valid.
- Required-field schema errors name a field path. Added unrelated fields are tolerated; optional
  missing values and independent component failures follow the provider's partial-result contract.
- Credentials go only to the account's permitted HTTPS endpoint, including redirect handling. No
  credentials in normal logs, snapshots or copied tool databases; explicit raw-capture exceptions
  follow `docs/providers/README.md`. No writes to another tool's credentials.
- Background Keychain access never prompts; interactive reads occur only after Connect announces them.
- One provider/source failure does not suppress other accounts. Last good readings keep their own age.
- Support-directory state, preferences, app-owned Keychain entries and explicit exports match
  `ARCHITECTURE.md`. Review secret/identity redaction in addition to running the audit script.

## Complete frontend/backend flows

Acceptance must follow the actual user action through the local backend and back to the rendered app.
Screenshots, mock-only interaction and isolated backend tests are supporting evidence, not substitutes.
For each applicable flow, verify action, validation, progress, result/error, recovery and persistence:

| Flow | End-to-end result |
|---|---|
| Discover/connect/add account | The intended source is read under the correct access policy, identity is reconciled, a real supported reading or an accurate connection reason reaches the row, and account configuration survives relaunch. |
| Refresh and recover | UI and CLI invoke the same engine rules; progress completes, fresh/stale/partial outcomes are visible, server backoff is respected, and stored state agrees with the rendered result. |
| Change settings | Threshold, interval, language and source/account enablement changes affect actual behaviour immediately or at the documented boundary and survive relaunch. |
| Disable/remove/reconnect | Scheduling and row state change as expected; manual app-owned credentials are handled correctly, external tool credentials stay untouched, and reconnection preserves a known account identity. |
| History and notifications | Eligible readings enter history once, estimates and charts match the stored observations, threshold crossings respect preferences and notification permission, and user-pinned views retain their state. |

Check these flows in the native Release app, including failures and restart. Use synthetic inputs to
exercise otherwise unavailable edge cases and clearly distinguish them from real-account checks.
Claude Code and Grok explicitly selected through Cursor CLI may advise on backend and frontend work;
Antigravity and Figma are frontend design aids
only. All accepted behaviour must still work through the actual app and local engine. Record a concrete external dependency
only after investigation; do not treat ordinary implementation uncertainty as a blocker.

For every resolved problem, record the original symptom or unmet requirement, cause, correction and
verification of the same scenario plus the affected user flow. Keep these records in the existing
task/delivery evidence, not a duplicate tracking system. A workaround, hidden error, disabled feature,
mock replacement or weakened check cannot be labelled a fix. Correct failure presentation is necessary
but does not by itself establish successful integration. If the original failure cannot be reproduced,
state that limit and show the alternative evidence; do not claim an observed before/after result.

## v0.1 — engine, CLI, usable notch, initial providers

- [ ] `make verify` passes; release code is green on CI before tagging.
- [ ] Stable account IDs survive same-account credential rotation/reconnect; locked sources can be listed without reading secrets. Known duplicate identities reconcile; different regions/teams stay separate. Legacy snapshot migration preserves unmatched data without guessing.
- [ ] HTTP tests cover 401/403, 429 numeric/date/missing `Retry-After`, 5xx, success, timeout, HTTP rejection, disallowed host and redirect rejection/revalidation. A key cannot be tried against another region merely because both hosts are allowlisted.
- [ ] Parser tests cover reported zero, optional absent reset/fraction, extra unrelated fields, invalid required fields, multi-currency balances, both kinds and partial success. Overage is retained only where documented.
- [ ] Engine tests cover isolation of discovery/fetch errors, observation-time freshness, reset expiry, 60 s active / 5 min idle cadence, rate-limit/backoff, 401 parking, manual refresh constraints, coalescing, wake/recovery, stop/cancellation and persistence failure.
- [ ] Cached data appears without waiting for discovery/network; stale components are visibly aged. A local provider record never becomes fresh solely because Waterline read it now.
- [ ] A second engine cannot fetch or mutate shared state while the app owns the writer lock. Snapshot reads remain available. Test lock release on exit, atomic writes, legacy migration and refusal to overwrite an unsupported newer schema.
- [ ] CLI `snapshot`, `version`, `accounts`, `refresh`, `account add/remove` have injected entry-point tests, documented exit codes and plain errors. Manual keys come from non-echoing terminal input or stdin, never command arguments; empty input is rejected without a Keychain write. `--json` conforms to the supported snapshot schema.
- [ ] Claude Code, Codex, Cursor and xAI each have a documented supported scope, adapter registration, reviewed fixtures and authorised live evidence. Display only verified metrics; billing spend is not automatically an allowance percentage. An unavailable live account or unsupported promised capability is recorded as a release gap, not a passed check.
- [ ] Offline: previous readings remain greyed with age and an offline reason; no fabricated zero. A failed refresh does not erase valid independent components.
- [ ] A protected Keychain item causes no background dialog and exposes Connect. An already-authorised item may read without prompting. Connect/cancel/reconnect are checked on native macOS; no automated test touches the real Keychain.
- [ ] On a notch screen, collapsed height equals `safeAreaInsets.top`; on a screen without a notch, the 136×32 pt capsule fits. Click-to-expand, single-account selection, display switching and full-screen/Spaces behaviour match `docs/ui.md`; only one panel exists and adjacent menu items remain usable.
- [ ] Collapsed display uses the selected single account and its shortest primary cadence; reset expiry shows Awaiting update. Automatic account choice uses health and stable ordering. Mixed CNY/USD amounts are never ranked numerically. Threshold equality, unknown currency threshold and all non-fresh/empty states have tests.
- [ ] Expanded UI covers no accounts, source errors, pending, partial, both kinds, multi-currency, stale, unavailable and unsupported states. Many accounts scroll without hiding controls; the collapsed provider logo matches the selected headline account. Long names, keyboard-only use, VoiceOver, Reduce Motion and explicit console/Connect actions are checked.
- [ ] Basic connection guidance works before full Settings exists. No disabled Settings placeholder. The app has no Dock icon; menu actions include Show accounts, Refresh and Quit.
- [ ] Runtime storage and resource usage meet the protocol below; report tested OS versions and hardware. A macOS 14 minimum declaration alone is not evidence of testing macOS 14.
- [ ] Initial-provider contracts link evidence, map fields/errors, and record actual live-verification dates and supported metric scope.
- [ ] `v0.1.0` is tagged only after these requirements hold; changing release scope requires an explicit owner decision.

## Runtime verification protocol

2026-09-07 real-account measurement started using Release PID 55022 on macOS 27.0 (26A5425a),
Mac17,9 with 48 GiB RAM and the built-in 3024×1964 Retina main display (mirroring off). Three accounts
are enabled at 300 s cadence: Codex/ Cursor fresh and Claude unavailable at startup. Initial external
`footprint` returned 25,871,392 physical bytes; this is not the acceptance peak. The bounded runner
`Scripts/measure-runtime.py` performs the required ten-minute warm-up and ten-minute one-second
sampling, recording CPU-time deltas and physical footprint rather than RSS. Its output is
`build/verification/runtime-real-20260907.json`. Completed: 600 samples after warm-up, mean process
CPU 0.0349997%, sampled physical peak 25,166,880 bytes and lifetime physical peak 26,117,152 bytes.
Largest sample gap was 1.029 s; configuration and executable remained unchanged. The executable SHA-256
was `f1b094c3901e214653e05334f7b0366175aa309e51eea7948a03e9bf95c28ae8`.
These numerical observations meet the thresholds for that baseline build. The later global limiter
and one-second freshness UI changes were not in the measured executable and require remeasurement.
The four-fixture offline baseline and native collapsed/idle observation still require separate evidence.

2026-09-07 current fixture remeasurement started: archived Release executable SHA-256
`596c6c6b93875eb49af63a15b0d49d7013de079564bde9592d234c3ac354ac88`,
`build/verification/runtime-596c6c6b9387.app`, PID 27095. Native AX inspection before warm-up showed
only the collapsed headline, with no expanded account content. The four isolated fixture accounts
use run ID `86E4B6D5-7A10-4FC1-9B3A-01DA4DF53467`. The live measurement controller owns cleanup;
target/configuration metadata is in `runtime-current-target.json`, final measurements will be in
`runtime-current-fixtures.json`, and process-exit evidence in `runtime-current-cleanup.json`, all under
`build/verification/`. Completed with 600 samples after the ten-minute warm-up: mean process CPU
0.1933317%, sampled physical peak 35,603,584 bytes, lifetime physical peak 37,815,472 bytes, and
maximum sample gap 1.0722 seconds. Configuration and archived executable remained unchanged; both
numeric thresholds passed for this four-fixture build on macOS 27.0 (26A5425a), Mac17,9, 48 GiB RAM.
The controller exited the test app and process inventory independently confirmed its absence.
Summary: `runtime-current-summary.json`; the final synthetic snapshot was archived and temporary
fixture storage removed. This does not replace current real-account remeasurement, other supported
macOS/display testing, or the complete native interaction matrix.

Use a Release bundle built with the reference toolchain. Record commit/build, macOS version, Mac model,
RAM, display setup, enabled accounts, refresh intervals and measurement tool. For the standard idle
check, use four fixture-backed accounts (two windows, one balance, one both-kind), no recent harness
activity, collapsed panel and no user input; the fixture mode must make no live calls. The separate
`make verification-app` / `make verification-test` harness implements these four account types with
explicit verification provenance and isolated dependencies. Rendered state still needs native checking.

2026-09-07 fixture harness checkpoint: its dedicated release test passes the four-type/account
restoration and denied network/Keychain checks. Native launch produced four fresh `verification`
readings in a new temporary directory; production data-file hashes were unchanged during the startup
check. Invalid verification run IDs and verification flags passed to the normal app exit 64. Normal
`make verify` passed 165 tests at this checkpoint. PID 71053 completed the four-account measurement in
`build/verification/runtime-fixtures-20260907.json`: 600 samples, mean CPU 0.1216654%, sampled physical
peak 23,135,240 bytes and lifetime peak 23,200,800 bytes, maximum sample gap 1.032 s. Configuration and
executable were unchanged; SHA-256 was `921ee55fb24d475684f8f62768697e39065cc7376e0b4b1002672943caedf50b`.
The matching bundle was archived at `build/verification/measured-fixtures-921ee55f.app`. Numeric
thresholds were met for this fixture build, which includes the one-second freshness timeline. Later
interaction-order source changes were not in it. Mac remained locked, so visual collapsed/idle and
interactive behavior remain unverified; this is not complete current-release performance acceptance.

After ten minutes of warm-up, sample another ten minutes at one-second intervals: mean process CPU
below 1% (100% means one fully used core), peak physical memory footprint below 120 MB. Include ordinary
refreshes; report peaks and any excluded event separately. Repeat with the authorised real-account
configuration for release evidence, recording its actual account count. Do not lower thresholds or
change measurement definitions silently to pass.

Use filesystem tracing across launch, refresh, preference change and a manual-key action. Classify
app state, preferences, Keychain operations, explicit exports and OS-managed writes separately. Confirm
no app-directed credential copies, persistent HTTP bodies/cookies, or unexplained state outside the
listed locations. No export is expected during a normal refresh.

## v0.2 — additional providers, discovery, gateways, estimates

2026-09-07 native layout follow-up: the owner-requested orange verification banner is removed from
the account panel, history windows and menus. Collapsed/expanded header wings now place the logo
and metric 18pt from their respective outer black edges. Native offscreen inspection verified both
`build/verification/collapsed-symmetric-zh.png` and `expanded-symmetric-zh.png`. Data remains synthetic.
The Token record window also completed a native full-screen entry and return to ordinary titlebar
controls after applying fullScreenPrimary to record windows; other full-screen scenarios remain open.
No true-provider run was started. `make verify` passed 234 tests; the local bundle was rebuilt.

2026-09-07 provider asset integrity: the resource test covers every Provider case, verifies the
reviewed SHA-256 manifest, decodes each PNG through ImageIO and checks license presence. Distribution
checks compare packaged logos/license against reviewed source resources. Temporary negative cases
with a missing Claude image and missing license were correctly rejected; the current bundle passes
this resource check. Evidence: `build/verification/provider-resource-check.json`. `make verify` passed
234 tests in 49 suites. No applications or live-provider requests were started in this check.

2026-09-07 Escape native repeat completed: the current isolated bundle was expanded and explicitly
pinned, then Escape removed the expanded content. A separate Codex-detail route also collapsed on
Escape; reopening showed Overview and an unpinned footer, not the previous detail. Cmd+Q exited,
process inventory confirmed no matching verification process, and the run directory was removed.
Evidence: `build/verification/escape-check-verified.json` with the tested executable hash. This closes
the earlier Escape repeat gap; pointer-leave, Spaces/full-screen and the full keyboard/accessibility
matrix remain separate acceptance items. No code changed in this verification-only turn.

2026-09-07 collapsed provider attribution: health dots were replaced by the selected headline
account's brand logo. Value/account selection is atomic, quota ties use stable account IDs, and
status-only headlines use Waterline's symbol. Expanded rows share the bundled provider images;
usage alerts retain their source account for matching icons. Two regression tests cover quota
ownership/ties/expiry and balance currency/source selection. The native offscreen collapsed PNG
`build/verification/collapsed-provider-logo-zh.png` visibly shows Claude's orange mark paired with
the synthetic Claude 44% headline. An initial named-resource load rendered no icon; explicit bundle
URLs with cached NSImage loading corrected it. `make verify` passed 233 tests. Native notification
delivery/icon behavior and the outstanding Escape repeat check remain open.

2026-09-07 Escape regression under native verification: after explicit pinning, Escape left the
expanded content visible while the panel dialog had focus. `NotchPanel.cancelOperation` now routes
the responder-chain cancellation to common collapse. The repeated native check became unavailable
with ScreenCaptureKit -3812/-3811 errors, so the correction is compiled but its end-to-end effect
remains unverified. `make verify` passed 231 tests; these are not Escape UI coverage. The exact test
process was stopped and its temporary directory removed. Evidence: `build/verification/escape-check-pending.json`.

2026-09-07 current development image validation: a read-only mount of the v2-wave-logo DMG
confirmed all seven application files byte-identical to the current Release bundle, with the expected
Applications symlink and installation text. The image was unmounted without launching its app.
Evidence: `build/verification/development-image-v2.json`. Extracted ICNS 32px artwork shows three
distinct ripple lines; 16px retains the silhouette with weaker detail. This is packaged-image inspection,
not a claim that Finder rendering or the full visual acceptance is complete.

2026-09-07 deployment-target/package follow-up: current Release declares macOS 14.0 and its
LC_BUILD_VERSION reports minos 14.0 / SDK 26.5. The distribution checker now compares the declared
and compiled deployment target and checks LSUIElement. Temporary negative cases with a 15.0 plist
and an invalid executable were rejected. App icon representations and sealed resources pass;
`security find-identity -v -p codesigning` returned zero Developer ID Application identities.
The updated development DMG includes v2 wave artwork and current fixes; its validated image SHA-256
is `582b725692a35b357a33a7312917b7e5efc5956b3cd488141e9fac613ee8142e`.
Evidence: `build/verification/deployment-check.json`. This establishes deployment metadata, not
execution on macOS 14. Signing/notarization/Gatekeeper prerequisites remain unmet. The independently
archived fixture measurement was left running and was not rebuilt or restarted.

2026-09-07 balance-basis regression: a failing test demonstrated that excluding posted-ledger
points still reused an earlier available-balance estimate and bridged across a basis interruption.
The estimator now treats same-currency posted observations as a segment boundary. Tests verify no
old estimate while posted credit is latest, no estimate from the first resumed available point,
correct restart after a full day, and independence of another simultaneously available currency.
`make verify` passed 231 tests in 48 suites; `make app` rebuilt the local debug bundle without launch.
This is deterministic estimate coverage, not live-provider or full native UI acceptance.

2026-09-07 Token window restart checkpoint: the isolated native app imported 1,000 synthetic
observations (repeat import added zero), exited, then the fixture source log was removed. A separate
process used `--verification-token-render --verification-token-restore` with the same run ID and
the ordinary `TokenHistoryWindow(model:)` initializer, without injecting preloaded view state or
performing an import. The offscreen native rendering showed 720 recent observations, input 72,000,
cached input 57,600, output 7,200 and approximately USD 0.56. All 1,000 saved records loaded; the ledger
SHA-256 stayed identical and the source log remained absent. Evidence: `build/verification/token-restored.json`
and `token-restored-zh.png`. Both processes exited without ordered windows. This proves the synthetic
local-ledger restart/render flow, not real-account attribution or completeness of imported logs.

2026-09-07 localization follow-up: corrected the malformed `Loading accountu2026` catalog key and
added No accounts/Manual key translations. Two catalog tests check direct UI literals and matching
format arguments/locale keys; dynamic/interpolated keys and full native layout remain outside that
check. `make verify` passed 229 tests. The owner subsequently replaced the W-shaped logo with three
water-ripple lines; `Resources/AppIcon.png` now matches `design-previews/brand/waterline-logo-v2.png`.
The local debug bundle was rebuilt with the new icon and translations. The earlier Release DMG
still contains v1 artwork and is not current for this revision.

2026-09-07 app icon/release packaging checkpoint: the generated Waterline artwork is now copied
into project Resources and converted to ICNS before bundle signing. All ten standard/Retina icon
representations decoded at their expected dimensions. Release and development DMG rebuilt; a read-only
mount confirmed all seven bundle files byte-identical, the Applications symlink and Read Me correct,
and sealed-resource verification passed. The image was unmounted without launching the app.
Evidence: `build/verification/icon-release-package.json`; DMG SHA-256
`1249655c50062be1eaf97385390c04b95a9451bb2759dc6430587cc845a788d9`.
`make verify` passed 227 tests; the updated distribution checker passes icon representations but
still fails Developer ID, hardened runtime, timestamp, stable version, notarization and unavailable
Gatekeeper assessment. Finder rendering and small-size visual acceptance remain unverified.

2026-09-07 island dismissal follow-up: footer unpin now calls the common collapse path. Native
fixture-app actions verified the pin label changes and unpin removes the expanded content immediately.
Hover dismissal now uses that same path to clear navigation rather than only changing visibility.
The pointer-exit/detail-reset scenario remains unverified: the CUA drag screenshot still showed the
pointer inside the panel, so its unchanged state does not prove a missed exit event. A trial pointer
poller was removed. Final `make verify` passed 227 tests; `make app` rebuilt the local debug bundle.
`build/verification/island-unpin-check.json` records the bounded result. Test processes exited and the
known temporary run directory was removed. This does not close the full native interaction matrix.

2026-09-07 development launcher isolation: `make run` now delegates to `Scripts/run-app.sh`,
matches the current checkout's canonical executable path, and waits for its exit before replacing
the bundle. Two temporary compiled native processes with the same executable basename verified
that only the target stops and the other checkout survives; build precedes launch. Evidence is
`build/verification/launcher-isolation.json`. The test substitutes build/launch with markers and
does not establish native app launch acceptance. Both helper processes and temporary files were
cleaned. `make verify` passed 227 tests and the format/whitespace/audit gates.

2026-09-07 configured-source monitoring follow-up: enabled DeepSeek global settings now participate
in the scoped five-minute local check and wake/network recovery. Tests verify changed-file-only
refresh, no file reads after opt-out, repaired-source recovery and preservation of 401/403 parking
through disappearance/reappearance of the same key. Authentication pause cause is persisted; legacy
parked records without the new marker are treated conservatively until credential change or Connect.
Original authorization failures remain visible across source interruptions. `make verify` passes
194 tests. No real optional source was enabled; native controls and live key rotation remain open.

2026-09-07 literal configuration-source checkpoint: separate DeepSeek global-Claude-settings consent
now reaches bounded JSON discovery, validated direct-provider routing, scoped fetch and key rotation.
Five tests cover no read before consent, unrelated fields, wrong/proxy URL variants, placeholders and
malformed input, regular-file size/type bounds, and stable identity/source bytes through rotation.
`make verify` passes 190 tests. Source metadata has explicit provenance in snapshot schema 9. No real
user settings or credentials were read for these tests. Native controls, live balances, automatic
monitoring of this new file source and other/project configuration sources remain unverified/open.

2026-09-07 optional-source CLI follow-up: enable/disable/check commands use the same scoped engine
flow; list reads canonical consent before falling back to legacy snapshot preferences. Three tests
cover saved flags/pause output, stale-snapshot listing, missing-source failure despite a healthy manual
account, and rejecting unknown sources/key arguments before storage. `make verify` passes 185 tests.
A real read-only `source list --json` returned deepseek-env disabled and its provider enabled; no real
source was activated. Native source controls and live optional-source balance checks remain open.

2026-09-07 optional-source checkpoint: process DEEPSEEK_API_KEY opt-in now persists and reaches scoped
discovery/fetch, cancellation, presentation, reconnect and restoration. Five tests cover off-by-default
and invalid input, isolation from manual keys, removal/reconnect, restart/rotation without plaintext
key storage, old preferences/unknown sources, and an overlapping reconnect/source-disable scenario.
`make verify` passes 182 tests. Settings copy is localized. No real source was enabled for the user;
native control and live balance verification remain open. Other optional sources and literal config
file parsing are still unimplemented, so the full Tier-2 acceptance item below remains unchecked.

- [ ] Zhipu, Kimi Code, Moonshot, MiniMax and DeepSeek meet the same adapter evidence and test bar, for their actually supported account/region/metric scopes.
- [ ] Separate subscription and platform billing identities remain separate rows. Regional selection is established before sending a key.
- [ ] Tier-2 sources are off by default; opting in is per source. Discovery records sources, parses supported literal declarations, never executes shell content and reports ambiguous routing without probing hosts.
- [ ] Recognised gateways use their own documented quota contract and a `via` label. Unknown gateways show unavailable without attributing usage to an upstream account.
- [ ] History records each successful account/currency observation, including unchanged balances, exactly once; repeated publication creates no duplicate, and data older than 90 days is pruned.
- [ ] Estimate tests cover fewer than two observations, span below/exactly 24 h, the 7-day window, unchanged balance, top-up/refund, zero/negative rate, debt, stale latest data, currency change and credential rotation. Labels say average decrease per day, not today's spend; no estimate appears without qualifying data.

## v0.3 — onboarding, Settings, localisation, public release

2026-09-07 partial-diagnostics follow-up: details now show a readable affected metric/currency plus
the safe failure message, collapsed component/schema diagnostics and an applicable server deadline.
Three tests cover retained-label deduplication, known absent quota/currency labels and a generic main
label for unknown technical paths. `make verify` passes 174 tests and the dedicated verification test
passes. A Chinese synthetic detail render (`build/verification/island-failure-detail-zh.png`) confirms
the named weekly error, collapsed disclosure and full-width thin meter. No-balance history space was
removed. Native disclosure/keyboard interaction and real integration failures remain separate checks.

2026-09-07 compact expired-state follow-up: secondary metrics now state Awaiting update and combine
their accessibility children. A shared-freshness ordering regression verifies expired high fractions
follow current metrics. The synthetic expired-secondary render initially showed duplicated partial
copy and wrapped badges pushing lower values out of view; a compact header status, single-line
badges and tighter overview spacing corrected the repeated Chinese render. All four rows and 200 CNY
are visible in `build/verification/island-expired-secondary-compact-zh.png`. Real VoiceOver/focus and
all state combinations remain unverified.

2026-09-07 unsupported-view follow-up: the previously empty unsupported reading now renders its
capability label/reason, and omits the generic Reconnect menu item. Reset and last-check captions
were made lighter. A dedicated synthetic unsupported scenario was exported and visually inspected
in Chinese (`build/verification/island-unsupported-zh.png`): the reason is visible and other account
metrics remain intact. This does not label the real Claude provider unsupported and does not replace
provider evidence, VoiceOver or native interaction checks.

2026-09-07 own-view rendering checkpoint: the separate verification app can export its synthetic
NSHostingView via `--verification-render`, without capturing desktop pixels or ordering its panel
frontmost. The first PNG showed vertically misaligned row headers and a clipped both-kind balance.
Top-aligned grid items and compact overview supplements corrected the repeated rendered scenario;
all four accounts, the 200 CNY balance and footer are visible. English, Chinese and long-name PNGs
were inspected in `build/verification/` (`island-four-accounts-compact.png`,
`island-four-accounts-zh.png`, `island-long-labels.png`). The verification-only grey backing exposes
the shared contour; it is not a production background. Native own-view layout evidence does not prove
hover/focus, physical notch placement, VoiceOver or all account-state combinations.

2026-09-07 balance-freshness follow-up: old component balances were excluded from the headline but
could still influence health, ordering and alerts. A shared balance freshness predicate now covers
those paths, expiry presentation and history eligibility; native rows grey old values and show time.
Three regression tests verify old low balances do not displace a fresh warning or mask valid quota,
an old crossing cannot notify until fresh confirmation, and an errored balance is not healthy even
without a separate failure list. `make verify` passes 170 tests. Rendered mixed-age rows remain pending
native inspection; earlier resource measurements belong to their recorded builds.

2026-09-07 interaction-order follow-up: a stored identity order now applies while the account surface
is hovered or the panel is key. NSPanel key/resign callbacks feed the observable layout; new/removed
identities update the frozen order while values stay current. Two tests verify priority changes do
not move existing identities or freeze their values, and added/removed identities remain unique.
`make verify` passes 167 tests. Native hover, menu and keyboard focus transitions remain unverified.
The running four-fixture measurement precedes this source update and retains its own build hash.

2026-09-07 quota-reset follow-up: shared window freshness now excludes passed resets from headline,
health and alerts; engine presentation distinguishes an expired window from other current metrics.
Reset deadlines can advance normal refresh but preserve fallback, Retry-After and parked states.
An unchanged past reset after a fresh fetch does not cause repeated immediate requests. Four added
tests cover reset boundary/value retention, scheduling constraints, the engine refresh/no-spin flow
and mixed-current/expired headline/alert behavior. `make verify` passes 165 tests. Header/open-content
timelines now check once per second, so the earlier running Release resource measurement cannot prove
the performance of this changed build. Native reset-boundary rendering still needs verification.

2026-09-07 global request-limit follow-up: separate provider refresh groups could each start four
requests. The engine now shares one four-request limiter across all discovery/usage HTTP clients.
Two added tests exercise simultaneous five-account refreshes from two providers (peak four, all ten
complete), and queued cancellation with subsequent capacity reuse. `make verify` passes 161 tests.
The running resource-measurement Release has deliberately not been replaced yet; its report belongs
to its recorded executable hash, not this later source change. Rebuild/distribution refresh follows
completion of that baseline measurement.

2026-09-07 credential-refresh checkpoint: Codex/Cursor file discovery now participates in the five-
minute scheduler and recovery path. Seven new engine tests verify unchanged-token parking, changed-
token recovery with stable ID/name, in-flight preservation, unreadable-source cache rejection,
disabled-source exclusion, Retry-After preservation, and stable repeated logged-out/switched-account
checks. `make verify` passes 159 tests. Real tool-driven token rotation during an unattended native
session remains unverified, and other providers' credential/profile scheduling is still open.

2026-09-07 Cursor legacy follow-up: request-count discovery uses `/api/usage` with the validated
subject/session. Four added tests cover total-count precedence, missing/zero caps, invalid counts and
the complete three-endpoint adapter path with modern quota replacement. `make verify` passes 152
tests. A modern Pro live regression at `2026-09-06T18:49:20Z` returned exit 0, fresh main/Grok metrics
and no invented legacy quota. A real legacy-plan account and its rendered dashboard comparison remain
unverified; modern-account success does not establish that scope.

2026-09-07 shared transport checkpoint: four additional tests exercise URLSessionHTTPClient through
its actual ephemeral URLSession with an injected URLProtocol, not a fake HTTPClient. They verify
status/body/header mapping, same-origin and cross-origin redirects never issuing a second request,
Set-Cookie not being replayed and non-HTTP response rejection. All responses are in-process; no
network or real credential is involved. These tests strengthen redirect/cookie boundary evidence,
but do not establish real-network TLS, timeout/cancellation or provider-specific live behavior.

2026-09-07 connection-guide checkpoint: first Settings presentation shows a localized guide built
from registered provider destinations and source descriptions. Continue persists guide completion
and selects the existing Accounts tab; General can reopen it. It neither connects accounts nor
requests permissions merely by being read. `make verify` passes 144 tests; catalogs have 168 paired
keys. Native first-open, keyboard dismissal/continuation, completion after relaunch and the subsequent
real connect/add-key flow remain unverified. Tier-2 discovery remains unimplemented and is described
as not scanned, with no nonfunctional enable control.

2026-09-07 headline follow-up: the app's fresh-only quota selection excluded valid partial readings.
Selection now lives in Dashboard and is used by the header, with component freshness and explicit
paused/pending/unsupported/empty states. A minute timeline rechecks cached snapshot age during
backoff. Four new regressions cover partial quota plus muted health, time-based expiry without a new
snapshot, stale balance exclusion and distinct nonnumeric states. `make verify` passes 144 tests.
Native minute-boundary display and accessibility behavior remain unverified.

2026-09-07 language-choice follow-up: General settings now persists a per-app language override with
an explicit next-launch boundary and Follow system removal. A native cross-process probe exposed
that using the app's own bundle ID as a UserDefaults suite is invalid; the app now uses standard
defaults for its own ID. Repeating the probe successfully saved Chinese, restored Chinese/“刷新” in a
new process, then saved/restored English/“Refresh”. Probe preferences were removed afterward. The
unit test covers isolated-domain restoration and removal; `make verify` passes 140 tests. Actual
Waterline picker interaction and full rendered bilingual layout remain unverified. Catalogs have
154 paired keys.

2026-09-07 dynamic localisation follow-up: 150 paired keys now include account counts, timestamps,
usage summaries, notification templates, history estimates and common errors. The compiled AppText
helper was exercised in a separate native main bundle using Release catalogs: Chinese/English
account-count formatting passed, and a name containing literal percent placeholders remained data.
Catalog key/placeholder counts and packaged bytes match. `make verify` still passes 139 tests.
Manual language choice, remaining source/diagnostic/accessibility copy and native rendered layout
are not yet accepted.

2026-09-07 initial localisation checkpoint: 99 paired en/zh-Hans strings are included by the bundle
script before signing. Both catalogs pass plutil, their key sets match and packaged bytes equal source
bytes. A separate native main-bundle probe using the packaged catalogs selected zh-Hans and returned
“刷新” with Chinese process language, and selected en/“Refresh” in English. An earlier Swift interpreter
probe inherited its English host localization, so only the native main-bundle probe supports language
selection evidence. `make verify` passes 139 tests and now lints both catalogs. Full UI rendering,
dynamic copy, notification text and a language setting remain open.

2026-09-07 Antigravity discovery review: official quota/credits docs, pinned community transport and
schemas, local `agy --help` and executable-name process inventory were inspected. No usage subcommand
or running candidate process was found in that local check. `docs/providers/antigravity.md` now
distinguishes local status, cloud OAuth and offline observations, with concrete trust/account/mapping
gates. This is source and capability evidence only; no adapter, live quota or native flow is verified.

2026-09-07 dashboard follow-up: source inspection found used-only values hidden behind a limit check,
metadata notes treated as missing data, and nested two-column grids in multi-account cards. Amount
formatting now includes used-only zero/values; fresh quota fractions precede spend/stale metrics in
overview selection; explanatory notes do not mute valid readings. Multi-account metrics stack within
cards, with a single account column below 600 pt. `make verify` passes 133 tests including localized
amounts and quota selection/health regressions. Rendered layouts remain pending native verification.

2026-09-07 Qwen capability review: current primary documentation was checked for Qwen Code OAuth,
Model Studio API keys, Coding Plan, Token Plan and cloud account balances. The OAuth free tier is
discontinued; the existing cloud balance API uses a distinct AccessKey/RAM scope. No suitable quota
query contract for intended DashScope/Coding Plan keys was established. The dated evidence and scoped
unsupported rationale are in `docs/providers/qwen.md`. Opt-in discovery and an honest unsupported
account row remain unimplemented; no provider live verification or full milestone completion claimed.

2026-09-07 Cursor recovery follow-up: an exclusive transaction reproduced a busy database being
misreported as schema change. The SQLite prepare boundary now maps BUSY/LOCKED to a recoverable
transport error, and the same test reads successfully after rollback. Additional synthetic tests
verify committed WAL rotation without database/WAL mutation and the real Cursor adapter's engine
reconnect/restart path with stable ID, name, pin and reading. `make verify` passes 130 tests. This
extends offline persistence evidence; it does not establish native settings or all Cursor profiles.

2026-09-07 Cursor live follow-up supersedes the earlier no-live checkpoint: scoped CLI discovery and
query identified one Pro account. The first Grok call returned 403; the reference request's missing
Origin header was restored and the repeated scenario returned exit 0, fresh main/Grok usage and the
same account ID at `2026-09-06T18:00:38Z`. The response also demonstrated that reported total quota
percent differs from USD used/limit; these now occupy separate windows. Grok reported zero with no
reset date, which remains absent. `make verify` passes 127 tests. Dashboard comparison, native account
flows, alternative plans and profiles remain open. Partial-response rate limits now retain the longest
Retry-After deadline without parking the valid components for an optional endpoint's permission error.

2026-09-07 Cursor checkpoint: the registered adapter has seven offline tests, including the scoped
summary/Grok request chain and SQLite byte preservation/noncreation. `make verify` passes 125 tests.
No Cursor live fetch or native connection has been verified. Follow `docs/providers/cursor.md` for
remaining legacy/profile, SQLite lock/WAL, account restoration and current dashboard-comparison work.

2026-09-07 geometry checkpoint: `NotchGeometry.expandedFrame` owns target-display bounds and is used
by the native panel. Four added regression tests cover translated/negative display coordinates,
narrow/short screens, count-dependent sizes with a stable top anchor and a housing wider than the
preferred content. `make verify` passes 118 tests. Actual display switching, Spaces and full-screen
behaviour remain outside this automated evidence.

2026-09-07 multi-account lifecycle checkpoint: source inspection found that count changes did not
recompute the native frame and render replaced the hosting view. The panel now installs one host,
observes account count for layout updates, and clears removed detail/filter identities. Build and
114 tests pass; native verification must still add/remove accounts while pinned, retain a detail
or provider filter across resizing, move between displays, and close/reopen to Overview. Unit tests
do not establish SwiftUI state retention or native hover/focus behaviour.

2026-09-07 implementation checkpoint: General settings calls `SMAppService.mainApp` register and
async unregister, displays actual registration/approval status and offers the system Login Items
pane. No local Boolean substitutes for registration, and opening/activating settings re-reads status.
`make verify` passes 114 tests; these do not exercise ServiceManagement. Native enable/disable,
system-side changes, restoration after app relaunch and automatic launch after a user login remain
unverified while native interaction is unavailable. Do not mark the Settings requirement complete.

- [ ] Full onboarding explains each source and destination with Tier 1 on and Tier 2 off. Keychain reads that permit interaction are announced first.
- [ ] Settings includes accounts/sources, enablement, manual keys, positive currency thresholds, ordered window thresholds, validated intervals, privacy destinations, language and launch at login.
- [ ] Antigravity meets the adapter bar. Review Qwen's current capabilities against linked evidence; show an honest unsupported reason if no suitable contract is verified.
- [ ] All user-facing strings are localised zh-Hans/en and follow the system; layouts fit both.
- [ ] Every released supported provider has live verification within 30 days for its declared scope. Planned/unsupported providers instead have a dated capability review and reason; do not fabricate a live date.
- [ ] Repository is public with contribution guidance and a bug template; privacy text matches implemented behaviour.

## v0.4 — alerts and activity

2026-09-07 notification-navigation checkpoint: local notification payloads now carry an opaque
account target, with bounded parsing and deferred pre-panel handling. Navigation uses a distinct
event for repeated targets, preserves pending selection while accounts load and falls back on missing
accounts. Three tests cover payload bounds, loading/present/missing resolution and repeated events.
`make verify` passes 177 tests. Own-view Chinese renders confirm target detail and missing-target list
states (`island-route-account-zh.png`, `island-route-missing-zh.png` in `build/verification/`). No real
notification was issued; OS delivery/click, cold-launch timing and keyboard behavior remain unverified.

2026-09-07 implementation checkpoint: kit crossing logic and private alert-state persistence are wired
to the native opt-in control, UserNotifications submission/delegate and 3 s collapsed headline.
139 tests pass, including initial baselines, duplicate observations, hourly suppression across encode/
decode, independent metric crossings, stale/disabled/policy-change exclusion, balance equality and
posted-ledger exclusion, plus corrupt-file preservation. No real permission request or notification
was issued during tests. OS approval/denial/revocation, banner/sound policy, click-to-panel, relaunch
and pinned-panel visual behavior remain unverified; the acceptance checkbox below remains open.

- [ ] Only a fresh threshold crossing triggers a 3 s activity view and system notification, at most once per account per hour. Respect notification permission/settings, preserve explicit account selection and do not alert on stale data.
- [ ] Balance rows show a 7-day sparkline from actual history, preserving gaps and currency/account separation.
- [ ] Hook-based activity is opt-in, uses documented events and has enable/disable cleanup checks; never silently edits another tool's configuration.

## v1.0 — distribution

2026-09-07 distribution-gate checkpoint: `make distribution-check` explicitly rejected the current
ad-hoc development app for missing Developer ID, hardened runtime, secure timestamp, stable version,
notarization ticket and enabled Gatekeeper assessment. Signature/resource integrity and the production
bundle ID passed. The checker is read-only and does not turn security on/off or upload anything.
The bundle script supports an explicitly supplied signing identity with runtime/timestamp options;
the actual Developer ID path remains unverified because no valid signing identity was found. Shell
syntax checking is now part of the ordinary verify gate; this is not a completed distribution gate.
The explicit-identity/debug preflight was exercised with a synthetic identity string: it exited 64
before signing and the existing executable hash was unchanged. `make verify` passes 174 tests.

2026-09-07 local image checkpoint: `make dmg` builds Release and creates
`build/Waterline-0.1.0-dev-arm64-development.dmg` plus a SHA-256 sidecar. `hdiutil verify` passed.
A read-only mount confirmed all six bundled files match the source app by SHA-256, strict code
signature integrity passed, and the Applications symlink/bilingual readme were correct. The image
was detached afterward; no installation replacement was performed.

`security find-identity -v -p codesigning` reported zero valid signing identities. The app signature
is ad-hoc with no team identifier. `spctl` returned accepted with `override=security disabled`; this
machine's policy override means that result is NOT clean-machine Gatekeeper evidence. No security
setting was changed by this work. Developer ID/notarization, clean installation, uninstall, cask and
signed updates remain incomplete; this artifact must remain labelled development.

- [ ] Signed/notarised DMG, Homebrew cask and signed appcast updates are verified on a clean installation. Update destinations/downloads and the enable/disable choice are documented before adding network traffic beyond provider queries.
- [ ] A new user with a supported signed-in account sees real data within one minute under normal network conditions; otherwise sees an actionable connection or capability reason, never sample values.

### 2026-09-07 provider colours and exit discoverability checkpoint

- `make verify`: 194 tests passed; strict format, whitespace and resource/audit checks passed.
- Separate verification app built and rendered `build/verification/island-provider-colours-zh.png` from synthetic data. Claude, Codex and Moonshot healthy quota bars now use distinct colours; stale/warning priorities remain in the metric renderer.
- Native CUA opened the footer Waterline menu and observed separate Collapse island / Quit Waterline entries. Clicking Quit terminated the isolated verification process, confirmed absent from the process list afterward. The production app was not terminated by this check.
- Region labels are derived from existing adapter manual-region definitions. Real multi-region account rendering remains to be verified; this fixture does not prove it.
- These checks do not accept the old shoulder silhouette, complete history valuation, provider live coverage, or distribution readiness.

### 2026-09-07 obstruction fix checkpoint

- Owner screenshot identified the still-running Claude design preview. Its exact process was terminated. All design hosts now start without opening a panel and hide an explicitly opened preview after pointer departure; three preview bundles recompiled. The new host hover timer is not yet natively exercised.
- Production panel no longer pins on showAccounts. An explicit footer pin owns persistence; unpinned resignKey closes the panel, retaining existing hover-exit dismissal.
- `make verify` passed all 194 tests and existing gates. Native isolated app launched collapsed; clicking opened its content and exposed Keep island open. Sending Cmd-Tab returned its AX tree to the collapsed header alone. This proves the tested app-switch dismissal, not the full pointer-transit/pinning matrix.
- Test process was terminated after validation and production bundle rebuilt without launching it. No preview/test instance should remain running.
- The shoulder-free shape compiles; complete new-shape visual and interaction acceptance is still pending.

### 2026-09-07 native balance history checkpoint

- New standalone SwiftUI Balance history window is reachable from footer and menu-bar entries. The footer closes the island before opening it.
- Engine query offers 7/30/90 days without a new journal or duplicated persistence. A clock-controlled relaunch test seeds boundary observations and proves period selection, retention cutoff, future exclusion and account isolation. All 195 tests and make verify gates pass; local app bundle rebuilt.
- Native isolated UI: footer history action opened a standard Balance history window with account picker and 7/30/90-day controls; a quota-only account showed the explicit no-balance-history state. Subsequent selection verification was interrupted by foreground changes and remains unverified. Test process terminated, with no verification or design-preview processes left running.
- New contour rendered offscreen to build/verification/island-unified-outline-zh.png and inspected: no shoulder connector remains.
- Do not treat this as billed-cost or token valuation implementation. Historical account switching, long-history rendering performance, region-series native checks and final visual/interaction acceptance remain open. The window defaults to an account with available balance data when possible, otherwise an explicit empty state.

### 2026-09-07 long-history rendering checkpoint

- BalanceChart pixel-envelope projection is used by both native balance graph surfaces. A 25,920-observation test retains endpoints and extreme values while bounding a 600-column graph to at most 2,400 samples. Gap tests prove an omitted gap inside one pixel is not bridged and entirely disconnected readings remain disconnected. Persisted data is unchanged.
- Detail charts now also separate posted-credit from available-balance history, matching the standalone history window.
- `make verify`: 198 tests in 41 suites passed, plus existing format, whitespace and audit gates. This verifies projection logic, not a measured native 90-day window rendering time; that performance check remains open.
- Token source evidence and unresolved attribution/pricing gates are recorded in docs/token-history-research.md. Token import/valuation is not implemented or accepted.

### 2026-09-07 refreshed development distribution checkpoint

- Rebuilt Release and `Waterline-0.1.0-dev-arm64-development.dmg` after the unified silhouette, explicit pin/dismissal, exit menu, history window and chart changes. Updated the bundled bilingual daily-use/exit instructions.
- DMG checksum verification passed. Read-only mount compared all six bundled files byte-for-byte with the Release bundle, checked the Applications symlink and install text, and passed strict sealed-resource verification. Volume detached afterward; no app launched or installation overwritten.
- Evidence: build/verification/development-image-20260907.json. Image SHA-256: d8e5b6cff9f47654b0c0d41d4f5e1c752ef00e23106d590f9b449e75a50327e7. Executable SHA-256: 2e31c00be93f3b5f4896cb88fb011452a6cdcce6722f1472c4d0e2fb978d2c81.
- `make distribution-check` intentionally remains failing: no Developer ID signature, hardened runtime, secure timestamp, stable release version or stapled ticket; Gatekeeper assessment is disabled/unavailable and cannot establish trust. No checks were weakened and no system security setting was changed. This artifact is development-only, not a completed public release.

### 2026-09-07 Antigravity official-schema foundation

- Official status-line documentation establishes a quota/account/plan payload separate from context usage. Standalone parser and synthetic tests cover 0/1 boundaries, absent quota/reset, incompatible fractions, malformed reset, wrong product, missing identity and bounded input.
- Parser returns a noncanonical DTO because the source supplies no quota observation timestamp; it cannot automatically create a fresh reading. No provider registration, status-line configuration mutation, authenticated fetch, account persistence or native integration is claimed.
- This is implementation groundwork and a narrowed integration path, not completion of the Antigravity provider. See docs/providers/antigravity.md for source and remaining flow requirements.

### 2026-09-07 offscreen native history verification

- Verification-only seed/export path reads a UUID-scoped synthetic journal through the engine and renders the actual SwiftUI HistoryWindow into its own bitmap without ordering a window. No desktop capture, real credential source, network fetch or production history injection is used.
- First exported images were incomplete; those measurements were rejected. Fixed capture sizing, native layout settling and an explicit verification background, then repeated the same scenarios. Visual inspection found and corrected wrapped period labels, empty-state header displacement, and untranslated region labels (also corrected the manual-key region picker).
- Final inspected outputs: build/verification/history-90d-usd.png (25,872 records), history-30d-cny.png (720 records, 国内 · CNY), history-empty.png. Their JSON reports record window_visible=false. Single-run USD query ~1.95 ms and bitmap stage ~21.95 ms; total settle/render ~314.68 ms includes a deliberate 250 ms layout wait. CNY bitmap ~59.24 ms. These are local isolated measurements, not a statistical benchmark or full interaction acceptance.
- make verify passed 202 tests plus all gates; verification-test passed its separate fixture isolation/restoration test. The production bundle was rebuilt; invoking --verification-history-render returned exit 64 before normal startup.
- Complete scrolling, keyboard/VoiceOver, same-window account changes and real multi-region historical data acceptance remain open. Each run exited automatically; generated temporary journals were removed after retaining evidence PNG/JSON files.

### 2026-09-07 history retry error classification

- Preserved the history-load error category through retry; incompatible complete records now return a data error instead of a generic disk-write error. A regression verifies the original journal bytes remain unchanged and cached current balances survive.
- Shared retry state prevents overlapping user retries; both History and Settings show progress/disable the action. History retry errors clear on successful recovery and do not clear an unrelated later error. The history window distinguishes unavailable history from an actually empty history.
- make verify passed 203 tests and gates. An isolated invalid-journal render exercises engine retry, AppModel error mapping and the native view. Its JSON records history_failed=true, original_preserved=true, window_visible=false, with the specific incompatible-record error; final Chinese PNG was inspected in build/verification/history-incompatible-zh.png.
- This corrects classification and feedback; it does not automatically repair incompatible complete records. Existing incomplete-tail recovery remains separate. No real history file or foreground window was touched. Local app bundle rebuilt.

### 2026-09-07 Token counter foundation

- Added strict Codex cumulative-counter validation and a versioned accumulator checkpoint. Four tests cover duplicate/restored totals, unknown-origin baselines, resets, cache correction, invalid counters/overflow and unsupported checkpoint versions.
- make verify passed 207 tests in 43 suites plus the existing gates. No log import, ownership mapping, price lookup, bill calculation or native Token history flow is claimed.
- Requested only service/plan/region names from the owner to plan applicable remaining live verification; no keys requested or sources enabled. Existing provider evidence limits remain open.

### 2026-09-07 read-only Codex log analyzer

- Implemented bounded JSONL reader and analyze-codex-log CLI entry point; source files remain unchanged. Synthetic cases cover metadata/model extraction, stable sample IDs, duplicate/reset handling, partial coverage and inherited-log refusal. No prompt/response body is part of output models.
- make verify passed 213 tests plus gates. Real current-task log analysis returned unsupported because a 7.2 MB compacted record exceeded the record budget. This remains a compatibility gap, not a passed real-log integration.
- No automatic scan, source opt-in, persistent Token ledger, historical account assignment, price table or native cost view is implemented by this step. The reader is not public-release acceptance.

### 2026-09-07 large Codex log compatibility

- Replaced whole-line buffering for irrelevant records with bounded streaming JSONL validation. Original relevant-record and file budgets remain; added complete-record syntax/duplicate-key/Unicode/depth/key-memory boundaries and deferred-tail handling.
- Same real task log that failed at its 7.2 MB compacted record now returns observed samples in Debug and Release. Invalid last-usage metadata is isolated from valid cumulative totals; it cannot acquire a model for pricing.
- Release evidence: build/verification/token-log-release-read.json (1,028 samples, coverageGaps=0, incompleteTail=false, ~0.738 s, max RSS 70,090,752 bytes). This proves the selected log read only. Account attribution, pricing, persisted import and native cost UI remain incomplete.
- No source journal, credentials or CLI configuration was changed, and no foreground window was opened.

### 2026-09-07 native Token import/persistence checkpoint

- Engine now owns a separate version-1 token-history.json ledger. Parsing runs in a cancellable utility task; lifecycle checks prevent a late commit after stop/sleep. Reimports are idempotent, appended observations can be added, and conflicting/shorter analyses or unknown saved versions leave existing data intact.
- Tests initially exposed cached URL file-size metadata: append reads stopped early and truncated inputs failed incorrectly. Refreshing resource metadata before reads fixed the original tests. Three temporary-file tests verify duplicate-byte stability, append, restart load, conflict/future-version preservation and cancellation without a ledger write.
- Native Token records window has explicit file selection, import progress/cancel, scoped retry, 7/30/90/all filters, cached-input subset labels, latest 100 details and error feedback. It does not scan automatically, assign accounts or price usage.
- make verify passed 223 tests plus gates. Verification export ran real parser→engine merge→duplicate merge→disk load→SwiftUI against 1,000 synthetic events: imported=1000, duplicate_added=0, loaded_sources=1, window_visible=false. Final Chinese image with column headers was inspected at build/verification/tokens-import-zh.png; JSON evidence is alongside it. Temporary synthetic files were removed after export, and local app bundle rebuilt.
- Native system-file-picker operation, real user-selected persistence, interactive cancellation and full accessibility remain unverified. Restart persistence is proved by the engine test, not by the offscreen render. No real task log was imported into the user's ledger in this checkpoint.

### 2026-09-07 dated reference valuation

- Added exact GPT-6 Astra Standard API-equivalent Token pricing from the official model page, dated 2026-09-07. Cache writes/read subsets, reasoning inclusion and the per-request >272K multiplier are tested; unrelated models, unproven cache data and invalid subdivisions stay unpriced.
- Token ledger v2 preserves optional pricing eligibility; v1 loads as unknown and can be reverified without changing observed counts. The existing future-version preservation test now uses v3. Migration/reimport and zero-versus-missing tests pass.
- make verify passed 226 tests plus gates. Native offscreen scenarios were asserted and visually inspected: all matched 720/720 → USD 0.5616; partial 710/720 → USD 0.5538 with a priced-portion label; none matched 0/720 → unpriced/em dash. PNG/JSON evidence: tokens-priced-zh, tokens-partial-price-zh and tokens-unpriced-zh in build/verification. Every report records window_visible=false.
- This is a dated Standard reference only, not actual service-tier billing or complete model/provider valuation. Account attribution, additional pricing scopes and real-user native import remain open. Local app bundle rebuilt; no real ledger was populated in these checks.

### 2026-09-07 reference catalog expansion

- Added exact Sol/Terra/Luna base reference rates from the official short/long-context table, with independent cache and output rates. Tests cover each model's short/long arithmetic and unknown alias rejection. Astra rates remain unchanged.
- make verify passed 227 tests and gates. Mixed-model native offscreen export asserted USD 0.11704 for 720 records; 7-day Luna subset asserted USD 0.0029568 for 168 records. The sub-cent PNG was inspected and shows < USD 0.01. Evidence is tokens-mixed-price-zh and tokens-small-price-zh PNG/JSON in build/verification; both report window_visible=false.
- These are dated Standard base references, not regional/actual-tier bills. Other models, providers and real account attribution remain open. No real user ledger or foreground window was changed.

### 2026-09-07 native file-picker flow

- Native testing exposed two real interaction problems: keyboard focus could return to the collapsed notch, and the data-only file-type filter disabled Open for JSONL. User-initiated history/settings actions now activate the app; only an expanded notch can become key. The chooser accepts items while the reader still requires a regular, bounded, valid Codex log.
- Repeated native scenario after fixes: opened Token records from island menu, opened NSOpenPanel, used Cmd-Shift-G to select the temporary JSONL, imported 1 sample (input 100/cache 80/output 10), reimported through the file item and observed Added 0, cancelled another chooser without error/count changes, then Cmd-Q exited the test app. The persisted synthetic ledger contained exactly one source/sample. Evidence: build/verification/native-picker-check.json.
- Process inspection confirmed no verification/preview app remained. The uniquely matched verification ledger directory and temporary source were removed. No real user log, credential or production ledger was used.
- make verify passed 227 tests plus gates, and local app bundle rebuilt. This verifies the native file-picker flow on this host with synthetic content; it does not prove every OS/accessibility case or real provider/account verification.

Daily selection follow-up (2026-09-07): explicit empty notch selection now remains empty
after deselecting the final account and after restart. Removing a selected account prunes
its ID without enabling Automatic. Offline engine tests verify these transitions, restore
to Automatic, duplicate and maximum-two validation. `make verify` passes 254 tests.
This patch has not yet been relaunched or checked through the native empty-selection UI.

Current development image (2026-09-07): Release rebuilt after the selected double-ripple
app/menu-bar identity and click-only single-account island changes. Read-only mounted
DMG verification matched all 19 application files and the installation README byte for byte
against the current bundle; the volume was ejected. Evidence: build/verification/development-image-v3.json.
Distribution checks pass bundle integrity, platform metadata, provider resources and icon
representations, but fail Developer ID, hardened runtime, secure timestamp, stable release
version and stapled notarization; Gatekeeper assessment is disabled/unavailable. This is
a development installation artifact only, not completed public-release or clean-install acceptance.

Reset display correction (2026-09-07): offline regression reproduced the selected
5-hour headline becoming weekly 95% exactly at its reset deadline. The corrected
presentation keeps the shortest cadence and returns Awaiting update. `make verify`
passes 257 tests; this is reset-boundary logic evidence, not a new live provider reset.
The earlier development-image-v3 file hashes describe the pre-correction artifact only.

Manual account recovery: 260 tests pass, including account-scoped interactive read
and no secret rewrite. Native Moonshot Settings Reconnect obtained a fresh response;
same-binary restart retained fresh account state. Two duplicate checkout app processes
were found during native checks and removed before restarting one current instance.
Automatic prevention of duplicate app launch remains to be hardened; writer locking
protects persistence but does not itself provide a complete single-instance UI flow.

Single-instance follow-up (2026-09-07): current native Release was running as PID 43169.
Two additional `open -n` launches automatically exited; the original PID survived and
the last five process samples contained only that original instance. Evidence:
`build/verification/single-instance-native.json`. The early application delegate guard
prevents duplicate engine/panel startup by selecting an older matching bundle instance.
`make verify` passed 260 tests. Simultaneous cold starts and different installed copies
sharing the production bundle ID have not yet received native verification.

Real-account runtime measurement completed (2026-09-07): PID 43169, Release SHA-256
`7fe0f38a8369600ba699750801a270d9974d24c696a935eb496a7388d5d2fa93`, four real
configured accounts. After ten-minute warm-up, 600 one-second samples measured mean
process CPU 0.1666661%, sampled peak physical footprint 25,216,104 bytes (24.04795 MiB),
lifetime peak 25,281,640 bytes, maximum sample gap 1.10274 s. Configuration and executable
remained unchanged. Both numeric thresholds pass for this binary. Evidence:
`runtime-current-real.json` and `runtime-current-real-summary.json`. This does not prove
all accounts refreshed successfully, filesystem privacy tracing, other macOS/display
coverage, or performance of later builds. The new unregistered Antigravity parser/process
helper was compiled only in debug tests during sampling and is not in this measured Release.

Configuration upgrade check (2026-09-08): offline tests verify exact-byte legacy backup,
0600 permissions, one backup per upgrade and no overwrite for future/corrupt configuration.
Full gate passes 281 tests. Read-only production metadata confirms configuration schema 2
and snapshot schema 10, both mode 0600, with one private configuration legacy backup and
seven private snapshot legacy backups. Evidence: `live-migration-metadata.json`. No
credential contents were printed or changed. Native source-toggle acceptance still awaits
manually unlocked macOS; this metadata check does not replace that flow.

Reconnect cancellation correction (2026-09-08): a delayed injected request reproduced
a late reconnect completion recreating operation state after Engine.stop(). Reconnect
now clears only its own still-current generation; stopped/replaced operations are not
rewritten. The same failing scenario passes and the full gate passes 283 tests. This
is an offline concurrency regression, not a new native Keychain authorization claim.

Owned-Keychain read isolation (2026-09-08): a controlled blocking key-store read proved
that pending authorization blocked Engine.snapshot(). Reads now run on a dedicated
queue while the engine awaits them. Tests verify snapshot responsiveness and rejection
of read results after stop or sleep; pending generation tokens are cleared for both.
Manual discovery rechecks lifecycle before reading subsequent keys and before applying
results. Full gate: 284 tests. These tests use injected stores, not the system Keychain;
native authorization-dialog responsiveness still requires an unlocked Mac check.

Architecture check (2026-09-08): isolated `x86_64-apple-macosx14.0` Release cross-builds
for WaterlineApp and waterline succeeded with the reference Xcode. The Intel CLI version
command ran under already-installed Rosetta and exited 0 (`intel-cli-runtime.json`).
The Intel test bundle compiled, but SwiftPM's testing helper attempted ARM loading and
failed with an incompatible-architecture error. Therefore the Intel test suite did NOT
pass and no Intel hardware/native GUI support is claimed. Current development DMG remains
arm64. Evidence: `intel-build.log`, `intel-cli-build.log`, `intel-tests.log`.
