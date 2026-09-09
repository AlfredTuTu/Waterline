# Moonshot (platform top-up)

Implementation: registered regional manual-key adapter, Engine/CLI/Settings wiring and offline routing tests. Native entry and both live regions remain unverified.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Kind: balance. Doc status: official. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `MOONSHOT_API_KEY` → `MOONSHOTAI_API_KEY` in config files | CN `api.moonshot.cn` and international `api.moonshot.ai` are distinct endpoint scopes; select the account region explicitly. Confirm currency from the response or linked endpoint contract, not from locale. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| balance | `GET https://api.moonshot.cn/v1/users/me/balance` or `https://api.moonshot.ai/v1/users/me/balance`, `Authorization: Bearer <key>` | Moonshot docs | official |

Documented shape: `data { available_balance, voucher_balance, cash_balance }`.

## Allowed hosts

`api.moonshot.cn`, `api.moonshot.ai`

## Response mapping

A new manual account must explicitly select `cn` or `global` before a key is stored. The region is
persisted separately from billing identity and survives key replacement. The selected region fixes
one host; neither 401 nor another failure retries the key against the other region. Console links
also follow the saved region. CLI creation supports `--region cn` or `--region global` with `--stdin`.

Both official endpoint references define available_balance, voucher_balance and cash_balance as
major currency units: CNY at the CN endpoint, USD at the international endpoint. Currency therefore
comes from the selected endpoint's documented contract, not locale. `code == 0` and `status == true`
are required; the generated code=123 example is not used instead of the explicit success definition.
`data.available_balance` is decoded as Decimal and retained directly, including zero. Optional voucher
metadata maps to gift; malformed vouchers preserve the available balance with a component error.
Cash balance can be negative under the contract and is not subtracted from available_balance again.
Cash decomposition is not currently displayed separately. No quota percentage or reset is invented.

## Evidence

- Official [CN balance endpoint](https://platform.kimi.com/docs/api/balance) and [international balance endpoint](https://platform.kimi.ai/docs/api/balance), inspected 2026-09-07. Both explicitly document units and independent regional keys.
- Last capability review: 2026-09-07
- Last live verified: —
- Verified account/region/metric scope: none.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.

## Real China account check — 2026-09-07

The installed Kimi Code 0.41.0 CLI reports a provider using `api.moonshot.cn` and an API
key, not a Kimi Code OAuth reference. With authorized local-account testing, that one key
was passed in memory to Waterline's standard manual-account stdin flow (region cn).
The flow returned exit 0 and fresh usage. A positive CNY total balance and positive CNY gift balance were observed at 13:07:33Z;
exact personal amounts remain only in ignored local evidence. These are platform money balances, not subscription
quota units. Evidence: `build/verification/moonshot-local-import.json` and
`build/verification/moonshot-cn-live.json`; no credentials were logged.

On relaunch, the app's noninteractive read of the CLI-created owned Keychain item returned
keychainLocked and retained the prior balance as stale. Thus endpoint and manual CLI
query are live verified for this China account; app restart/background access is NOT
verified and currently fails. A normal interactive Connect can request access, but durable
cross-binary permission still depends on stable signing/installation. No ACL bypass or
credential export was used. International-region live verification remains open.

Native recovery follow-up: the selected-account Reconnect button was exercised in
Settings and returned a fresh Moonshot response at 13:14:30Z (`moonshot-native-reconnect.json`).
A subsequent same-binary restart, without rebuilding/re-signing, restored an idle fresh
account and retained its 13:14:51Z reading in the 13:15:36Z snapshot
(`moonshot-same-build-restart.json`). This proves recovery and retained startup access
for this binary; it is not proof of a new post-restart balance request or permission
surviving future ad-hoc rebuilds. Key material was not rewritten by Reconnect.

History persistence check: production history contains three distinct observation keys
for the imported China account, all with the same CNY amount at the three actual query times. The
records survived native reconnect and same-binary restart; no mixed currency or duplicate
observation key was found. Sanitized evidence is `moonshot-history-live.json`. The short
span does not establish a 24-hour decrease estimate or actual spending. Native history
chart display for these records remains unverified.
