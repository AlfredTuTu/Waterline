# Optional hook activity — scope and evidence

Status: initial implementation, 2026-09-08. The CLI receiver, local notification
transport, session-state model, native opt-in/banner and owned-entry cleanup exist.
The complete real-tool/native workflow remains unverified; this does not close
ACCEPTANCE.md's hook requirement.

[Claude Code's official hooks reference](https://code.claude.com/docs/en/hooks)
documents command-hook JSON input including `session_id` and `hook_event_name`.
Candidate events are UserPromptSubmit, Stop, StopFailure and SessionEnd. Prompt,
transcript path, working directory and assistant/error text can also occur in input;
Waterline must discard them and never read the referenced transcript. Review actual
installed CLI event support before configuring it. Events are tool-session evidence,
not proof of billing-account identity or precise token consumption.

The implementation must provide an explicit native opt-in, a working local receiver,
visible state and disable/cleanup. Default is off. Enabling must explain the exact
configuration change; disabling removes only Waterline-owned entries and preserves
other hooks/settings. Background startup never installs hooks. Failures must surface
without blocking the coding tool or exposing hook payloads.

Bound local input size, hash session identifiers, handle simultaneous sessions,
duplicate/out-of-order endings and crash/expiry. Missing completion events must not
leave an indefinitely running indicator. Events must not change usage fractions or
infer the selected quota account from a tool name: Claude Code can route to other
providers. Keep provider/account attribution separate from tool activity.

Acceptance requires an actual enabled tool session reaching the native UI, no payload
content stored, no automatic notch expansion, disabling and preservation of unrelated
configuration, relaunch restoration and cleanup. Pure parser fixtures are insufficient.

Implemented protocol: `waterline hook-claude-v1` accepts at most 1 MiB on stdin,
extracts only the event kind and a bounded session ID, hashes that ID and emits a local
distributed notification containing only hash/kind/time. It produces no stdout. The
app ignores notifications while disabled, rejects stale/future/older events, caps
tracked sessions at 256 and expires activity after ten minutes. No quota data changes.
The banner is in the expanded overview; receiving an event never expands the notch.

Enabling updates only the four named events in `~/.claude/settings.json`, preserves
unrelated JSON/hooks and refuses disabled-all-hooks or malformed settings. Commands
are quoted absolute bundled-CLI paths with a two-second tool timeout. Replacement
uses a private temporary file, checks for an observed external edit before rename,
and rejects regular/broken file symlinks. This is not an atomic compare-and-swap with
an unrelated writer; concurrent vendor edits remain a native integration test case.
A saved pending command supports cleanup after interrupted installation. Disabling
stops reception before attempting removal; unsuccessful cleanup remains retryable.

Four offline tests cover payload exclusion, session overlap/replay/expiry, preservation
and idempotence, private permissions and symlink refusal. An isolated real CLI-to-local
notification test received the sanitized synthetic event with no stdout. No real Claude
settings were edited or enabled. Actual tool event support, native opt-in, relaunch,
disable and layout checks remain pending.
