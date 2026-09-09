# AGENTS.md

Waterline is a macOS notch/menu-bar app showing the usage windows and prepaid balances reported for
accounts discovered on this machine. It has no backend or telemetry. Credentials go only to the
appropriate provider endpoints. Missing data stays missing; deterministic calculations are allowed,
and predictions must be labelled as estimates.

## Where things are

- `ARCHITECTURE.md` — what to build: process model, modules, data model, adapter contract, engine,
  credential discovery, persistence, testing, toolchain.
- `ACCEPTANCE.md` — what "done" means: the verification gates and each milestone's checklist.
- `docs/ui.md` — the notch UI: states, rows, colours, interactions, geometry.
- `docs/providers/<name>.md` — one contract per provider: credentials, endpoints, response mapping,
  allowed hosts, capability-review and live-verification dates. `docs/providers/README.md` has the matrix and how to add one.
- `docs/decisions.md` — why things are the way they are. Append a row when a decision changes.
- GitHub Issues and milestones — the shared work queue when working through GitHub. A direct owner
  request also defines work; do not require an issue for an explicitly requested local review or edit.

## Reading the rules

Follow the owner's current task and constraints. Product requirements live in `ARCHITECTURE.md`;
presentation behaviour in `docs/ui.md`; provider-specific evidence in `docs/providers/`; verification
in `ACCEPTANCE.md`. Update related documents together when changing a rule. Historical decisions do
not override their later replacements. Describe target behaviour separately from implemented and
verified behaviour; neither a plan nor a passing build proves a provider works.

## Source layout

- `Sources/WaterlineKit` — everything testable: `Model`, `Providers`, `Host`, `Engine`, `Snapshot`,
  `Presentation`. Never imports AppKit or SwiftUI.
- `Sources/WaterlineKit/Providers/<Name>/` — one folder per provider, one line in `Providers/Registry.swift`.
- `Sources/WaterlineCLI` — `waterline`, the engine's second client and the way to verify without the UI.
- `Sources/WaterlineApp` — SwiftUI app lifecycle, the notch `NSPanel`, views. Thin; logic goes in the kit.
- `Tests/WaterlineKitTests` — Swift Testing. `Fixtures/<provider>/` holds reviewed responses and labelled synthetic cases.

## Working loop

1. Read the requested task and relevant documents. For issue-driven work, select the lowest open
   issue in the current milestone assigned to this agent whose dependencies are closed; read its body.
2. Inspect the working tree and preserve unrelated work. For issue-driven implementation, branch from
   an up-to-date `main`; an explicitly local documentation task does not require remote operations.
3. Implement with suitable verification. Use tests for logic and regressions; native app checks for
   UI and OS integration that unit tests cannot establish.
4. Run `make verify` and check applicable acceptance items. Documentation-only work needs no new
   tests; check references, consistency and the existing gate. Report checks that could not run.
5. Update affected contracts and append changed architectural decisions to `docs/decisions.md`.
6. When delivery through GitHub is requested, use the PR template, reference the issue if present,
   ensure CI is green, and add `status:review`. When the owner authorizes merging or end-to-end
   release delivery, perform the normal squash merge and release workflow after the required checks;
   do not require the owner to operate the merge button personally.

Resolve routine implementation choices within the authorised scope and record material trade-offs.
If a change needs an owner decision about product scope, privacy or an incompatible interface, explain
the concrete choice and continue unaffected work. Do not stop the entire task for every discrepancy.
For issue-driven work, record scope changes on the issue and use `status:needs-decision` where needed.

## Authorization and execution

- The owner's latest explicit instructions define the authorized scope and supersede older project
  workflow preferences. Authorization persists across turns; do not ask again for an action already
  approved in this task.
- An explicit end-to-end GitHub delivery/release request authorizes preparing and updating the PR,
  merging the reviewed change after required CI passes, creating the release tag, uploading the
  verified artifacts and publishing the Release in the named repository. Respect an explicit
  draft-only or stop-before-merge instruction instead when present.
- Use the PR workflow by default and verify the exact head before merging. Direct pushes or force
  pushes to protected/default branches require a specific instruction; publishing does not implicitly
  authorize changing repository visibility, bypassing branch protection or modifying unrelated work.
- Requests to validate the owner's real accounts authorize the necessary bounded read-only checks
  for those providers. Do not request a new approval for each routine check. Raw credential exposure,
  unrelated destinations, purchases and expansion beyond the task are not implied.
- Platform permission controls and automatic review still apply. If an action is rejected, explain
  the concrete rejection and obtain any missing authorization; never bypass it indirectly. A new
  explicit owner authorization may be used when retrying the same action.
- Verification, data protection and truthful completion reporting remain mandatory. Authorization
  to publish is not permission to invent successful tests or hide unresolved failures.

## Complete workflows and external assistance

The frontend and the local backend must form complete working flows. The backend is the kit's engine,
provider, account and persistence logic. A visible action must reach that logic, expose progress and
success/failure, update the UI and persist the result where applicable. Verify restoration after
relaunch. An isolated view, parser, mock response or passing unit test does not complete a user flow.

Use Claude Code CLI or Grok explicitly selected through Cursor CLI for bounded design/technical
consultations when evidence or an implementation choice remains uncertain. These are the permitted
external AI assistants for backend research, architecture, provider integrations, data, persistence,
security and debugging; do not use Antigravity for those tasks. Verify the current Cursor model list
and select its exact Grok model ID instead of relying on a default model. The owner's reference to
"Grok Bot quota" means the quota available for Grok within Cursor, not a separate bot or the standalone
Grok Build CLI. Check Cursor's actual reported allowance and applicable billing before use; model-list
availability alone does not establish remaining quota or free usage. Antigravity CLI is limited to
frontend design alternatives; Figma can
establish layouts, components and interaction states when that would resolve a design question.
Compare candidates using the same brief and states, assessing clarity, native macOS fit, accessibility,
implementation cost and actual flow completeness. Select and implement a coherent result; a Figma
frame or another agent's opinion is not native-app verification. The owner has authorised these aids
for this project; no separate approval is needed for each ordinary consultation within this scope.

