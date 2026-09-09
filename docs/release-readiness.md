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

## Release validation checklist

- Final exact-commit local and GitHub `make verify` pass.
- Final Release installation and native UI checks, including ordering and language.
- Claude CLI local delivery, account isolation, cached-data handling and server fallback.
- Final binary performance sample under the acceptance protocol.
- DMG verify, read-only mount, matching copied bundle and installation instructions.
- SHA256 checksum and GitHub release attachment verification.

The current build target is Apple Silicon (arm64). Do not advertise Intel GUI
support from historical cross-compilation alone. The minimum deployment target
is macOS 14; tested hardware/OS must be recorded with final verification.

See [acceptance](../AGENTS.md), [provider contracts](providers/README.md),
and [installation text](../Resources/Install.txt). Historical readiness is retained in Git history.

## Verified candidate evidence

- Final application SHA256:
  `4fae1d8cb646120d4db9c2d30d83179dadc038c6d984602265ecb1f2918b1d5d`.
  Runtime sources have not changed since commit 3fce5f9; later changes concern
  documentation, installation text and checksum-file formatting.
- Local `make verify`: 335 Swift tests in 76 suites plus script/format/audit gates.
  GitHub verified candidate commit bf51e628d7bf32da5b1cca64e098c5a8d3de0563
  successfully in run 34290887498. The merged release commit and attachment verification are recorded in the local publication report.
- Final real-account performance: 600 seconds warmup + 600 one-second samples;
  mean CPU 0.5199955%, peak physical footprint 55,493,880 bytes (52.9 MiB).
  Configuration and executable unchanged; maximum sample gap 1.030 seconds.
  Tested on Mac17,9 with 48 GiB memory, macOS 27.0 build 26A5425a. This is not a
  universal OS/hardware or energy-use claim.
- Native GUI verification: Claude's old 38%/login-error card changed to desktop
  data 2%/33%, retaining the original 08:30:07 sample time; later automatic GUI
  updates reached 12%/34%. Same-binary restart preserved valid data. CLI local
  delivery was independently observed through the installed receiver. Offline
  regressions cover source identity, replay, expiry and failed fallback handling.
- Owner explicitly confirmed card drag changes/preserves order and language
  selection works. Full-card preview is installed. Footer sorting window opens
  natively. The retired login item is system-reported disabled.
- The final DMG passed sealed-code/resource checks, read-only mount and full
  file/symlink inventory comparison. Its Read Me and Applications link match.
  DMG SHA256: `4ecf8c2c9b8f3f1a2f9d09a90bf7f30db8d779b1cbc21d8bec5c5c5c41b5e02b`.
- Unnotarized/ad-hoc distribution and manual updates were explicitly approved
  by the owner. Developer ID and notarization are not claimed. Repository
  visibility remains private.
- Old draft bundles, caches, development images and duplicate history documents
  were removed. Current artifacts, selected evidence and pre-upgrade account-state
  backups remain; canonical account files and Keychain data were not deleted.

Detailed local evidence is consolidated in
`build/verification/release-validation-summary.json` and the final runtime report.
