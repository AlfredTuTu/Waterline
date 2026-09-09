# MiniMax

Implementation: registered CN/global Subscription Key flow and offline Token Plan quota tests. No live quota verification yet.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Candidate kind: Coding Plan quotas per model; platform balance has no candidate route recorded yet. Doc status: community. Milestone: v0.2.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 2 | `MINIMAX_API_KEY` → `MINIMAX_CN_API_KEY` → `MINIMAX_INTL_API_KEY` in config files | CN `api.minimaxi.com`, international `api.minimax.io`. |
| 3 | manual | |

## Current endpoint contract

Official current FAQs use `GET https://www.minimaxi.com/v1/token_plan/remains` (CN) and
`GET https://www.minimax.io/v1/token_plan/remains` (global), with a regional Subscription Key as Bearer.
These replace the initial unverified coding_plan/remains candidate in the implemented path.
No sibling-region, browser-cookie or pay-as-you-go fallback is attempted.

## Allowed hosts

`www.minimaxi.com`, `www.minimax.io`

## Response mapping

Support top-level or data-wrapped model_remains and base_resp status. Each model's interval and weekly
lane is independent. For current responses, remaining_percent gives used = 100 - remaining_percent;
zero placeholder counts do not create an invented absolute allowance. Legacy usage_count means
remaining, so used = total_count - usage_count with a positive denominator. Do not label these quota
units as fixed prompts or money. Unquantified status-3/100%-remaining/zero-or-absent-total lanes carry
no percentage or count rather than pretending zero usage or unlimited availability.

End times accept the observed contemporary epoch-second and epoch-millisecond formats. Missing end
times stay missing; ambiguous remains_time is not used to invent a reset. Invalid lanes preserve
successful siblings. Reported model/bucket names remain separate and are never summed. Purchased
Credits, cash balances, browser-session history and legacy cookie-only endpoint paths remain open.

## Evidence

- Official [global FAQ](https://platform.minimax.io/docs/token-plan/faq) and [CN FAQ](https://platform.minimaxi.com/docs/token-plan/faq), inspected 2026-09-07: Subscription Keys, separate PAYG keys, current endpoints and quota windows.
- Response evidence: CodexBar MiniMaxModelRemains.swift, MiniMaxUsageFetcher.swift and MiniMaxCurrentTokenPlanResponseTests.swift at [commit c15f736](https://github.com/steipete/CodexBar/tree/c15f736ef42158b830b47db1970ea91886e30e85/app/Sources/CodexBarCore/Providers/MiniMax), inspected 2026-09-07. Used as protocol evidence, not copied implementation.
- Last capability review: 2026-09-07
- Last live verified: —
- Verified account/region/metric scope: none.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.

## Real CN attempt — 2026-09-08

The owner-authorized OpenCode minimax-cn key import created a distinct CN account.
The documented Token Plan request returned HTTP 200 with base_resp.status_code
2062; the observed provider message reported no active Token Plan subscription.
This is not a successful quota response and does not establish that the key is
invalid for PAYG inference. PAYG balance and Token Plan quota remain separate
capabilities; no PAYG balance is inferred from this failure. Native access to the
CLI-created Keychain item separately required permission. Evidence: ignored
`build/verification/opencode-regional-queries.json`. Imported keys are one-time
Waterline-owned entries; later OpenCode key changes are not automatically synced.
