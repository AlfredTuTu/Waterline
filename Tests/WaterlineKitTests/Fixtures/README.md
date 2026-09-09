# Fixtures

One folder per provider (`claude-code/`, `codex/`, etc.). Prefer redacted real happy-path responses.
Synthetic auth/rate-limit errors and deliberately changed schemas are allowed when marked as such;
never provoke a live failure or consume quota just to produce test data. Live capture uses the planned
`waterline refresh --provider <p> --json --dump <dir>` only when implemented and explicitly authorised.
Follow `docs/providers/README.md` for raw-file permissions, storage and cleanup.

For each fixture, record its origin (captured, synthetic or mutated), source date/version when known,
HTTP status and safe headers relevant to parsing (for example `Retry-After`), expected result and
transformations. Put this metadata in the provider folder's README or a companion JSON file.

- Remove keys, cookies, tokens, emails, account/team identifiers, local usernames/paths, request IDs
  and other private identifiers. Use stable fictional replacements with valid types/relationships
  where the parser needs them; a numeric identity must not become the string `REDACTED`.
- Keep metric values, units, timestamps and structure where safe. If any are sensitive, substitute
  consistent fictional values and record the transformation; do not describe an edited sample as raw.
- Include optional omissions, unrelated extra fields and independent component failures where relevant.
  Changed-schema samples are deliberately mutated test inputs unless actually observed otherwise.
- Use descriptive names such as `windows-ok.json`, `rate-limited-429.json`, `missing-reset.json`.
  Never derive names from real private account identifiers.
- Review the entire fixture and its metadata before committing. `Scripts/audit.sh` catches selected
  secret-shaped strings; it cannot establish complete redaction or detect every credential format.

Automated tests use these files through a stub client and a synthetic environment. No live services,
real Keychain access or network sockets. A frozen fixture proves behaviour for that shape, not that the
provider still returns it today. Fixture modification dates are not live-verification evidence.
