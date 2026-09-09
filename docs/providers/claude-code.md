# Claude Code

Implementation: default macOS Keychain/file discovery and initial quota adapter implemented; live verification pending.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Kind: window (5-hour and 7-day rolling windows; plan tier). Doc status: community. Milestone: v0.1.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 1 | Keychain generic password, service `Claude Code-credentials`, account = macOS user name | Data is JSON: `claudeAiOauth { accessToken, refreshToken, expiresAt, scopes, subscriptionType }`. Data access may require an ACL prompt; verify noninteractive access and attribute enumeration on supported macOS versions. |
| 1 | `~/.claude/.credentials.json` | Same JSON, used when the Keychain item is absent. |
| 3 | — | Manual OAuth-token entry is outside the supported connection flow; use the tool login. |

Claude Code owns token refresh; Waterline never refreshes its credentials. An expired token parks
fetching until the credential changes or Connect rereads it. Keep a previous reading stale with its
age; show unavailable only when no valid reading exists.

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| account identity | `GET https://api.anthropic.com/api/oauth/profile`, Bearer access token | CodexBar OAuth source | implemented; one identified Pro account observed 2026-09-07 |
| usage windows | `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <accessToken>`, `anthropic-beta: oauth-2025-04-20` | CodexBar, claude-token-monitor | one Pro 5h/7d live check, 2026-09-07 |

Response shape observed by those tools: `five_hour { utilization (0–100), resets_at }`,
`seven_day { … }`, optionally per-model seven-day objects. `subscriptionType` from the credential
gives the plan label.

## Allowed hosts

`api.anthropic.com`

## Response mapping

Default login scope only. Enumerate the `Claude Code-credentials` service; read each item under the
Connect/background policy. Use the credential file only when that service has no items. A locked
item produces an identified source row with `keychainLocked` and no HTTP request. Profile identification
uses validated `account.uuid` and `organization.uuid`; never merge by email. The profile request runs
through the same injected allowlisted HTTP boundary during discovery, before committing account metadata.

Map `five_hour`, `seven_day`, and supported model/app/routines weekly fields independently. Percent
utilization is divided by 100; missing utilization/reset stays absent; invalid fields produce scoped
failures. ISO dates accept fractional seconds. The engine retains failed previous components with their
own original times. Primary windows remain in overview. `subscriptionType` is a reported credential
plan label, never a rule for inventing windows.

Current gaps: the newer scoped `limits` array, extra-usage monetary semantics, alternate config
directories, and additional credential-profile forms still require implementation/evidence. These
are not counted as supported by the initial adapter.

## Pitfalls

- Background reads must disable interaction. List attributes to identify a provisional account;
  read the data only if access is already allowed without a prompt. Otherwise report `keychainLocked`
  and offer Connect. Verify this policy on native macOS, including rebuild/reconnect behaviour.
- An ad-hoc signed rebuild may need renewed Keychain authorisation. Record observed behaviour;
  no rebuild is an exception to the ban on background prompts.

## Evidence

