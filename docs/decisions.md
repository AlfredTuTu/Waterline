# Decisions

Append-only. ARCHITECTURE.md describes the current state; this file keeps the reasons and the roads not taken.

| Date | Decision | Why | Instead of |
|---|---|---|---|
| 2026-09-06 | MIT licence | Same family as the tools we read (CodexBar) so forks can carry the project on; keeps every dependency option open | GPL-3 (would forbid nothing useful and inherit from GPL references we do not copy anyway) |
| 2026-09-06 | Own `NSPanel` for the notch window | ~200 lines of AppKit we fully control; no third-party UI dependency to track across macOS releases | DynamicNotchKit (MIT, maintained, but another moving part for the one piece of UI that must be pixel-exact) |
| 2026-09-06 | In-process engine, no daemon, no local server | A menu-bar app is already always on; a daemon doubles Keychain authorisation, signing and installation for no gain | LaunchAgent + IPC; localhost HTTP API |
| 2026-09-06 | `snapshot.json` + CLI as the integration surface | Anything on the machine can read a file; no protocol to version | Sockets, XPC, URL scheme |
| 2026-09-06 | Three targets: `WaterlineKit`, `WaterlineCLI`, `WaterlineApp` | Adapters are folders inside the kit; a separate module adds boilerplate, not isolation. UI-free presentation logic lives in the kit so it is testable | Four targets with a separate adapters module |
| 2026-09-06 | Credential is the primary key, not the vendor | One vendor can be zero, one or several accounts on a machine (Kimi Code subscription vs Moonshot top-up); gateway routes belong to no local account | Per-vendor rows |
| 2026-09-06 | Adapters report only what the API returned and throw otherwise; the engine owns freshness | Never a fabricated number on screen; stale vs unavailable is an engine concept | Adapters returning best-effort placeholders |
| 2026-09-06 | GitHub Issues + milestones as the agent work queue | Same place as the code and PRs; `Closes #n` closes the loop; `gh issue list --json` is the agent's API | Linear (kept for the owner's other work; keeps agent-generated sub-issues out of it) |
| 2026-09-06 | CodexBar, boring.notch, open-vibe-island are references, never sources | Clean MIT provenance; the last two are GPL | Porting adapter code with attribution |
| 2026-09-06 | Zero third-party dependencies before v1.0 | Cursor's SQLite is read with the system `SQLite3`; TOML/JSON needs are narrow enough for Foundation | swift-argument-parser, TOMLKit, GRDB |
| 2026-09-06 | Pure SwiftPM, no `.xcodeproj`; `Scripts/bundle-app.sh` makes the `.app` | Text files agents can edit and diff; CI needs only `make verify` | Xcode project, XcodeGen, Tuist |
| 2026-09-06 | Toolchain pinned to stable Xcode 26.6 / Swift 6.3, macOS 14 minimum | Matches the `macos-26` CI runner; the beta Xcode on the owner's machine is not the reference | Xcode 27 beta |
