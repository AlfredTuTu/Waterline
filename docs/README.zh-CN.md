# Waterline

[English](../README.md) · 简体中文

在 Mac 灵动岛和菜单栏查看订阅用量。

## 安装

从 [Releases](https://github.com/AlfredTuTu/Waterline/releases/latest) 下载
**Waterline-0.1.0-arm64.dmg**，打开后将 Waterline 拖入应用程序。需要 Apple Silicon 和 macOS 14 或更新版本。

首次打开若被 macOS 拦截，请前往 **系统设置 → 隐私与安全性 → 仍要打开**。
更新时退出 Waterline，再用新版应用替换即可。

## 日常使用

- 最小灵动岛显示选定账号的图标和剩余额度百分比。
- 点击展开账号卡片，拖动调整顺序，修改自动保存。
- 通过图钉菜单选择日常显示的账号。
- 底部 Waterline 菜单提供账号排序、收起和退出。
- 在 macOS 菜单栏菜单中切换语言。

首次启动自动连接本机已保存的登录；macOS 请求钥匙串访问时，按提示授权即可。

## 支持的账号

| 账号 | 登录来源 | 用量 |
| --- | --- | --- |
| ChatGPT / Codex | Codex 保存的登录 | 订阅额度窗口 |
| Claude Code | 保存的登录、Claude 桌面历史与 CLI 状态栏 | 5 小时、周及其他已报告的窗口 |
| Cursor | 本机 Cursor 登录 | 套餐及模型额度池 |
| Grok / SuperGrok | Grok Build 保存的个人登录 | 订阅用量 |
| Antigravity | 原生 CLI 保存的登录 | Gemini 与 Claude/GPT 额度组 |

## 刷新

账号通常每 60 秒自动刷新。Claude 还会读取匹配的桌面历史和新建 Claude Code 会话的状态栏数据；
其网络备用查询最多每 5 分钟一次。已有的自定义 Claude 状态栏会保留。遇到服务商限流后，自动恢复更新。

登录来源和刷新细节见[账号接入说明](providers/README.md)。

## 构建

使用 `/Applications/Xcode.app` 中的 Xcode 26.6 / Swift 6.3。

```sh
make verify
CONFIGURATION=release make app
make run
```

应用生成在 `build/Waterline.app`。`make verify` 执行构建、测试、格式和仓库检查，测试使用隔离数据。
读取已保存的用量快照：

```sh
.build/debug/waterline snapshot --json
```

## 项目结构

- `app/`：Swift 工程、原生应用、资源和测试。
- `tools/`：构建、打包和验证工具。
- `docs/`：账号接入、界面规则和发布证据。

[界面规则](ui.md) · [发布证据](release-readiness.md) · [许可证](../LICENSE)