- Official authentication/storage evidence: [Claude Code authentication](https://code.claude.com/docs/en/authentication), inspected 2026-09-07; local CLI version 2.1.263.
- Endpoint/shape evidence: [CodexBar ClaudeOAuthUsageFetcher](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/app/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift), commit `c15f736ef42158b830b47db1970ea91886e30e85`, inspected 2026-09-07. Used as protocol evidence, not copied implementation.
- Last capability review: 2026-09-07
- Last live verified: 2026-09-07, one Pro account with 5-hour and weekly windows. Earlier noninteractive source checks returned keychainLocked promptly. Successful quota access does not establish durable authorization across ad-hoc rebuilds.
- Verified account/region/metric scope: none.

2026-09-07 read-only evidence reconciliation: the current production snapshot's Claude entry stores
`unavailable.error.unauthorized`. This is a cached result, not a fresh request or proof of current
Keychain access. It supersedes describing the outstanding gap solely as OS access. An authorised
reconnect must establish usable authentication and an actual successful quota response before setting
a live-verification date. No credentials, response bodies or account identifiers were printed during
this snapshot inspection.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.

## Later real-account evidence — 2026-09-07

The earlier unauthorized snapshot reconciliation above is historical, superseded for quota
availability by `build/verification/live-cadence-and-pools.json`: at 12:23:22Z the production
snapshot contained fresh Claude `five_hour` 18% and `seven_day` 24%, with explicit 18000/604800
second cadences. Native account rendering showed Pro and the same 5h/7d data. A later read-only
production snapshot at 13:00:53Z again contained a fresh Claude response; the sanitized status
is recorded in `build/verification/provider-status-current.json`. This confirms recovered
access, not permanent Keychain permission. No credentials or raw response bodies were captured.

Max/Fable and other account tiers remain synthetic contract coverage only. The parser accepts
reported dynamic model scopes; this is not a claim that those scopes exist for the Pro account.

## Official local status-line evidence (2026-09-08)

[Official status-line reference](https://code.claude.com/docs/en/statusline) documents
`rate_limits.five_hour` and `rate_limits.seven_day`, each containing
`used_percentage` and Unix `resets_at`. Each window may be absent; windows are
removed after reset. The payload is available after an API response, and the
script itself does not consume API tokens. This is independent of context-window
percentages and session list-price costs. The documented example requires v2.1.251+.

The owner's CLI v2.1.263 was tested with session-only settings; no persistent
statusLine was installed. A resumed session first emitted no rate_limits. After
one response it emitted 5h 30% and 7d 31%, with reset epochs. Only quota, version,
receipt time and API-duration fields were retained in ignored verification evidence.
The temporary CLI exited normally. `disableAllHooks` also prevented this local
status-line probe from running, so it was removed from the temporary invocation;
the user's configuration contained no hook events and was not changed.

`ClaudeStatusline` validates a bounded payload and returns a distinct observation
DTO, never a live Usage reading. It deliberately lacks account attribution or a
fabricated provider timestamp: session_id is a session identifier, not an account.
API-duration progression alone does not prove refreshed quota. Before integrating,
bind the source to the correct native login and retain observation provenance;
repeated callbacks and replayed cached windows must not advance freshness.
The capture/engine flow and idle fallback remain unfinished. The undocumented
`/api/oauth/usage` query rate limit remains unknown; 60 seconds is app policy,
not a published provider guarantee.

Local account association: `.claude.json` contains `oauthAccount.accountUuid` and
`organizationUuid`. A bounded metadata read on the owner's machine matched both
UUIDs to Waterline's profile-verified identity. `ClaudeLocalLogin` validates both
and compares UUID values case-insensitively; matching only the user while ignoring
the organization is not sufficient. No name, email, plan or token is retained by
this parser. This is association evidence, not live membership evidence. Binding
at a session's start and rejecting replay across account switches remain necessary
before enabling persistent status-line ingestion.

The empty-session condition was verified separately on v2.1.263 without sending
a model request: `rate_limits` absent and `total_api_duration_ms` zero.
`ClaudeSessionBinding` can initialize only in this state with matching local and
profile-verified account/organization UUIDs. It rejects later first attachment,
other sessions, changed logins and regressing API-duration counters; duplicate
callbacks do not yield another observation. Passing this gate is necessary but
still does not establish a provider observation timestamp or complete ingestion.

Local observation persistence uses a separate writer lock and atomic private files,
keyed by validated session UUID. Identical quota values retain their first receipt
time even after further API activity; missing fields do not become zero. Stored
records validate account scope, session ID and quota bounds when loaded. This is
not yet installed capture or engine ingestion; session-file retention limits and
end-to-end delivery remain outstanding before enabling the source.

The `waterline claude-statusline-v1` receiver now reads bounded stdin, checks the
default local login against exactly one profile-verified Claude account in the
Waterline snapshot, and writes the separate private local-observation store. It
does not open Keychain or make network requests. Custom Claude configuration
directories, token/API-key overrides and alternative provider environments are
rejected until their identity routes are supported. The receiver is not installed
into the owner's persistent Claude settings yet; app ingestion and retention are
still required before that activation. Injected-home tests verify file integration
and exclusion of transcript path, workspace and email from stored observations.

App-side ingestion is now implemented: a filesystem event source watches the
local observation directory, reads the latest matching login observation off the
main actor, then publishes it through Engine.receiveClaudeObservation. No periodic
file scan is added. Receipt must be recent and later than the replaced metric;
expired local windows and cross-account values are rejected. Other provider
windows remain. Local progress defers the ordinary remote schedule by five minutes
without clearing server Retry-After or credential parking. This is an app policy,
not an asserted Anthropic limit. Store retention caps owned session files at 128,
leaving unrelated files untouched. Persistent Claude configuration activation and
native delivery verification remain outstanding.

Native owner-account validation — 2026-09-08 23:54: the installed receiver was
configured once, preserving a private settings backup. A new official CLI session
created a zero-duration binding, then a normal model response produced local 5h 38%
and 7d 32%. The app filesystem listener accepted it automatically: snapshot origin
became local and the native card showed both values without a manual refresh.
The earlier stale/rate-limited state was replaced by local quota data while the
server deadline remained stored. CLI exited normally after validation.

Ordinary Claude network fallback now uses a minimum 300-second interval, including
view-open acceleration; other providers retain their own existing cadence. Reset
boundaries and explicit manual refresh still respect provider backoff. This is
Waterline policy, not a published Anthropic request allowance. Persistent source
activation with an already-customized status line remains preserved/unmodified
and falls back to server queries; no unsupported universal setup claim is made.

Release-soak correction: background credential checks now include Claude with
user interaction disabled. The adapter caches profile identity by the secret
revision (bounded to 32 entries), so unchanged saved credentials do not cause a
profile HTTP request every minute. A changed token requires profile verification;
profile failures retain backoff with at least a five-minute retry interval.
This changes neither the CLI credentials nor authorization parking for an unchanged
failed token. Live refresh-after-rotation must be verified on the final candidate.

## Desktop GUI source — 2026-09-09

Installed Claude 1.46388.4 ships a version 2 `plan-usage-history.json` store under
its Application Support directory. Static inspection of its bundled usage code
shows samples `{t,org,u}` written only after successful authenticated usage
responses; `t` is epoch milliseconds, `fh` and `sd` are percentage utilization.
History is retained for 30 days, appends are limited to one per organization per
270 seconds, and native polling uses 300 seconds after recent interaction or 900
seconds while idle, with additional native tray/idle gating. These are this desktop
version's implementation details, not a published universal HTTP rate limit.

Waterline reads this file and only `lastKnownAccountUuid` from desktop `config.json`.
It does not decrypt token caches, read browser cookies or call GUI-private IPC.
Both the user and latest sample's organization must match the known Waterline
account. Version 1 unscoped history is not used. The owner's latest sample matched
both identifiers and reported 5h 0%, 7d 33% at 08:14:37, replacing the obsolete overnight
CLI observation. This source has no reset timestamp, so it cannot manufacture one.

Desktop records carry their actual sample time and a 30-minute maximum age (twice
the observed idle poll interval). Re-reading or receiving unrelated filesystem
events does not change that sample time. Older desktop samples cannot replace
newer CLI/server observations. An independently current local reading remains
visible if a fallback request fails; the fallback failure and scheduling limits
remain in the engine. Missing/outdated GUI data is not treated as fresh or zero.
The desktop app's own background pause behavior can limit new samples; CLI data
and normal server fallback remain complementary. Final native verification of
this addition is still required before release.

Native recovery verified on the installed GUI-source candidate: the card changed
from the obsolete 5h 38% / login error to 5h 2%, 7d 33%, observed by Claude Desktop at
08:30:07. Waterline persisted that original time and no fabricated reset timestamp.
Relaunching the same binary restored the same data; corresponding synthetic tests
confirm that a failed fallback retains authentication parking while the valid local
windows remain available. Further automatic-cycle and final-release verification
are still required.
