# Waterline · 水位

**中文** · [English](#english)

Waterline 是一个 macOS 原生的刘海/菜单栏小工具：自动发现本机已登录的 AI 编码工具账户，把每个账户的
**订阅窗口**（已用百分比、何时重置）或**充值余额**（金额、消耗速度）放在刘海两侧，一眼看完。

- 本地优先：只读各工具已经存在本机的凭证，不注册账号，不上传任何数据。
- 一个账户一行，以凭证为准：Kimi Code 订阅和 Moonshot 充值是两行；经网关转发的调用不算在你的账户上。
- 只显示厂商接口真实返回的数字；估算值一律标 `≈`；接口失效时显示原因，不显示 0。
- 覆盖：Claude Code、Codex、Cursor、xAI、智谱 GLM、Kimi Code、Moonshot、MiniMax、DeepSeek、Antigravity；Qwen 因无接口标注为不支持。

### 隐私承诺

- 不需要完全磁盘访问权限；Keychain 只读，且只读明确列出的条目；后台刷新永远不会弹出授权框。
- 唯一的外部请求是各厂商自己的额度/余额接口；每个适配器的允许域名硬编码，`URLSessionHTTPClient` 拦截其他一切。
- 你手动填入的 key 只存在本 App 自己的 Keychain 条目里；磁盘上只写 `~/Library/Application Support/Waterline/`。
- 零遥测，零崩溃上报。

### 状态

v0.1 开发中（Claude Code / Codex / Cursor / xAI）。路线图见 `ARCHITECTURE.md`，验收标准见 `ACCEPTANCE.md`。

### 开发

需要 Xcode 26.6（仓库所有命令固定 `DEVELOPER_DIR=/Applications/Xcode.app`）。

```bash
make verify   # build + test + swift-format lint + whitespace + audit；CI 跑的就是它
make run      # 打包 build/Waterline.app 并启动
.build/debug/waterline snapshot --json
```

首次打开 `build/Waterline.app` 会被 Gatekeeper 拦下（v0.x 为 ad-hoc 签名）：右键 → 打开一次即可。

---

## English

Waterline is a native macOS notch/menu-bar utility. It discovers the AI coding tool accounts already
signed in on this machine and shows, beside the notch, each account's **subscription window**
(percent used, when it resets) or **prepaid balance** (amount, burn rate).

- Local-first: reads credentials the tools already stored, needs no account of its own, uploads nothing.
- One row per credential, not per vendor: a Kimi Code subscription and a Moonshot top-up are two rows;
  calls routed through a gateway are never charged to your account in the display.
- Only numbers the provider returned are shown; estimates carry `≈`; a broken endpoint shows its
  reason, never a zero.
- Covers Claude Code, Codex, Cursor, xAI, Zhipu GLM, Kimi Code, Moonshot, MiniMax, DeepSeek,
  Antigravity; Qwen is listed as unsupported because Bailian has no balance API.

### Privacy

- No Full Disk Access. Keychain reads are limited to listed items and never prompt in the background.
- The only outbound requests are the vendors' own usage/balance endpoints; each adapter's hosts are
  hard-coded and `URLSessionHTTPClient` refuses everything else.
- Keys you type are stored only in this app's own Keychain entries; the only files written live under
  `~/Library/Application Support/Waterline/`.
- No telemetry, no crash reporting.

### Status

v0.1 in progress (Claude Code / Codex / Cursor / xAI). Roadmap in `ARCHITECTURE.md`, acceptance in
`ACCEPTANCE.md`, work queue in GitHub Issues.

### Development

Xcode 26.6; every command pins `DEVELOPER_DIR=/Applications/Xcode.app`.

```bash
make verify   # build + test + swift-format lint + whitespace + audit — exactly what CI runs
make run      # bundle build/Waterline.app and launch it
.build/debug/waterline snapshot --json
```

Gatekeeper blocks the first launch of an ad-hoc signed `Waterline.app`: right-click → Open once.

### Acknowledgements

Design references, read but not copied: [CodexBar](https://github.com/steipete/CodexBar) (MIT) for
credential discovery and provider strategy, [boring.notch](https://github.com/TheBoredTeam/boring.notch)
and [open-vibe-island](https://github.com/Octane0411/open-vibe-island) (GPL-3) for notch interaction,
[dsh-provider-balance](https://github.com/aka-danielZhang/dsh-provider-balance) and
[claude-token-monitor](https://github.com/young1lin/claude-token-monitor) for Chinese provider endpoints.

MIT licence.
