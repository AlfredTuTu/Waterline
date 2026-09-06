# MiniMax

Kind: both (Coding Plan windows per model; platform balance). Doc status: community. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `MINIMAX_API_KEY` → `MINIMAX_CN_API_KEY` → `MINIMAX_INTL_API_KEY` in config files | CN `api.minimaxi.com`, international `api.minimax.io`. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| coding plan remains | `GET https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains` (CN) / `https://api.minimax.io/…` (intl), `Authorization: Bearer <key>` | dsh-provider-balance, CodexBar | community, unverified |

Observed shape: `model_remains[] { model_name, current_interval_usage_count, current_interval_total_count, current_interval_end_timestamp }`.

## Allowed hosts

`api.minimaxi.com`, `api.minimax.io`

## Response mapping

_To be filled by the adapter PR._

Last verified: —
