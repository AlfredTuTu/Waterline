# Codex

Kind: window (primary 5-hour and secondary weekly windows; plan type). Doc status: community. Milestone: v0.1.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 1 | `~/.codex/auth.json` | `tokens { id_token, access_token, refresh_token, account_id }`, `last_refresh`; or `OPENAI_API_KEY` when the user chose API-key login (no usage windows in that mode). |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| usage windows | `GET https://chatgpt.com/backend-api/wham/usage` with `Authorization: Bearer <access_token>`, `ChatGPT-Account-Id: <account_id>` | CodexBar | community, unverified |
| local fallback | latest `rate_limits` event in `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` (`primary { used_percent, window_minutes, resets_at }`, `secondary { … }`) | CodexBar | local, no network |

## Allowed hosts

`chatgpt.com`

## Response mapping

_To be filled by the adapter PR._

## Pitfalls

- The local fallback is only as fresh as the last session; report it as the reading with its own
  `fetchedAt`, never as a substitute for a failed network read without the age being visible.

Last verified: —
