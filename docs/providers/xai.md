# xAI / Grok

Kind: both (billing usage per period and prepaid balance). Doc status: official. Milestone: v0.1.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 3 | `waterline account add xai` → this app's Keychain | A **management** API key from the xAI console; inference keys cannot read billing. Team id may be required. |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| billing / balance | Management API under `https://management-api.x.ai/` — consult https://docs.x.ai for the current billing and usage routes | xAI docs | official, verify route names |

## Allowed hosts

`management-api.x.ai`

## Response mapping

_To be filled by the adapter PR._

## Pitfalls

- Two key kinds exist; explain in the add-account copy that the management key is the one needed.

Last verified: —
