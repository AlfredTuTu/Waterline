# Native software updates — implementation contract

Status: initial native integration, 2026-09-08. The exact dependency, native controls
and framework embedding are implemented. No feed/public key is configured and no
updater is initialized without them. Update requests and a real signed installation
have not been verified. This does not close release acceptance.

## Selected candidate and dependency review

Sparkle 2.9.6 is the selected dependency for the native application updater. The release API
reported publication on 2026-08-17. Its tagged SwiftPM package is a binary target
with archive checksum `8d5fb41d960b43f4a68aa14126bf62b098544ec8d191cdcc73eb14e63a8e7606`.
Pin an exact reviewed version; changes require renewed review and a resolved-file update.

The benefit is a maintained macOS installer/relaunch implementation with archive
signature verification, rather than a new privileged executable-replacement system.
The top-level license is MIT-style; bundled bsdiff, sais, Ed25519 and signature-verifier
notices must also ship intact. Keep the complete upstream license in the app bundle.
The official release is recent, but maintenance activity is not a security guarantee.

Sources inspected:
- [2.9.6 release](https://github.com/sparkle-project/Sparkle/releases/tag/2.9.6)
- [Package and checksum](https://github.com/sparkle-project/Sparkle/blob/2.9.6/Package.swift)
- [Complete license](https://github.com/sparkle-project/Sparkle/blob/2.9.6/LICENSE)
- [Official integration and signing guide](https://sparkle-project.org/documentation/)
- [Programmatic integration](https://sparkle-project.org/documentation/programmatic-setup/)

## Target user flow

General settings exposes Check for updates and an automatic-check toggle, initially
off. Explicit checks show checking, current version, available update or an actionable
failure. Installing requires the user's choice in native update UI. Closing an update
prompt leaves the running app usable. Disabling automatic checks persists across
relaunch. Do not enable automatic installation or profile submission by default.

The updater must not initialize in verification builds or when the release feed/public
key configuration is absent. Development builds should show a short unavailable state,
not query a fake URL. An update must preserve accounts, preferences and local history.

## Network and trust boundary to implement

Update traffic is separate from provider traffic. It carries no provider credentials,
account identifiers, balances, usage records or optional system profile. The user sees
that enabling checks contacts the release host. Ordinary request metadata remains
visible to that host; privacy text must describe this accurately.

The allowed feed configuration is `https://github.com/AlfredTuTu/Waterline/releases/latest/download/appcast.xml`.
This repository remains private and no feed URL is configured in the app yet. Before enabling traffic,
record the exact feed URL, archive URL pattern and observed HTTPS redirect destinations;
review how the chosen Sparkle version constrains feed, archive and release-note requests.
Do not reuse the credential-bearing provider HTTP client or allow arbitrary URL overrides.

Require signed feeds and pre-extraction archive verification in addition to Developer ID
and notarization checks. No production key is generated as part of this document. The
owner's release signing setup, key backup/rotation procedure and configured public key
must be established before publishing an update-capable build.

## Integration and acceptance work remaining

- Implemented: exact dependency, resolved version, license and audit allowlist.
- Implemented embedding with preserved symlinks/permissions and executable runpath;
  nested helpers/framework are signed before the application. Release signature checks remain required.
- Implemented native controls and observed updater state with localized text. Verify
  persisted opt-in and disabled network behavior with a configured signed build.
- Generate and validate a signed feed and archive from real release artifacts.
- Test old-to-new installation, relaunch and unchanged user data on a clean installation.
- Test altered archive/feed signatures, failed network, cancellation, read-only app location,
  disabled checks, version comparison and update-signing key rotation policy.

An ad-hoc build, feed parser test or framework import cannot prove this flow. Until the
signed old/new artifact test succeeds, signed updates remain incomplete in AGENTS.md.

## Configuration and archive policy checks

`SoftwareUpdatePolicy` rejects missing feed/key, disabled signature checks, enabled
automatic checks/install/profile defaults and release-note downloads. The native
Sparkle delegate returns no permitted system-profile fields and rejects initial
archive URLs outside this repository's versioned GitHub DMG assets. Regression tests
cover missing/altered config and non-HTTPS, foreign-owner/host, user-info, traversal,
query/fragment and non-DMG URLs. This does not yet prove redirect restrictions.

`Scripts/check-update-config.py` applies the release plist gate during distribution
preflight. The current development bundle correctly fails it because no feed/public
key is configured. Passing that gate proves syntax/policy, not key ownership, archive
signature validity or real installation.

## Fixed-version transport review — 2026-09-08

At resolved revision `ac2def288cbff5cfc7df3ffef6abdf45b72bcb0a`,
`Downloader/SPUDownloader.m` creates a default NSURLSession and does not implement
`willPerformHTTPRedirection`. `Sparkle/SPUDownloadDriver.m` builds requests and
accepts optional supplied headers; Waterline supplies no provider headers. The
actual downloaded Downloader.xpc plist sets `NSAllowsArbitraryLoads` to false.
The updater delegate API supports the implemented empty system-profile key list.

Consequently, initial feed/archive URL policy is implemented, but a per-redirect
host allowlist is not. ATS and signed-feed/archive validation are separate controls,
not evidence of a redirect allowlist. Keep this limitation explicit; inspect actual
GitHub delivery and test downgrade/unexpected-redirect handling before configuring
a production feed. The updater remains uninitialized in the current bundle.

Source: [fixed-version downloader](https://github.com/sparkle-project/Sparkle/blob/ac2def288cbff5cfc7df3ffef6abdf45b72bcb0a/Downloader/SPUDownloader.m).
