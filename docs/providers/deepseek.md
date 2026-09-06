# DeepSeek

Kind: balance. Doc status: official — the only fully documented balance endpoint in the set. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `DEEPSEEK_API_KEY` in config files | Users route Claude Code with `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| balance | `GET https://api.deepseek.com/user/balance`, `Authorization: Bearer <key>` | DeepSeek API docs | official |

Documented shape: `is_available`, `balance_infos[] { currency, total_balance, granted_balance, topped_up_balance }`.

## Allowed hosts

`api.deepseek.com`

## Response mapping

_To be filled by the adapter PR._

Last verified: —