Keep consultation economical: inspect available usage information without exposing credentials,
send only the minimum relevant redacted context, and begin with one bounded call plus a targeted
follow-up only if needed. Avoid sending the whole repository or repeatedly asking multiple models the
same question. Use read-only/planning tool permissions for advice; any delegated edits must have a
bounded file scope and be reviewed before integration. Never bypass permission controls. Do not enable
extra billing or buy usage credits without explicit approval. API-dollar caps do not establish a cap on
subscription-window usage; if remaining quota cannot be read, report it as unknown and limit calls.

Do not presume a blocker before investigating. Inspect code, reproduce the issue, consult primary
documentation and, where useful, consult one of the authorised assistants for alternatives; then test
the selected solution.
Unavailable helper quota does not block local implementation or verification. Escalate only a concrete
remaining dependency requiring owner action, while continuing independent work. Do not invent access,
live evidence or successful verification to avoid reporting an actual limitation.

Close each problem with evidence: establish the failing behaviour or unmet requirement, identify its
cause, implement the correction, repeat the relevant failing scenario and verify the affected user flow.
Advice, a code edit or a green unrelated test is not a resolution. Do not suppress errors, replace real
results with mocks, disable features, weaken assertions or relax acceptance criteria to make a problem
appear fixed. An accurate error message improves handling but does not prove the underlying integration
works. Keep unresolved or unverified items open and report exactly which behaviour remains to be proven.

## Code rules

- Validate network responses, files, OS results and user input at boundaries; trust validated types
  inside the process. Avoid redundant guards, swallowed errors and checks for impossible states.
  Recovery from actual external failures is required, including isolating one failed account.
- Keep abstractions proportionate. A helper used once is useful when it clarifies intent, isolates a
  boundary or enables testing. Remove dead code, forwarding-only wrappers without a purpose, and
  comments that merely restate the code. Do not build for hypothetical needs.
- Map supported provider fields and documented deterministic calculations. Ignore unrelated added
  fields; incompatible required fields produce `FetchError.schemaChanged` naming the field path.
  Retain independently valid metrics when the contract supports partial results. Zero is never a placeholder.
- Keep account identity separate from credentials; rotating a secret must not reset history or settings.
- Send secrets only over HTTPS to the account's documented provider/region endpoints, within the
  adapter's `allowedHosts`. Enforce this on redirects too; never forward credentials to another origin.
- Recurring background work never shows a Keychain prompt. Prompts are limited to the owner-approved
  initial connection flow or an explicit reconnect, using macOS's normal authorization controls.
- Automated tests never contact live services or the real Keychain. Fixtures are reviewed and redacted;
  `Scripts/audit.sh` is an additional pattern check, not proof that all private data was removed.
- Prefer system libraries. A new dependency needs a concrete benefit, licence and maintenance review,
  and a decision entry; update the audit allowlist in the same implementation change. Do not introduce
  dependencies during documentation-only work.
- Swift 6 strict concurrency. `WaterlineKit` is nonisolated by default; `WaterlineApp` is `MainActor` by default.
- Main UI text is short and plain. Optional diagnostics may include redacted technical details needed
  to understand a failure; never include credentials, raw headers or raw response bodies.

## Commands

- `make verify` — build, test, `swift-format lint --strict`, whitespace check, `Scripts/audit.sh`. The one gate; CI runs exactly this.
- `make test`, `DEVELOPER_DIR=/Applications/Xcode.app xcrun swift test --filter <Name>` — focused runs while iterating.
- `make format` — apply the formatter before committing.
- `make app`, `make run` — bundle `build/Waterline.app` and relaunch it. Only for UI checks.
- `.build/debug/waterline snapshot --json` — read the last stored snapshot; `version` is also implemented.
- CLI now includes `accounts`, `refresh [--provider codex] [--json]`, `connect <provider>`, and
  `account enable/disable/pin/unpin/rename/remove`. Manual `account add <provider> --stdin` and `account key <id> --stdin` are implemented for supported manual providers; raw `--dump` remains planned. Implemented commands have injected CLI entry-point coverage. Check implementation before using these commands. A live check needs explicit
  authorisation in the task or owner request. `connect <provider>` permits an announced Keychain read; `--dump`
  is a separate, explicit raw-capture action governed by `docs/providers/README.md`.
- Reference toolchain: Xcode 26.6, Swift 6.3.x. `make` defaults to `/Applications/Xcode.app`; CI selects
  `/Applications/Xcode_26.6.app`. Direct `xcrun` and bundle-script calls need `DEVELOPER_DIR` explicitly.
  Verify versions at these paths; do not silently switch toolchains to make a check pass.

## Git

- Branches: `codex/<n>-<slug>`, `claude/<n>-<slug>`, `alfred/<slug>`; omit the number for authorised work without an issue.
- Conventional Commits: `feat(providers): deepseek balance adapter`, `fix(engine): honour Retry-After`.
  End the body with `Refs #<n>` when there is an issue; never invent a reference.
- No attribution trailers or generated-by lines in commits or PR descriptions. Use the owner's configured authorship.
- Never commit secrets, `.env`, unredacted captures, `build/` or `.build/`.
