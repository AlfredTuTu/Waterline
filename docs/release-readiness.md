# Waterline 0.1.0 release readiness

The owner explicitly approved an unnotarized first Release with macOS's normal
Privacy & Security approval flow. No Gatekeeper-disable or quarantine-removal
workaround is part of installation. Developer ID and notarization remain deferred,
not falsely passed. The repository remains private.

## Reproducible candidate

```sh
make verify
CONFIGURATION=release make app
DEVELOPER_DIR=/Applications/Xcode.app bash Scripts/check-distribution.sh build/Waterline.app --adhoc-release
DEVELOPER_DIR=/Applications/Xcode.app bash Scripts/build-dmg.sh --adhoc-release
```

The explicit ad-hoc mode checks sealed-resource/code integrity, the production
bundle ID, stable version, deployment targets, matching app/CLI architectures,
icons/licenses and disabled automatic updates. It reports the omitted notarization
and trust assessment rather than claiming they passed. The default `complete`
and `--pre-notarization` modes retain their Developer ID requirements.

## Release evidence to complete

- Final exact-commit local and GitHub `make verify` pass.
- Final Release installation and native UI checks, including ordering and language.
- Claude CLI local delivery, account isolation, cached-data handling and server fallback.
- Final binary performance sample under the acceptance protocol.
- DMG verify, read-only mount, matching copied bundle and installation instructions.
- SHA256 checksum and GitHub release attachment verification.

The current build target is Apple Silicon (arm64). Do not advertise Intel GUI
support from historical cross-compilation alone. The minimum deployment target
is macOS 14; tested hardware/OS must be recorded with final verification.

See [acceptance](../ACCEPTANCE.md), [provider contracts](providers/README.md),
and [installation text](../Resources/Install.txt). Historical readiness is retained in Git history.
