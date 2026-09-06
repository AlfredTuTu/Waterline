# Moonshot (platform top-up)

Kind: balance. Doc status: official. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `MOONSHOT_API_KEY` → `MOONSHOTAI_API_KEY` in config files | CN platform `api.moonshot.cn` (CNY) and international `api.moonshot.ai` (USD) are separate accounts; the base URL in use decides. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| balance | `GET https://api.moonshot.cn/v1/users/me/balance` or `https://api.moonshot.ai/v1/users/me/balance`, `Authorization: Bearer <key>` | Moonshot docs | official |

Documented shape: `data { available_balance, voucher_balance, cash_balance }`.

## Allowed hosts

`api.moonshot.cn`, `api.moonshot.ai`

## Response mapping

_To be filled by the adapter PR._

Last verified: —
