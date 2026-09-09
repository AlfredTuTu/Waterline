# Release acceptance

Current owner scope: finish the current native interface and Claude Code local quota
reading, optimize performance, simplify this repository, submit to GitHub, pass CI
and publish the first Release. Stop the active goal after this scope is complete.
Do not expand additional providers, subscription tiers or new features.

## Required gates

- [x] Current UI matches owner decisions: no overview heading, Token records,
  connection guide, redundant account actions or rate-limit explanation. Sorting
  is available directly on cards and in the footer Waterline menu.
- [x] Native drag ordering saves and restores; menu language controls work. Retired launch-at-login registration is removed. First launch connects without a separate guide, with OS
  permission prompts only as required.
- [x] Claude CLI local observation -> identity binding -> private bounded storage
  -> engine -> native card is verified with the owner's real account. Duplicate
  callbacks, account changes, reset expiry and restart preserve correct freshness.
- [x] Claude server fallback is explicit app policy, respects backoff and does not
  accelerate on opening the panel. No claim of an undocumented official limit.
- [x] Performance is measured on the final installed Release: mean CPU <1%
  (100%=one core), physical memory <120MB, no material interaction regression.
  A completed earlier sample is not evidence for a later binary.
- [x] Repository cleanup preserves source, real-account state, credentials and
  necessary verification evidence. Remove unused product code and stale drafts;
  retain actionable provider contracts and reproducible build instructions.
- [x] `make verify` passes locally and on GitHub for the exact release commit.
- [x] Release bundle/DMG identity, installation, launch and update behavior are
  checked. Signing/notarization/Gatekeeper conditions are accurately reported;
  ad-hoc signing is never described as Developer ID or notarization.
- Publication gate: verify the first GitHub Release and its downloaded attachments
  after publishing; the remote Release is the authoritative completion record.

## Verified candidate evidence

- Final application SHA256:
  `4fae1d8cb646120d4db9c2d30d83179dadc038c6d984602265ecb1f2918b1d5d`.
  Runtime sources have not changed since commit 3fce5f9; later changes concern
  documentation, installation text and checksum-file formatting.
- Local `make verify`: 335 Swift tests in 76 suites plus script/format/audit gates.
  GitHub verified candidate commit bf51e628d7bf32da5b1cca64e098c5a8d3de0563
  successfully in run 34290887498. Recheck the final documentation commit before tagging.
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

## Historical evidence

Superseded milestone logs remain in Git history (for example commit 4e9ca10).
They are not duplicated in the working directory or treated as current acceptance.
Key live-verification artifacts are kept locally under `build/verification`.
