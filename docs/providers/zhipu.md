# Zhipu GLM (Z.ai / bigmodel.cn)

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
No balance endpoint exists for top-up use.

## Allowed hosts

`open.bigmodel.cn`, `api.z.ai`

## Response mapping

_To be filled by the adapter PR._

Last verified: —
