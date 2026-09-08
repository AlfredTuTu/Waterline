# Providers

One file per provider records its credential sources, candidate endpoints, supported metric contract
and verification evidence. Candidate notes are not implemented support. `official` means an endpoint
is documented by the vendor; `community` means third-party observation. Neither label proves a live
check, all account types, or the completeness of the proposed mapping.

As of 2026-09-07, the table separates current implementation evidence from target scope. Provider
contracts carry reviewed endpoints, tested account scopes and dates. A registered adapter does not
establish live support; unreviewed candidate notes remain provisional.

| Provider | `Provider` case | Implementation / evidence | Candidate metrics | Evidence classification in planning notes | Credential source | Target |
|---|---|---|---|---|---|---|
| [Claude Code](claude-code.md) | `claudeCode` | Registered; Pro 5h/7d live 2026-09-07; renewed source permission can still be required | windows | community | Named Keychain item or credentials file | v0.1 |
| [Codex](codex.md) | `codex` | Registered; live quota 2026-09-07, one account | windows | community / local records | Tool auth file; local usage records | v0.1 |
| [Cursor](cursor.md) | `cursor` | Registered; one Pro summary/Grok Bot live 2026-09-07 | separate usage pools and reported caps | community | Read-only tool SQLite | v0.1 |
| [Grok / SuperGrok](grok.md) | `grok` | Consumer OIDC adapter; direct weekly endpoint and native discovery/refresh live 2026-09-08 | subscription windows | official client source | Grok Build auth file | priority |
| [xAI API](xai.md) | `xai` | Registered posted-ledger/team flow; offline only | billing usage and/or balance; allowance denominator unverified | official candidate | Manual management key, account/team scope | v0.1 |
| [Zhipu GLM](zhipu.md) | `zhipu` | Registered personal CN/global; offline only | windows / named quotas | community | Opted-in named config keys or manual key | v0.2 |
| [Kimi Code](kimi-code.md) | `kimiCode` | Registered manual key; offline only | windows | community | Opted-in named config keys or manual key | v0.2 |
| [Moonshot](moonshot.md) | `moonshot` | Registered CN/global; CN manual CLI live 2026-09-07, app Keychain restart access pending | balance | official candidate | Regional config/manual key | v0.2 |
| [MiniMax](minimax.md) | `minimax` | Registered regional Subscription Key; offline only | coding-plan quotas; balance route unverified | community | Regional config/manual key | v0.2 |
| [DeepSeek](deepseek.md) | `deepseek` | Registered manual key; offline only | balance | official candidate | Config/manual key | v0.2 |
| [Antigravity](antigravity.md) | `antigravity` | Registered opt-in running CLI; real engine/restore 2026-09-08; native UI pending | per-model/group quotas | community | Documented account storage to verify | v0.3 |
| [Qwen / Bailian](qwen.md) | `qwen` | Reviewed 2026-09-08; console-query candidate found, key auth unverified | OAuth discontinued; plan/account scopes separate | primary capability review | Opted-in config source | v0.3 |

Keep Tier 1 tool login state on by default; Tier 2 config scanning off per source; Tier 3 manual entry
user initiated. A configured base URL helps identify a region or gateway; it is never permission to
send a key to an arbitrary host. Do not merge accounts solely because credential names form a fallback chain.

## Support and evidence states

- **Planned**: candidate only; may lack a usable endpoint or credential path.
- **Implemented**: registered adapter and offline contract tests; live scope is not yet established.
- **Live verified**: dated live evidence for the declared account, region and metric scope, alongside tests.
- **Unavailable / unsupported**: explain whether this is a temporary endpoint failure or no verified
  supported capability. Date and link the capability review; do not assert that no API exists without evidence.

Each provider file must record source links (and commit/version for community code), date inspected,
request method/path, exact HTTPS hosts, region and key kind, required scopes/identifiers, and supported
account/plan kinds. The mapping must name required/optional field paths, units, currency source,
formulas, timestamp meanings, overage policy, omission/partial-failure behaviour, errors and limitations.
For a currency inferred from a documented endpoint contract, cite that contract; never assume it merely
from an account's locale. Billing spend without a real allowance denominator is not a usage fraction.

## Adding or repairing a provider

1. Validate the candidate sources and capability before promising metrics. Use vendor documentation
   where available and linked community evidence for undocumented routes. Record what remains unknown.
2. Define identity, region and credential discovery through the injected environment. Background
   Keychain reads are permitted only with interaction disabled; return a connection reason if blocked.
3. Implement `Providers/<Name>/<Name>Adapter.swift` and register it. Use the shared HTTP boundary;
   HTTPS, account-specific endpoint selection and redirects follow `ARCHITECTURE.md`.
4. Map supported fields. Ignore unrelated additions; incompatible required fields become
   `schemaChanged` naming their path. Preserve independent valid components and their timestamps.
   Missing optional values do not require fabricated zeros, resets or plan names.
5. Test discovery with synthetic files/Keychain and fetching with a stub client. Include good data,
   auth/permission failure, rate limit, incompatible schema, optional omissions and extra fields;
   include partial results and regional selection where applicable.
6. When live checking is authorised and the CLI supports it, close the app to release its writer lock
   and run `waterline refresh --provider <p> --json`. Record the actual metrics and observation age.
   A missing live account is an evidence gap; never set the live date based only on fixture tests.
7. If raw capture is needed and authorised, follow the next section and the fixtures README. Complete
   the response mapping and evidence status. Run `make verify`.

## Raw capture and fixtures

`--dump <dir>` is a planned diagnostic flag, not implemented by the scaffold CLI. When implemented,
it requires an explicit user-selected directory and capture authorisation (the task may already provide
both). A live-refresh request alone does not imply raw export. State that raw responses may contain
private account information. Capture response bodies byte-for-byte; never request headers or credentials
from local auth files. If a response itself contains secrets, the raw file is sensitive and must not be shared.

Raw capture is a narrow exception to normal secret-free disk output: create owner-only directories/files,
use the project's ignored `local/` directory or another explicitly selected non-shared location, and
never include raw data in logs, commits or delivery attachments. Do not overwrite an existing capture.
After a redacted fixture is reviewed, remove the task's temporary raw captures unless retention was
explicitly requested. This does not authorise deleting unrelated captures.

Fixtures are reviewed before entering `Tests/WaterlineKitTests/Fixtures/`. Real happy-path samples are
preferred; generated error/schema mutations are allowed when clearly labelled. Do not provoke a live
auth failure or exhaust quota to obtain a fixture. Record response status, relevant safe headers, origin
and any transformation; the fixture date is not a live-verification date. See the fixtures README.

## Verification dates and drift

`Last live verified` is the day an authorised real-account check established the recorded mapping for
its stated scope. `Last capability review` is a dated review of linked documentation/source, including
unsupported capabilities. A local wording edit changes neither date.

Frozen fixtures test known shapes; they do not detect changes on a remote service by themselves.
Live failure or an authorised recheck can reveal drift. Reproduce it with a reviewed fixture, update the
mapping/tests and record new evidence. Planned or unsupported providers retain an honest reason and
review date rather than a fabricated live date.
