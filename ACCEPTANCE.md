# Release acceptance

Current owner scope: finish the current native interface and Claude Code local quota
reading, optimize performance, simplify this repository, submit to GitHub, pass CI
and publish the first Release. Stop the active goal after this scope is complete.
Do not expand additional providers, subscription tiers or new features.

## Required gates

- [ ] Current UI matches owner decisions: no overview heading, Token records,
  connection guide, redundant account actions or rate-limit explanation. Sorting
  is available directly on cards and in the footer Waterline menu.
- [ ] Native drag ordering saves and restores; menu language controls work. Retired launch-at-login registration is removed. First launch connects without a separate guide, with OS
  permission prompts only as required.
- [ ] Claude CLI local observation -> identity binding -> private bounded storage
  -> engine -> native card is verified with the owner's real account. Duplicate
  callbacks, account changes, reset expiry and restart preserve correct freshness.
- [ ] Claude server fallback is explicit app policy, respects backoff and does not
  accelerate on opening the panel. No claim of an undocumented official limit.
- [ ] Performance is measured on the final installed Release: mean CPU <1%
  (100%=one core), physical memory <120MB, no material interaction regression.
  A completed earlier sample is not evidence for a later binary.
- [ ] Repository cleanup preserves source, real-account state, credentials and
  necessary verification evidence. Remove unused product code and stale drafts;
  retain actionable provider contracts and reproducible build instructions.
- [ ] `make verify` passes locally and on GitHub for the exact release commit.
- [ ] Release bundle/DMG identity, installation, launch and update behavior are
  checked. Signing/notarization/Gatekeeper conditions are accurately reported;
  ad-hoc signing is never described as Developer ID or notarization.
- [ ] First GitHub Release is published with the verified artifacts, checksums,
  concise release notes and the explicitly accepted unnotarized-installation limitation.

## Current evidence and open conditions

- UI and Claude changes are being finalized; see provider contracts and `docs/ui.md`.
- Installed binary e40d7c5b completed a 10-minute warmup + 10-minute sample:
  mean CPU 0.9849977%, peak physical footprint 67,224,848 bytes. Configuration and
  executable unchanged. This sample met numerical targets with narrow CPU margin;
  it does not establish final-build performance or isolate individual optimizations.
- Native Claude local delivery was observed at 23:54: 5h 38%, 7d 32%, origin `local`,
  without pressing Refresh. Later fallback-policy changes require final validation.
- Signing identity inventory returned zero valid identities. Formal signing and
  notarization are deferred: the owner explicitly approved first-release distribution
  with the standard macOS Privacy & Security override. They are not blockers for
  this release and must not be claimed as completed.
- GitHub repository is private; owner has authorized submission and first Release.
  Visibility is not changed implicitly.

## Historical evidence

[Previous milestone checklists and execution records](docs/archive/acceptance-history-2026-09-08.md)
are historical evidence only. Later owner decisions supersede retired feature scope;
retired requirements are not marked as passed. Relative paths in that historical
record refer to the repository root unless explicitly stated otherwise.
