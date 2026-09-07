# Waterline · 水位

**中文** · [English](#english)

Waterline是一个开发中的macOS原生刘海/菜单栏应用，目标是自动发现本机已有的AI编程工具账号，
集中显示服务商报告的**额度使用情况、重置时间和预付费余额**。

- 一个真实账号一行，凭据可以更换；同一账号的多个来源可以合并，不同地区或计费范围保持独立。
- 支持服务商原始值和有明确依据的计算；缺失数据不补零，预测值标`≈`。
- 最小状态常显一个账号的图标与剩余额度，点击展开、移出收起，图钉选择日常账号；无刘海的屏幕使用悬浮胶囊。数据过期时保留上次读数并显示时间。
- 余额按各自币种的阈值判断状态，不直接比较不同币种金额。

### 当前状态

截至2026-09-06，已建立SwiftPM工程、基础模型与引擎、快照存储、HTTP/钥匙串边界和刘海占位界面。
CLI已实现`snapshot`、`version`、`accounts`和初步`refresh`。Codex已完成一次真实只读额度查询及原生Release显示/刷新检查；其余Provider和完整账号管理仍在开发。
下列服务属于计划范围，不代表已经支持：

- v0.1：Claude Code、Codex、Cursor、xAI。
- v0.2：智谱、Kimi Code、Moonshot、MiniMax、DeepSeek，以及余额历史与估算。
- v0.3：Antigravity、Qwen能力评估、完整设置与引导、中英文界面。

具体指标以验证后的接口能力为准。Provider状态和证据要求见[服务商说明](docs/providers/README.md)，
目标设计见[架构](ARCHITECTURE.md)，完成标准见[验收](ACCEPTANCE.md)。

### 隐私设计

以下是必须实现并验收的约束，尚不代表当前骨架已通过完整隐私验证：

- 没有Waterline后端、遥测或崩溃上传服务。认证信息和必要账号标识仅发送到对应服务的获准HTTPS地址。
- 仅读取列明的工具凭据位置；配置文件扫描按来源选择开启，不执行Shell文件。后台钥匙串操作不弹授权框。
- 不修改其他工具的凭据；手动输入的密钥写入本应用自己的钥匙串条目。
- 常规状态与历史保存在`~/Library/Application Support/Waterline/`，偏好设置由`UserDefaults`保存。
  明确请求的诊断导出写入用户选择的位置；原始响应可能含隐私信息，须单独处理、脱敏且不提交。
- 不以完全磁盘访问权限作为前提。受限来源显示原因；启用真实连接时说明读取范围。
- 后续自动更新会另行说明下载地址和开关，不属于服务商额度查询。

### 开发

`make run`通过`Scripts/run-app.sh`只停止当前工作区构建目录中的应用，再构建和启动；
不会按进程名关闭其他工作区或Applications中的Waterline。若旧实例未退出，停止重建并报错。

参考工具链为Xcode26.6、Swift6.3.x。2026-09-06在本机`/Applications/Xcode.app`验证到
Xcode26.6（17F113）、Swift6.3.3。`make`默认使用该路径；直接调用`xcrun`需显式指定。

```bash
DEVELOPER_DIR=/Applications/Xcode.app make verify
DEVELOPER_DIR=/Applications/Xcode.app make run
.build/debug/waterline version
.build/debug/waterline snapshot --json
.build/debug/waterline source list --json
make dmg
```

应用已通过共享AppModel连接引擎。已有Codex登录可查询真实额度；无快照时`snapshot`返回无数据。
本地开发包采用ad-hoc签名，并非已公证发行版；如macOS要求确认，请使用系统提供的打开流程。
不关闭系统安全检查。完整流程见[项目规则](AGENTS.md)。

---

## English

Waterline is a macOS notch/menu-bar app in development. It aims to discover existing AI coding accounts
and show provider-reported **allowance usage, reset times and prepaid balances** in one place.

- One row per account; credentials can rotate. Reconcile known duplicate sources, while keeping
  separate regional and billing identities distinct.
- Show reported values and documented deterministic calculations. Missing data stays missing;
  predictions carry `≈`.
- Keep one account logo and remaining allowance visible; click to expand, leave to close, and use pin to select the daily account. Use a floating capsule on displays without a notch. Stale readings
  retain their values and observation age.
- Judge balances against thresholds in their own currencies; never rank raw amounts across currencies.

### Status

As of 2026-09-06, the repository contains the SwiftPM scaffold, initial model/engine, snapshot store,
HTTP/Keychain boundaries and an initial engine-connected notch panel. The CLI implements `snapshot`,
`version`, `accounts` and initial `refresh`. Codex has a successful read-only CLI/live native display check.
The provider registry is empty; no live usage or balance integration has been delivered.

Planned coverage: Claude Code, Codex, Cursor and xAI in v0.1; Zhipu, Kimi Code, Moonshot, MiniMax and
DeepSeek plus history/estimates in v0.2; Antigravity, a Qwen capability review, full onboarding/Settings
and zh-Hans/en in v0.3. Actual metrics depend on verified endpoint capabilities.

See [provider evidence](docs/providers/README.md), [target architecture](ARCHITECTURE.md) and
[acceptance requirements](ACCEPTANCE.md). Planned support is not live verification.

### Privacy design

These are implementation and verification requirements, not a completed privacy audit of the scaffold:

- No Waterline backend, telemetry or crash-upload service. Send authentication and required account
  identifiers only to the corresponding service's permitted HTTPS endpoints.
- Read only named tool sources. Config scanning is opt-in per source and never executes shell files.
  Background Keychain operations never prompt.
- Never modify another tool's credentials. Manual keys belong in this app's own Keychain service.
- Normal state/history live under `~/Library/Application Support/Waterline/`; preferences use
  `UserDefaults`. Explicit diagnostic exports go to a user-selected directory. Raw responses may be
  private; handle separately, redact before sharing and never commit them.
- Do not depend on Full Disk Access. Explain inaccessible sources and the access needed for a connection.
- Future updates need a documented download policy and enable/disable choice beyond provider queries.

### Development

Reference toolchain: Xcode 26.6 / Swift 6.3.x. On 2026-09-06, `/Applications/Xcode.app` reported Xcode
26.6 (17F113), Swift 6.3.3. `make` defaults to that path; direct `xcrun` calls need the variable explicitly.

```bash
DEVELOPER_DIR=/Applications/Xcode.app make verify
DEVELOPER_DIR=/Applications/Xcode.app make run
.build/debug/waterline version
.build/debug/waterline snapshot --json
```

The app is wired to the engine; without an existing snapshot the last command
reports no data. Development bundles are ad-hoc signed, not notarised releases; follow the OS-provided
open flow if confirmation is requested, without disabling system security. See [project rules](AGENTS.md).

`make dmg` builds the Release configuration and creates a locally ad-hoc-signed development image
under `build/`, with an Applications link, bilingual installation notes and a SHA-256 sidecar. It
verifies image integrity but does not notarize or publish the artifact. Developer ID signing,
notarization and clean-machine Gatekeeper/installation checks remain required for distribution.

`make distribution-check` is a separate read-only gate for the existing production app bundle. It
requires Developer ID Application signing, hardened runtime, a secure timestamp, a stable version,
a stapled notarization ticket and enabled Gatekeeper assessment without a local override. It is
expected to fail for the current development artifact. An explicit `WATERLINE_SIGNING_IDENTITY`
enables Developer ID signing in `CONFIGURATION=release make app`; debug signing is rejected before
replacing the app. Without it, signing remains ad-hoc. The real identity path
is not verified on this machine. Secure timestamping is build-time Apple service traffic, not runtime
app telemetry. This check neither uploads for notarization nor publishes a release.

The offline resource harness is separate: `make verification-test` checks its isolated dependencies;
`make verification-app` builds `build/WaterlineVerification.app` with a distinct bundle identifier.
Launch it with `--verification-run-id <UUID>` to use that run's directory under the system temporary
folder's `WaterlineVerification/<UUID>/`. It contains exactly four synthetic accounts and rejects
network/Keychain operations. Its headline/menu identify test data; connections and external console
links are disabled. Production builds reject verification flags. Use `Scripts/measure-runtime.py`
with `--scope fixtures`, the exact process/executable and that run's snapshot to collect the standard
600 s warm-up plus 600 one-second samples. Real-account measurements use `--scope real`.

The verification app also accepts `--verification-render` to export its own synthetic island view
to `island.png` in the run directory and exit. `--verification-long-labels` exercises truncation;
process-local `-AppleLanguages '(zh-Hans)'` selects Chinese. This renders only the app's own view,
not desktop content, and does not validate real hover/focus or screen placement.
`--verification-unsupported` supplies an explicit synthetic capability-state scenario for rendering;
it is not the four-kind resource benchmark and does not describe a real provider account.
`--verification-expired-secondary` renders a current quota alongside an expired supplementary quota
to inspect text status and compact mixed-freshness layout.
`--verification-component-failure --verification-detail` renders a named partial failure in account
details. All such scenarios are synthetic and retain the verification provenance.
`--verification-route-account` and `--verification-route-missing` exercise the account-navigation
render states; they do not send notifications or establish OS notification-click behavior.

### Acknowledgements

Design references, read but not copied: [CodexBar](https://github.com/steipete/CodexBar) (MIT),
[boring.notch](https://github.com/TheBoredTeam/boring.notch) and
[open-vibe-island](https://github.com/Octane0411/open-vibe-island) (GPL-3),
[dsh-provider-balance](https://github.com/aka-danielZhang/dsh-provider-balance) and
[claude-token-monitor](https://github.com/young1lin/claude-token-monitor).
Provider contracts must cite the exact evidence used when implemented. Project licence: MIT; review
third-party licences separately before incorporating code or dependencies.


### Current CLI exit codes

Optional process sources use `source enable|disable|check deepseek-env [--json]`. Enabling is explicit
consent for the inherited environment source; it never accepts a key argument. `source list [--json]`
reads canonical saved consent without discovery/network requests. A missing optional source returns
exit 2 even if another manual account for that provider is healthy. Disabled sources are shown paused.
`deepseek-claude-settings` separately enables the direct DeepSeek declaration in global Claude Code
settings. Both sources remain off by default; source checks never execute shell/config commands.

`0`: command completed; `1`: storage or unexpected operation failure; `2`: no saved data, unknown
account, or one or more requested refreshes failed (JSON may still contain valid partial data);
`3`: another engine owns the writer lock; `64`: invalid arguments or unavailable provider command.
`connect` announces the saved-login read and may show a native Keychain access prompt. It never
refreshes another tool's authentication credentials.


### Manual balance accounts (development build)

Settings → Accounts → DeepSeek → Add key stores a key only in Waterline's own Keychain service.
Existing manual accounts offer Update key; their ID, name and pin are preserved. The CLI also accepts
`account add deepseek --stdin [--json]` and `account key <id> --stdin [--json]`, with input piped from
an appropriate local secret source. It rejects echoing terminal input and never accepts a key argument.
If key deletion fails, Privacy settings exposes a retry; startup also retries pending cleanup.
This flow has offline integration coverage. Native Keychain writes and real DeepSeek balances remain
unverified; this is not a release-readiness claim.

### Notarization preparation

`bash Scripts/notarize-app.sh --check build/Waterline.app` runs submission preflight
without contacting Apple. It must reject development/ad-hoc bundles. The full
`make distribution-check` still requires a stapled ticket and Gatekeeper acceptance.

Once a stable Release is signed with the intended Developer ID and an existing
notarytool Keychain profile is available, invoke `Scripts/notarize-app.sh` with the
source app, profile name and a new output-app path. It submits a staged ZIP, preserves
Apple's result beside the output path, staples and validates an accepted app, and leaves
the source bundle unchanged. This step does not publish a GitHub release, build a
Homebrew cask or establish clean-install acceptance. Those remain separate requirements.

### Homebrew cask preparation

`python3 Scripts/generate-cask.py SIGNED_DMG --url VERSIONED_RELEASE_URL --output Casks/waterline.rb`
checks the DMG signature/ticket, mounts it read-only, validates its actual application,
and generates a cask with the artifact SHA-256, macOS minimum and actual CPU architectures.
It accepts only this project's versioned HTTPS GitHub asset URLs and never installs or
publishes anything. The source DMG must already be a validated stable release; development
DMGs are rejected. Online Homebrew audit and clean installation remain required after
publication. Format reference: [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook).

The application bundle now includes `Contents/MacOS/waterline`, signed before the outer
app. Its version is checked against the app in local packaging verification; distribution
checks inspect its signature, signing team, architecture and deployment target without
executing a downloaded artifact. Generated Homebrew casks link this helper as `waterline`.
Read-only snapshot commands remain available while the app runs; commands that need the
writer lock require the running app to exit first.
