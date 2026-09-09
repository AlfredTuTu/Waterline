# xAI / Grok

Implementation: registered Management Key + Team ID flow for posted prepaid credit, with offline tests. No live verification yet.
See [the provider contract rules](README.md) for evidence, mapping and live-check requirements.

Candidate metrics: billing usage and/or prepaid balance; quota-window support is not established. Doc status: official. Milestone: v0.1.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 3 | `waterline account add xai` → this app's Keychain | A **management** API key from the xAI console; inference keys cannot read billing. Team id may be required. |

## Implemented endpoint

`GET https://management-api.x.ai/v1/billing/teams/{team_id}/prepaid/balance`, Bearer Management key.
Team ID is mandatory, persisted with the account, and validated before storage/path construction.
No inference, top-up, payment-method or spending-limit mutation endpoint is implemented.

## Allowed hosts

`management-api.x.ai`

## Response mapping

Require `total.val` as a signed integer string in USD cents. The prepaid ledger uses the opposite
sign to credit availability (the official top-up example records a purchase as a negative change):
posted prepaid credit = -total.val / 100. Missing/malformed totals are errors, never zero.

The value is labelled **Posted prepaid credit**, not live available credit. Community live evidence
reports that unposted current-cycle spending can make it higher than Console availability. A distinct
balance basis prevents available-balance health/headline selection and depletion estimates, including
mixing posted observations into later available-balance history. Snapshot schema 6 carries this basis.
Actual current available credit, spend analytics and consumer Grok/SuperGrok quota remain outside this
initial implemented scope and are not claimed verified. HTTP 403 is a permission error, not a network
failure. CLI entry accepts `account add xai --team <id> --stdin`; native entry requires the Team ID.

## Pitfalls

- Verify key kind, required permissions and team scope; explain the management-key requirement in
  account entry. Never treat billing spend as percent used without a verified allowance denominator.
- Missing quota support must not suppress an independently valid balance; record the actually
  supported scope before selecting a usage kind.

## Evidence

- Official [Management guide](https://docs.x.ai/developers/management-api-guide) and [Billing REST reference](https://docs.x.ai/developers/rest-api-reference/management/billing), inspected 2026-09-07.
- Sign/posted-ledger interpretation: official purchase examples plus [CodexBar xAI notes](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/docs/xai.md), commit `c15f736ef42158b830b47db1970ea91886e30e85`. This project's own live comparison remains pending.
- Last capability review: 2026-09-07
- Last live verified: —
- Verified account/region/metric scope: none.

Complete field requirements, units, currency source, timestamps, partial-result behaviour and safe
error mapping before marking this provider implemented or live verified.
