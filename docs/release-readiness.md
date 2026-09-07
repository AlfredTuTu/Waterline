# Release readiness — 2026-09-08

This is a current-state audit, not release approval.

| Requirement | Observed state | Remaining work |
|---|---|---|
| Repository | AlfredTuTu/Waterline is private; default branch main | Review publishable source before changing visibility |
| CI | Latest successful run covers base 504cd08f0a94f8a62fe16f1818206044894d1056 | Integration branch needs review/PR and CI for its own commit |
| Local gate | 284 tests, strict formatting, whitespace and audit pass | Re-run for subsequent changes |
| Signing | No Developer ID Application or Apple Development identity found in local identity inventory | Intended release signing identity must be available |
| Notarization | Preparation script and fail-closed preflight implemented; no Apple submission performed | Signed stable build, existing notarytool profile, submission/stapling and actual validation |
| Version | 0.1.0-dev | Stable version only after applicable release acceptance |
| Native acceptance | Some real flows verified; Mac lock currently prevents remaining source-toggle/UI checks | Finish on unlocked supported macOS/display configurations |
| Providers | Per-provider scope is in docs/providers/README.md | Remaining real account/region checks and Qwen capability gap stay open |
| Architecture | arm64 development bundle; Intel cross-build and Rosetta CLI startup succeed, full Intel tests blocked by ARM helper | Intel-capable test runner/hardware and native GUI acceptance |
| Distribution | Development DMG only | Signed/notarized DMG, clean installation, Homebrew cask and signed update/appcast flow |

`Scripts/notarize-app.sh --check` does not upload. Its explicit three-argument form
uses an existing Keychain profile, stages the source app, preserves submission results,
and writes a separate accepted/stapled app. Full distribution and clean-install checks
remain mandatory afterward. No keys, credentials or signing identities are generated
or purchased by this script.
