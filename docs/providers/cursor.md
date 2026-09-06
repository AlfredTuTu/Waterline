# Cursor

Kind: window (billing-cycle request usage; plan). Doc status: community, the most fragile of the set. Milestone: v0.1.

## Credentials

| Tier | Location | Notes |
|---|---|---|
| 1 | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`, table `ItemTable(key, value)`, keys `cursorAuth/accessToken`, `cursorAuth/refreshToken`, `cursorAuth/cachedEmail` | SQLite; open read-only with the system `SQLite3` module (`SQLITE_OPEN_READONLY`), copy first if the file is locked. The user id is the JWT `sub` claim after `auth0|`. |

## Endpoint candidates

| Purpose | Request | Source | Status |
|---|---|---|---|
| usage | `GET https://cursor.com/api/usage?user=<userId>` with cookie `WorkosCursorSessionToken=<userId>::<accessToken>` | CodexBar, community scripts | community, unverified |
| usage summary (newer) | `GET https://cursor.com/api/dashboard/get-usage-summary` (same cookie) | CodexBar | community, unverified |

## Allowed hosts

`cursor.com`, `www.cursor.com`

## Response mapping

_To be filled by the adapter PR._

## Pitfalls

- Cursor changes these endpoints often; keep every observed shape as a fixture and prefer
  `schemaChanged` over a guess.

Last verified: —
