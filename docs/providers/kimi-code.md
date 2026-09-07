# Kimi Code

Implementation: registered regional manual Code Console key adapter, Engine/CLI/Settings wiring and offline tests. No live quota verification yet.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Kind: window (Kimi Code subscription usage). Doc status: community. Milestone: v0.2.

A Kimi Code subscription and a Moonshot platform top-up are different accounts with different keys;
this file covers the subscription. Calls routed through a gateway (OpenCode Go, Hermes, a relay) with a
kimi model are **not** this account.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `KIMI_CODING_API_KEY` → `KIMI_CODE_API_KEY` in config files | Only when the harness base URL is `api.kimi.com/coding`. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| usage | `GET https://api.kimi.com/coding/v1/usages`, `Authorization: Bearer <key>` | dsh-provider-balance, dsh-balance | community, unverified |

## Allowed hosts

`api.kimi.com`, `api.kimi.ai`

## Response mapping

New manual accounts explicitly select cn (`api.kimi.com`) or global (`api.kimi.ai`), using
`/coding/v1/usages` on that host. Existing regionless accounts retain their historical .com mapping. No browser-cookie scan,
proxy override or Moonshot-platform key substitution is performed. CLI-owned OAuth/device-header
integration remains a separate unimplemented path; Waterline never creates a foreign device_id.

`usage` is the subscription summary. Each `limits[]` entry has a duration/timeUnit and an independent
detail. Map string-valued `limit`, optional `used`, and optional `remaining`; when used is absent,
used = limit - remaining is allowed for the same component. A positive limit permits used/limit;
a zero denominator produces no percentage, while reported counts remain visible. Counts are labelled
quota units, not money or inferred tokens. Missing resets remain absent. Supported duration units are
minute/hour/day; convert only reported durations. The summary label does not assume a fixed period.

Map `user.membership.level` as the reported label without a price/quota lookup table. Extra fields are
ignored. Malformed individual windows do not erase successful siblings or the summary. Duplicate
window identities are rejected. Monthly web-membership enrichment and CLI OAuth discovery are not
included in the initial implemented scope.

## Evidence

- Official [overview](https://www.kimi.com/code/docs/en/) and [data locations](https://www.kimi.com/code/docs/en/kimi-code-cli/configuration/data-locations.html), inspected 2026-09-07.
- Endpoint/schema evidence: [CodexBar Kimi notes](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/docs/kimi.md) and KimiModels.swift at commit `c15f736ef42158b830b47db1970ea91886e30e85`, inspected 2026-09-07. Used as protocol evidence, not copied code.
- Default `~/.kimi-code/credentials/kimi-code.json` was absent in a metadata-only presence check; no credential content was exported.
- Last capability review: 2026-09-07
- Last live verified: —
- Verified account/region/metric scope: none.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.

## Official current CLI review — 2026-09-07

Installed CLI reports 0.41.0 at `~/.kimi-code/bin/kimi`. Its help points to the current
[official repository](https://github.com/MoonshotAI/kimi-code), reviewed at commit
`5e622e5b5240000326bed29970199e1c0244a588`. This source revision is not asserted to be the
exact installed binary revision. `packages/oauth/src/region.ts` explicitly maps mainland-cn
to api.kimi.com and global to api.kimi.ai; managed-usage.ts fetches `/coding/v1/usages`
with Bearer authentication. These are quota units, not CNY/USD balances.

Waterline now exposes these manual regions and tests selected-host routing and rejection
of unknown regions before HTTP. The legacy nil-region path remains China for compatibility.
OAuth config selection, expiry/refresh and identity handling are still unfinished. The public
source stores named credential JSON files and region-aware OAuth references; an absent
old default filename is insufficient evidence that the installed CLI is logged out.
No local credential contents were inspected and no live Kimi query was performed here.

Local configuration review found one provider with baseUrl host api.moonshot.cn and apiKey,
without an OAuth reference. Only field names/host were printed; no secret values. Standard
`~/.kimi-code/credentials/kimi-code.json` was absent. This explains this machine's CLI
availability through the Moonshot platform; it does not establish a Kimi Code subscription.
The actual Moonshot query and restart limitation are recorded in moonshot.md.
