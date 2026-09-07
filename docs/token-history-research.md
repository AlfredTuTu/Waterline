# Token history and API-equivalent valuation — evidence checkpoint

Current status: read-only analysis and explicit native Codex-log import/persistence are implemented. Account attribution remains unimplemented. A dated GPT-6 Astra Standard API reference is now available for eligible records; other models remain unpriced. See token-reference-pricing.md. Earlier checkpoints below retain their original evidence scope.

Owner requirement: retain long-term usage and, when evidence permits, show an explicitly estimated API-equivalent value. Keep native SwiftUI/AppKit UI and region-specific account/endpoint/currency identities. Do not derive money from quota percentages.

## Verified source shape (2026-09-07)

Primary protocol: https://raw.githubusercontent.com/openai/codex/main/codex-rs/protocol/src/protocol.rs

The protocol defines TokenUsageInfo with total_token_usage and last_token_usage, and TokenCountEvent with info and rate_limits. TokenUsage includes input_tokens, cached_input_tokens, cache_write_input_tokens, output_tokens, reasoning_output_tokens and total_tokens. The protocol also has a per-response TokenUsageRecord carrying response/thread/turn/session IDs; availability in a particular installed rollout must be verified before relying on it.

A bounded 8 MiB tail of this task's own local rollout contained 168 token_count events with the above cumulative and last-usage fields. Only schema keys and event counts were returned; no prompt, response, path metadata, credentials or account identifiers were exported. This sample does not establish the shape of all historical files.

## Required before import/valuation

- Never sum cumulative snapshots or treat a quota-only repeat as new token usage. Validate monotonic counters, resets/compaction semantics and duplicate observations; do not silently guess a reset delta.
- Prefer per-response identity where actually present. Forked/copied histories need deduplication based on original event ownership, not physical filename alone.
- Resolve model and service tier from matching turn metadata. Unknown model/pricing stays unpriced. Retain pricing version, currency and effective date; current prices are not automatically historical prices.
- Validate how cache writes and cache reads relate to input totals, and whether reasoning tokens are a subset of output, before applying prices. Avoid double charging subsets.
- Historical local session use must not be assigned to whichever account is currently logged in. If stable historical account/region evidence is unavailable, present unassigned local usage separately.
- Read only recognized usage/identity fields; retain no prompt or response body. Bound reads, resume incrementally, preserve originals, survive truncated tails, and avoid duplicate imports on relaunch.
- A billed amount and an API-equivalent estimate are different metrics. Keep original currencies separate; any optional conversion needs dated exchange-rate evidence.

Next implementation gate: reviewed redacted/synthetic fixtures covering repeats, compaction, fork ownership, model changes and unknown account identity; then an explicit source opt-in and a native import-to-history flow with persistence/relaunch verification. No external service is required for reading local usage records.

## Counter foundation — 2026-09-07

`CodexTokenCounters` validates integer, nonnegative counters, input/output total consistency, cached-input and reasoning-output subset bounds, and overflow. Older absent cache-write counters follow the protocol's documented default. This is a supported-profile validator; an incompatible record must be reported, not repaired by invented counters.

`TokenCounterAccumulator` operates on one already-resolved logical stream. Its default unknown-origin first observation establishes a baseline without claiming usage. Identical totals are duplicates. Counter regressions or inconsistent deltas create explicit discontinuities and rebaseline; a later valid interval can be counted separately. A verified complete stream may explicitly supply a zero baseline. The versioned checkpoint round-trip prevents recounting the same totals, and rejects an unknown checkpoint version.

Tests cover duplicates after checkpoint restoration, unknown-origin fragments, counter reset, late cache correction, invalid subsets and integer overflow. This is not a log importer, persistent ledger, fork/account resolver or valuation feature. Callers must retain discontinuity/coverage information and validate stream/model ownership before assigning any delta. Cache-write pricing overlap remains to be established and is not inferred by this component.

A subsequent bounded sample of this task's local log had 198 cumulative events, all with total=input+output and cached/reasoning subset bounds. Only invariant counts were emitted. It does not prove these assumptions for every tool version, provider backend, fork or historical session.

## Read-only log analysis — 2026-09-07

`waterline analyze-codex-log <path> [--json]` now analyzes one explicitly selected regular file without starting the engine or modifying its journal. File reads are bounded to the initial file length (512 MiB maximum), chunks to 64 KiB and records to 4 MiB. It extracts only session metadata, model context/reroute and token-count fields; no prompt or response is returned or persisted.

The current supported profile requires one original UUID session header, a plain cli/vscode/exec source, and no fork/parent/history-base markers. Mixed or inherited headers are rejected. First cumulative=last counters can establish a complete first interval; an unknown prefix starts at a baseline. Missing intermediate responses retain observed counter deltas without model attribution. Counter discontinuities are reported, and sample IDs distinguish reset segments while remaining stable across identical copies. Whole-file reanalysis is implemented; an incremental file checkpoint/ledger merger is not.

JSON returns decimal-string observed counts, coverage gaps, incomplete-tail status, and explicit accountAttributed=false/priced=false. Exit 2 reports partial coverage, exit 1 unsupported/unreadable input, exit 64 invalid command syntax. This is not total account consumption or a monetary estimate.

Synthetic end-to-end tests cover CLI output and source-byte preservation, duplicate/copy identity, incomplete tail, missing prefix, inherited ownership rejection, reset ID collisions and unattributed intermediate responses. Current task's real log was tried read-only and rejected at a ~7.2 MB `compacted` record (line 2825), beyond the record budget. No actual-log success is claimed; safe support for large compaction records remains necessary. Diagnostic inspection emitted only record type, line index and size, not content.

## Streaming large records — 2026-09-07

The previous 7.2 MB compaction incompatibility is resolved by streaming JSONL validation rather than increasing the relevant-record decode budget. A 64 KiB scanner validates full JSON grammar, UTF-8/escape sequences, unique object keys and nesting, retaining only root/payload type fields for dispatch. Unrelated bodies are not materialized. Relevant metadata/counter records still have a 4 MiB decode budget; the 512 MiB file limit remains. Retained object-key state is bounded to 10,000 keys and 1 MiB, with depth 128.

Unterminated tails remain deferred; malformed newline-terminated records fail. Invalid last-usage counters no longer erase independently valid cumulative counters: only verifiable deltas are retained, with model attribution withheld and a coverage gap when needed. Repeated cumulative totals remain duplicates regardless of last-usage metadata.

The same real task log subsequently completed in Debug and Release. Release snapshot: 1,028 samples, no detected coverage gap or incomplete tail, accountAttributed=false and priced=false. The task remained active, so sample counts differ between snapshots. Measured wall time ~0.738 s and maximum RSS 70,090,752 bytes on this Mac; this is CLI RSS, not physical-footprint or long-running native-app acceptance. Evidence: build/verification/token-log-release-read.json. No full transcript was copied to an artifact.
