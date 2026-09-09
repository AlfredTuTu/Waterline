# Codex

Implementation: initial ChatGPT file discovery and live quota adapter implemented; first CLI live check passed on 2026-09-06. Complete account lifecycle and native UI verification remain open.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Kind: window (primary 5-hour and secondary weekly windows; plan type). Doc status: official source code (internal endpoint, no public stability guarantee). Milestone: v0.1.

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

`auth_mode=chatgpt` with `tokens.access_token`, `tokens.account_id`, and an ID-token subject
selects the single ChatGPT source. API-key mode performs no request. No token refresh or credential
write occurs. A stable local UUID is reconciled by provider, endpoint scope, account ID and subject;
token changes are independent. Unknown legacy identities remain separate.

`rate_limit.primary_window` and `secondary_window`, plus each `additional_rate_limits` bucket,
map `used_percent / 100` to a fraction. Preserve zero; accept only finite 0–100 percentages.
`limit_window_seconds / 60` labels the duration when present; `reset_at` is Unix seconds when present.
Null/absent windows stay absent. Account plan labels never infer windows: synthetic Plus 5-hour+weekly and other-plan weekly-only cases are tested independently. The single live account is not evidence for all plans. Extra fields are ignored. Malformed windows yield component errors
without dropping independently valid windows. Failed components with stable IDs retain their prior values and original observation time, marked stale inside a partial result.
`plan_type` is optional. Credits are not mapped to currency balances without a currency contract.
Live receipt time is the observation time. Local rollout fallback is not implemented.

401 maps to unauthorized; 403 to access denied; 429 parses numeric or HTTP-date Retry-After;
other failures are safe transport errors. Initial inactive 5-minute scheduling and per-account backoff/parking are implemented; active cadence, credential-change recovery and relaunch preservation of deadlines remain open.
HTTPS is restricted to `chatgpt.com`, port 443, with redirects refused.

## Pitfalls

- The local fallback is only as fresh as the last session; retain the record's original
  `observedAt` and local origin; `fetchedAt` is when Waterline read it. Do not substitute it for a failed
  network read without showing its age and failure. The scaffold fetch result cannot yet express this metadata.

## Evidence

- Source: OpenAI Codex commit `ac192cd7937b0d73edc6dffe009940ae53782dd4`, inspected 2026-09-06:
  [request routing](https://github.com/openai/codex/blob/ac192cd7937b0d73edc6dffe009940ae53782dd4/codex-rs/backend-client/src/client/rate_limit_resets.rs),
  [headers and mapping](https://github.com/openai/codex/blob/ac192cd7937b0d73edc6dffe009940ae53782dd4/codex-rs/backend-client/src/client.rs),
  [window fields](https://github.com/openai/codex/blob/ac192cd7937b0d73edc6dffe009940ae53782dd4/codex-rs/codex-backend-openapi-models/src/models/rate_limit_window_snapshot.rs).
- Last capability review: 2026-09-06
- Last live verified: 2026-09-06, CLI query and snapshot write only.
- Verified account/region/metric scope: one existing ChatGPT login on chatgpt.com; four quota windows across ordinary and additional buckets, including reported zeros. No inference, billing mutation or raw response export.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.
