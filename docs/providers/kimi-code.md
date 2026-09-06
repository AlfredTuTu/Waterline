# Kimi Code

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

`api.kimi.com`

## Response mapping

_To be filled by the adapter PR._

Last verified: —
