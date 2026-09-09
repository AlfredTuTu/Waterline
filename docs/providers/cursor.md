# Cursor

Implementation: registered. Local SQLite discovery, usage summary and Grok Bot status have offline
coverage. One local Pro account passed live summary and Grok Bot queries on 2026-09-07. Legacy request-based usage now has offline mapping/request coverage; a legacy account remains live-unverified.
Browser-cookie accounts and additional Cursor profiles remain open.

## Credentials and transport

Read only `cursorAuth/accessToken` from `ItemTable` in
`~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`. The system SQLite reader uses
`SQLITE_OPEN_READONLY`, a 250 ms busy timeout and a 16 KiB value limit. It never copies the database,
reads refresh tokens/email or rotates credentials. Tests inject the reader; production installs it in
`DiscoveryEnvironment.current`. Missing files/rows produce no discovered account; unreadable existing
sources remain visible with a connection error.

JWT `sub` supplies the account identifier after its final `|`; the secret is validated for cookie-safe
characters. This is local identity extraction, not JWT signature verification. Cursor authenticates the
request. Identity and the source path are separate from the token, so rotation preserves local settings.
Only `cursor.com` is allowed. Redirects are rejected by the shared HTTP client.

| Purpose | Request | Mapping |
|---|---|---|
| Main usage | `GET https://cursor.com/api/usage-summary` | Cookie `WorkosCursorSessionToken=<subject>%3A%3A<token>` |
| Legacy requests | `GET https://cursor.com/api/usage?user=<subject>` | Same scoped session cookie; optional per-account response |
| Grok Bot | `POST https://cursor.com/api/dashboard/get-sand-usage-status`, JSON `{}` | Same cookie plus `Origin: https://cursor.com`; read-only status query |

No inference request, billing change or paid usage is initiated. The console action opens
`https://cursor.com/dashboard` without credentials in its URL.

## Response mapping

- Require a recognized `individualUsage` or `teamUsage` object. `membershipType` is reported verbatim;
  it does not choose limits. Optional `billingCycleEnd` is ISO 8601; invalid supplied dates fail parsing.
- `individualUsage.plan`, `.overall`, `.onDemand`, `teamUsage.pooled` and `.onDemand` remain separate
  windows. Optional `used`/`limit` are nonnegative integer USD cents, divided by 100 with Decimal.
  A positive limit permits a ratio; absent/zero limits never fabricate a fraction or unlimited label.
  Counts retain over-limit spending even when the meter is full. These are usage/caps, not balances.
  If reported quota percentages coexist with USD values, put the USD values in a separate spend
  window without a fraction: the live response established that the two ratios can differ.
- `totalPercentUsed`, `autoPercentUsed` and `apiPercentUsed` are percentage units, including values
  below 1. Independent Auto/API pools are never averaged. Percentages must be finite and in 0–100.
  The installed Cursor 3.19.13 UI and the owner’s console identify `autoPercentUsed` as Cursor Models
  and `apiPercentUsed` as Other Models. When either pool exists, omit the aggregate total quota bar;
  retain totalPercentUsed only as the older-response fallback. Field IDs remain stable.
- Missing fields stay missing; `enabled:false` is explicitly labelled Disabled. A malformed block
  produces a scoped component failure and leaves independent blocks available.
- Grok Bot requires `hasNonZeroIncludedLimit`. False supplies no window; true allows the optional
  `usagePercent` and ISO `nextResetTimestampUtc`. It is a separate quota on the same Cursor account,
  not proof of free access to every Grok model in Cursor or a standalone xAI balance.
- Grok endpoint 404 means the optional surface is absent. Other errors preserve main usage with a
  `grok-bot` component failure. Main endpoint failure currently fails the fetch before Grok is queried;
  independently recovering Grok in that case remains open.
- Shared status mapping handles 401, 403, 429/Retry-After and transport failures. No raw responses,
  tokens or cookies appear in UI diagnostics.

## Legacy request quota

`gpt-4.maxRequestUsage` establishes a reported request cap. Prefer `numRequestsTotal` over
`numRequests`; both are nonnegative integers. Missing caps produce no request window, and zero caps
or missing used counts produce no fraction. A usable request fraction replaces modern Included/
Auto/API quota bars; independent spend and on-demand metrics remain separate. Reset comes only
from the summary's supplied billing-cycle end, never a month inferred from `startOfMonth`.

The request endpoint is queried after summary/Grok with the same host-scoped cookie and validated
subject. A 404 means the optional surface is absent; other failures remain scoped to `legacy-requests`
and preserve independent metrics. The 2026-09-07 modern Pro regression query returned fresh usage,
exit 0 and no legacy request window at `2026-09-06T18:49:20Z`. This is not a live legacy-plan check.

## Evidence

Last capability review: 2026-09-07. Last live verified: 2026-09-07 (Melbourne),
`2026-09-06T18:00:38Z`. Scope: one local Pro account; summary total/Auto/API percentages, reported
USD usage/cap, disabled on-demand and Grok Bot zero usage. Grok did not supply a reset timestamp.
CLI exit 0, fresh state with no component failures, same account ID after a second process start.
The first Grok attempt returned 403; adding the reference request's Origin header resolved it.
No raw capture was saved, no credential output, and no inference or billing mutation was performed.
Dashboard visual comparison and native account actions remain unverified.

- [Cursor usage and limits](https://prod.cursor.com/help/models-and-usage/usage-limits): billing-cycle
  pools and dashboard semantics; it does not document the private endpoint schema.
- [Cursor usage-based charges](https://prod.cursor.com/help/account-and-billing/overages): included
  usage and on-demand billing are distinct.
- Community schema inspected at CodexBar commit `c15f736ef42158b830b47db1970ea91886e30e85`:
  [summary](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe.swift),
  [local auth](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Cursor/CursorAppAuth.swift),
  [Grok Bot](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Cursor/CursorSandUsage.swift).

Offline tests cover pool separation, percent units, absent caps, partial schema failure, Grok eligibility,
cookie routing, optional-endpoint failure, malformed token rejection and nonmutating/noncreating SQLite
reads. Synthetic SQLite/engine integration also verifies exclusive-lock timeout and recovery,
committed WAL token rotation without database/WAL mutation, scoped reconnect, and stable account
identity/name/pin after restart. No real Keychain or network is used by these tests. Native actions,
additional profiles/plans and dashboard comparison still need evidence before the full acceptance bar.

## Current pool reconciliation — 2026-09-07

The owner’s console and installed official Cursor UI show Cursor Models and Other Models.
`build/verification/live-cadence-and-pools.json` records the mapped real Pro response:
Cursor Models 1.2533333333333334%, Other Models 0%, plus separate Grok Bot weekly data,
reported included spending and on-demand state. These are not duplicate quota pools.
The application rounds display precision without changing stored fractions. The later
13:00:42Z response remained fresh in `provider-status-current.json`; no additional plan
or regional coverage is inferred from that account.
