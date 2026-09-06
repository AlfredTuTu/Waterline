# Fixtures

One folder per provider (`claude-code/`, `codex/`, …) holding real responses captured with
`waterline refresh --provider <p> --json --dump <dir>`, then redacted:

- replace every token, key, cookie, account id and e-mail with `REDACTED`;
- keep numbers, timestamps and structure exactly as received — the parser is tested against the shape;
- name files by what they show: `windows-ok.json`, `rate-limited-429.json`, `schema-2026-09.json`.

`Scripts/audit.sh` fails the build if anything secret-shaped survives here.
