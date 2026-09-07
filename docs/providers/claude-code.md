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
- Endpoint/shape evidence: [CodexBar ClaudeOAuthUsageFetcher](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthUsageFetcher.swift), commit `c15f736ef42158b830b47db1970ea91886e30e85`, inspected 2026-09-07. Used as protocol evidence, not copied implementation.
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
