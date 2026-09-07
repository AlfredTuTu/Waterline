# DeepSeek

Implementation: registered manual-key adapter plus opt-in process-environment and global Claude settings discovery, with Engine and Settings flows and offline tests. Native Keychain writes and live balance verification remain unverified.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Kind: balance. Doc status in planning notes: official candidate; documentation link and current mapping still need verification. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | Process environment `DEEPSEEK_API_KEY` | Implemented only after per-source opt-in. Shell/config-file declarations remain unimplemented; no custom base URL is followed. |
| 2 | `~/.claude/settings.json` → `env.ANTHROPIC_BASE_URL` and `env.ANTHROPIC_AUTH_TOKEN` | Separate opt-in; direct HTTPS DeepSeek Anthropic URL required. No helpers/hooks/project settings evaluated. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| balance | `GET https://api.deepseek.com/user/balance`, `Authorization: Bearer <key>` | DeepSeek API docs | official |

Documented shape: `is_available`, `balance_infos[] { currency, total_balance, granted_balance, topped_up_balance }`.

Map each supported `balance_infos` currency entry independently; preserve valid entries and report
malformed components per the shared partial-result rules. Do not silently select only the first balance.

## Allowed hosts

`api.deepseek.com`

## Response mapping

`GET /user/balance` uses Bearer authentication at the single global `api.deepseek.com` endpoint.
`balance_infos` must be an array. Each supported CNY/USD component maps `total_balance` as an exact
Decimal amount, with optional `granted_balance` as the gift portion. `topped_up_balance` is not added
again: total_balance already includes it. Reported zero stays zero even if is_available is false.

Monetary fields are strict decimal strings; malformed totals fail only their currency. A malformed
gift field preserves the valid total with a component warning. Duplicate entries for one currency are
rejected rather than chosen or added; prior matching currency values can remain stale through the
engine. No cross-currency addition/ranking. Negative/debt balances and new currency codes need further
contract evidence before support. The timestamp of an undated live response is receipt time.

Settings exposes Add key/Update key, backed by the engine and the app-owned Keychain service.
CLI supports `account add deepseek --stdin` and `account key <id> --stdin`, with optional `--json`.
No key argument or echoing terminal entry is accepted. Config is saved before creating a new secret;
a failed secret write leaves a recoverable account row. Replacement preserves its ID/settings.
Removal drops account metadata and deletes its own key, retaining a visible retry marker on failure.
Startup and Privacy settings retry pending cleanup. No external tool key is written or deleted.
Registration enables no optional source. Accounts → Optional sources can enable the process variable.
Only the environment inherited by the app is read; changing a shell export cannot alter an already
running app session. Empty, oversized or whitespace/control-bearing keys produce an explicit source
error. The key is sent only to api.deepseek.com and never copied into configuration/snapshots. A local
source identity persists through key rotation; no provider billing ID is inferred from the key.
Disabling this source cancels its work and removes cached credentials without disabling manual
accounts. Removal stays suppressed until Check source explicitly reconnects. The opt-in is persisted,
and scoped reconciliation does not re-read unrelated manual keys in ordinary source checks.
CLI exposes the same flow as `source enable|disable|check deepseek-env [--json]`; `source list` is
read-only. A healthy manual account cannot make a missing environment-source check succeed. Keys
remain in the inherited environment rather than arguments or saved metadata.

## Evidence

- Official [Get User Balance](https://api-docs.deepseek.com/api/get-user-balance/), retrieved 2026-09-07. The rendered documentation lists CNY/USD and string-valued total/granted/topped-up balances.
- Last capability review: 2026-09-07
- Last live verified: —
- Verified account/region/metric scope: none.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.

## Global Claude settings source

`deepseek-claude-settings` is an independent, initially disabled source. On startup or Check source,
read at most 1 MiB from the regular file `~/.claude/settings.json`. Decode only the relevant literal
env fields. The base URL must be HTTPS api.deepseek.com, default/443 port, `/anthropic` with an optional
trailing slash, and no credentials/query/fragment. Unknown proxy/provider URLs yield no DeepSeek
account. Only after routing matches is ANTHROPIC_AUTH_TOKEN extracted and validated. Dollar/backtick/
backslash placeholders are not accepted; no helper, hook or shell expression is executed.

Source metadata records the configuration source ID, file path and field name, never the key. A
corrupt matching-source file remains diagnosable without erasing independent source results. Scoped
checks preserve the other optional/manual sources. File rotation keeps the local account identity;
source bytes are never changed. The enabled settings source is checked locally every five minutes and on wake/network recovery,
without rereading other optional/manual sources during ordinary checks. Project/managed overrides
and other credential aliases remain open. This describes the global declaration,
not proof of the endpoint actually selected by a particular running Claude session.

Primary references reviewed 2026-09-07:
- [Claude Code settings](https://code.claude.com/docs/en/settings): global settings and env structure.
- [DeepSeek Claude Code integration](https://api-docs.deepseek.com/zh-cn/quick_start/agent_integrations/claude_code/):
  Anthropic base URL and authentication variable.
- [DeepSeek Anthropic compatibility](https://api-docs.deepseek.com/guides/anthropic_api/): direct endpoint.

Five offline tests cover opt-in-before-read, unrelated settings, bad/proxy routes, placeholder/malformed
input, bounded regular-file reads and scoped key rotation with unchanged source bytes. No user's
actual settings file or real key was read for this implementation verification.
