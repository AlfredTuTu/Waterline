# Antigravity

Implementation: registered, explicit opt-in for an already-running signed CLI. Capability review: 2026-09-08. Live engine verification: 2026-09-08; native UI pending unlock.
The official CLI exposes quota information, but Waterline has not yet verified a complete authenticated
transport/account flow. A running process or model list alone is not quota evidence.

## Verified discovery findings

- Current official docs describe interactive `/usage` (alias `/quota`) as a backend quota/configuration
  refresh followed by a TUI panel. `/credits` and subscription settings are separate surfaces.
- Local `/Users/tzc/.local/bin/agy --help` was inspected read-only on 2026-09-07. It lists model and
  agent commands and prompt/headless modes, but no standalone machine-readable usage subcommand.
  Do not turn a guessed `--print` prompt into an inference call to check quota.
- A bounded executable-name process inventory found no running `agy` or Antigravity IDE language
  server at that check. This is a time-specific observation, not an installed-account diagnosis.
- The old OpenCode `antigravity-accounts.json` lead is not yet a verified credential schema here.
  Do not treat a plugin config path as Antigravity IDE's native account store.

## Candidate integration paths

The official [CLI reference](https://www.antigravity.google/docs/cli/reference/) and
[SDK overview](https://www.antigravity.google/docs/sdk/overview/) were additionally reviewed on
2026-09-07. The reference describes `/usage` as a TUI slash command, not a documented standalone
JSON quota command. The SDK overview instead initializes agents with a Gemini API key or Vertex
project/location credentials; it does not establish a read-only query for the CLI user's subscription
quota. Do not substitute SDK agent/chat execution or cloud billing identity for subscription monitoring.
No SDK package was installed, no agent conversation was started, and no new credentials were read.

| Path | Inspected evidence | Required work before registration |
|---|---|---|
| Existing local IDE/CLI status service | Community implementation reads HTTPS loopback user status and newer quota summaries from the running tool. | Bind discovered ports to the exact verified executable/process owner, validate account identity, define narrow TLS trust and CSRF handling, handle process replacement and timeout, then verify the response against the tool's UI. |
| Direct Google OAuth | Community implementation uses `cloudcode-pa.googleapis.com` with OAuth access tokens, project discovery and quota queries. | Establish an owner-approved native credential source and account/project identity; token expiry/refresh and permissions must be complete. No external credential files may be changed. |
| Offline local snapshots | Community implementation also reads CLI/IDE stored observations. | Verify schema/account provenance and original observation times; stale snapshots must not become newly observed live usage. |

The first implementation should investigate the existing-process status path. It avoids treating
another monitoring app's OAuth store as the tool's own login. This is a development direction, not a
verified transport. Do not use blanket certificate acceptance, arbitrary localhost ports, redirect
following or raw process-argument logging. Any local transport exception needs an explicit narrow
contract and tests; the ordinary provider HTTP client's HTTPS/host protections remain intact.

Starting a managed CLI solely for status needs an explicit user-facing lifecycle choice and bounded
process cleanup. No automatic tool installation, shell/config change, project onboarding, credit
purchase, or inference is part of a quota refresh.

## Candidate cloud requests

The inspected community source names these routes under `https://cloudcode-pa.googleapis.com`:

- `POST /v1internal:loadCodeAssist`: account/project context.
- `POST /v1internal:fetchAvailableModels`: model availability with optional quota metadata.
- `POST /v1internal:retrieveUserQuota`: quota buckets where permitted.

Its separate `onboardUser` operation changes onboarding state and must not be imported into a
read-only fetch by default. Its credential store at `.codexbar/antigravity/oauth_creds.json` belongs to
CodexBar, not the native Antigravity app. No host has been added to Waterline's registry yet.

## Candidate mapping boundaries

Local `userStatus.cascadeModelConfigData.clientModelConfigs` contains model identity, label and
optional `quotaInfo.remainingFraction`/`resetTime`. Newer quota summaries contain groups and stable
bucket IDs, disabled state and remaining fractions. Cloud models and quota buckets are separate
response schemas; never assume one wrapper for all three.

For a verified remaining fraction, used fraction is deterministically `1 - remaining`, only for finite
0–1 input. Missing quota metadata means unavailable, not a full allowance. Preserve stable model or
bucket IDs, independently failed components and supplied reset times. Plan names never generate a
5h/weekly window. Group/model aliases and shared quotas need evidence before deduplication.

The reference cloud implementation explicitly verifies suspicious all-full model metadata with a
quota endpoint. Waterline must establish which response actually reports account quota before showing
all models at zero usage. Credits and model-quota fractions require different units and labels.

## Evidence inspected

- [Official model quotas command](https://www.antigravity.google/docs/cli/commands/usage)
- [Official AI credits and quota documentation](https://www.antigravity.google/docs/cli/credits/)
- Community source pinned to CodexBar commit `c15f736ef42158b830b47db1970ea91886e30e85`:
  [response models](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Antigravity/AntigravityStatusProbe%2BResponseModels.swift),
  [quota summary parser](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Antigravity/AntigravityQuotaSummaryParser.swift),
  [remote fetcher](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Antigravity/AntigravityRemoteUsageFetcher.swift),
  [CLI session](https://github.com/steipete/CodexBar/blob/c15f736ef42158b830b47db1970ea91886e30e85/Sources/CodexBarCore/Providers/Antigravity/AntigravityCLISession.swift).

No reviewed redacted live response, fixture mapping, native account match or successful Waterline
query exists yet. Those remain required before claiming implemented or live support.

## Official status-line schema — additional review 2026-09-07

The [official status-line customization guide](https://www.antigravity.google/docs/cli/statusline/)
now provides a direct documented quota payload. It describes a user-configured command in
`~/.gemini/antigravity-cli/settings.json` receiving state JSON on stdin. The payload includes
`product`, `email`, optional `plan_tier`, and a `quota` map keyed by model/bucket ID. Each quota
may contain `remaining_fraction`, absolute `reset_time` and relative `reset_in_seconds`.
The `context_window` percentage is conversation context usage, not account quota.

`AntigravityStatusline.parse` now validates this standalone format against labelled synthetic tests.
It preserves missing fractions and resets, validates finite 0–1 fractions, converts remaining to used,
retains bucket IDs and ignores unrelated working-directory/transcript fields. It deliberately returns
a distinct DTO rather than a fresh canonical UsageWindow. Relative reset seconds are not turned into
an absolute date using Waterline's receipt time.

The documented payload has no quota observation timestamp, and callbacks occur on agent-state changes.
Receiving an identical payload is not evidence that quota was freshly queried. Therefore this parser
is **not** registered as an adapter and does not claim a working account flow. A user-initiated bridge,
explicit source opt-in, capture/persistence ownership, original freshness treatment, and native/live
verification remain necessary. No status-line settings, hooks or commands were installed or changed.

A current executable-name/UID inventory again found no running Antigravity/agy language-server
process. No localhost service or cloud quota endpoint was queried, and no process arguments or
credentials were printed. The installed app and CLI alone do not establish a running quota source.

## Native official CLI usage observation — 2026-09-07

A bounded interactive CLI 1.1.27 session in a dedicated empty temporary directory ran
only `/usage`; no model prompt was submitted. The existing signed-in Google AI Pro
account showed Gemini Flash/Pro sharing weekly and five-hour limits: 99.33% and 97.70%
remaining, respectively. Claude Opus/Sonnet/GPT-OSS shared a separate pair, each 100%
remaining. The CLI displayed reset countdowns only for the Gemini group. No absolute
reset timestamp is inferred from rounded display text. The temporary session exited 0.
Sanitized evidence: `build/verification/antigravity-cli-usage-live.json`; email omitted.

This verifies real quota availability in the official CLI, not Waterline transport.
A future adapter must preserve group-level shared quota identity and both cadences;
rendering one duplicate allowance per member model would be wrong. The prior statement
that no native quota observation existed is superseded only for this CLI observation.
The adapter remains unregistered until authenticated transport, freshness, error handling
and the complete persisted account flow are verified.

## Structured loopback verification — 2026-09-07

A temporary CLI-owned HTTPS listener was verified by exact executable path, UID and
PID-owned socket inventory. Its public self-signed certificate includes localhost and
127.0.0.1 SANs. The probe used that exact leaf as a request-local trust anchor with
hostname validation enabled; no blanket trust delegate, `-k`, credentials, redirects
or system trust-store changes were used. The adjacent listener rejected TLS and was
not queried as a quota endpoint.

`POST /exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary` with
JSON `{ "forceRefresh": true }`, Content-Type application/json and
Connect-Protocol-Version 1 returned 200. No Authorization or CSRF header was required
for this CLI-owned endpoint. This is not permission to omit CSRF on IDE endpoints.

Observed `response.groups[].buckets[]` fields: bucketId, displayName, window,
remainingFraction and resetTime. Actual window values were `weekly` and `5h`. Gemini
remaining fractions 0.99333555/0.9770333 matched the rounded CLI display; Claude/GPT
fractions were 1/1. Unlike the TUI, the structured response supplied absolute resets
for unused buckets as well. Retain server-supplied times rather than inventing absent
TUI resets. Normalized quota-only evidence: `antigravity-structured-live.json`.

Waterline adapter integration remains unfinished: opt-in lifecycle, process identity
revalidation, narrow session trust, account identity, partial-schema failures, cleanup
and refresh scheduling need native implementation and tests. The successful standalone
probe establishes a concrete transport candidate, not shipped support.

Quota-summary parser implemented (not registered): AntigravityQuotaSummary.parse validates
the observed envelope and maps each bucket exactly once, preserving reported group and
bucket identity. It recognizes explicit 5h/weekly durations; unknown cadence stays nil.
Missing values stay missing, malformed siblings are isolated, and conflicting duplicates
are invalidated. Parsing never sets observation freshness. Six offline tests include
wrong types, zero/null, future cadence, envelope limits and duplicate conflicts.
Transport/account/refresh integration remains open.

## Registered engine integration — 2026-09-08

`antigravity-cli` is an explicit optional source, off by default. It queries only an
already-running signed CLI; it does not launch the CLI, read tokens or use a fabricated
Secret. LocalProviderAdapter supplies a separate local-service fetch route, leaving
ordinary remote HTTP restrictions unchanged. Configuration schema 2 and snapshot schema
10 represent the local-service source; older configuration/snapshot files are preserved
as migration backups before replacement.

GetUserStatus email establishes a case-normalized, provider-domain-separated SHA-256
identity. Only that opaque key is kept in the adapter identity DTO; PID/port/start time
are transport leases, not account IDs. Fetch checks the account before and after quota
retrieval. Background source checks can discover an account change without overwriting
the prior account. CLI absence preserves old data with an actionable CLI-login message.

Offline engine tests cover opt-in, no secret writes, fetch, restart, stable ID and notch
selection, disable and account switching. A real CLI against isolated Waterline state
then verified one account, four quota windows, fresh refresh after engine recreation,
stable ID and restored notch selection. Evidence: `antigravity-engine-live.json`. This
is real backend/persistence evidence, not mocked data and not native UI verification.
Mac lock prevented native source-toggle acceptance. The running app exposes the new
source but no production account was added by the isolated probe.

## Native owner-account verification — 2026-09-08

The earlier Mac-lock limitation was subsequently resolved. The native optional
source was enabled for an already-running signed-in CLI, and the configured
account returned fresh readings. Native overview displayed all nine configured
accounts; Antigravity detail showed Gemini and Claude/GPT groups with 5h on the
left and 7d on the right. The account persisted in the installed application.
Evidence: ignored `build/verification/order-and-cadence-native.json` and the
owner-priority checkpoint in ACCEPTANCE.md. This establishes one real account
and this display scope, not all plans or inactive-CLI availability. The app still
does not start the CLI, extract its token or invent data while it is absent.
