# Zhipu GLM (Z.ai / bigmodel.cn)

Implementation: registered CN/global personal Coding Plan manual-key flow with offline tests. No live quota verification yet.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Kind: window (Coding Plan: token window, time window, MCP monthly quota; plan level). Doc status: community. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `ZAI_API_KEY` → `ZHIPU_API_KEY` → `BIGMODEL_API_KEY` in `~/.claude/settings.json` `env` or shell rc files | Users route Claude Code to GLM with `ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic` (CN) or `https://api.z.ai/api/anthropic` (intl); the base URL decides the region. |
| 3 | manual | |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| quota | `GET https://open.bigmodel.cn/api/monitor/usage/quota/limit` (CN) or `https://api.z.ai/api/monitor/usage/quota/limit` (intl), `Authorization: Bearer <key>` | claude-token-monitor, glm-coding-plan-statusline | community, unverified |

Observed shape: `data.limits[] { type: TOKENS_LIMIT | TIME_LIMIT, percentage, usage, limit, nextResetTime }`, `data.level`.
No top-up balance endpoint is recorded in these planning notes; capability is unverified, not evidence of global absence.

## Allowed hosts

`open.bigmodel.cn`, `api.z.ai`

## Response mapping

Explicit `cn` or `global` account region selects exactly one host. The request is GET with Bearer
credentials and no endpoint overrides. The initial flow is personal Coding Plan usage; team selectors,
organization/project headers, monetary balances and model-usage statistics are not implemented.

Require success=true, code=200 and data.limits. TOKENS_LIMIT and CREDIT_LIMIT produce Coding Plan
windows; TIME_LIMIT is a separate MCP component. Unknown limit types are ignored. Percentages must be
finite 0–100. Positive usage (the allowance) and currentValue, or usage minus remaining, permit a
deterministic fraction that takes precedence over the percentage field. Counts are nonnegative quota
units, never currency. Unit codes 1/3/5/6 describe day/hour/minute/week durations; unknown durations do
not invent a period. MCP is labelled MCP rather than guessing a monthly reset from a legacy marker.
nextResetTime is epoch milliseconds; missing resets stay absent. Malformed known components retain
previous readings with their original times, and other components remain usable.

## Evidence

- Official [Coding Plan FAQ](https://docs.z.ai/devpack/faq), inspected 2026-09-07, establishes separate 5-hour/weekly plan limits and distinct balance semantics.
- Protocol evidence: [CodexBar z.ai notes](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/docs/zai.md) and [zai.js](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Resources/Plugins/zai.js), commit `c15f736ef42158b830b47db1970ea91886e30e85`, inspected 2026-09-07. Used for endpoint/field evidence, not copied implementation.
- Last capability review: 2026-09-07
- Last live verified: —
- Verified account/region/metric scope: none.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.
