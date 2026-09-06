# Claude Code

Kind: window (5-hour and 7-day rolling windows; plan tier). Doc status: community. Milestone: v0.1.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 1 | Keychain generic password, service `Claude Code-credentials`, account = macOS user name | Data is JSON: `claudeAiOauth { accessToken, refreshToken, expiresAt, scopes, subscriptionType }`. Reading the data triggers the ACL prompt the first time; attributes can be listed without it. |
| 1 | `~/.claude/.credentials.json` | Same JSON, used when the Keychain item is absent. |
| 3 | — | No manual entry: an OAuth token cannot be typed. |

Claude Code refreshes its own token when it runs; Waterline never refreshes it. An expired token is
`unavailable(.unauthorized)` until Claude Code has been used again and the item is re-read on connect.

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| usage windows | `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer <accessToken>`, `anthropic-beta: oauth-2025-04-20` | CodexBar, claude-token-monitor | community, unverified |

Response shape observed by those tools: `five_hour { utilization (0–100), resets_at }`,
`seven_day { … }`, optionally per-model seven-day objects. `subscriptionType` from the credential
gives the plan label.

## Allowed hosts

`api.anthropic.com`

## Response mapping

_To be filled by the adapter PR._

## Pitfalls

- Never read the Keychain data in the background; list attributes to know the account exists and
  report `keychainLocked` until Connect.
- An ad-hoc signed development build changes its code signature on every rebuild, so the Keychain ACL
  prompt returns after each rebuild; that is expected during development.

Last verified: —
