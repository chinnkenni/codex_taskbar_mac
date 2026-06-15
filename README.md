# Codex Taskbar

Codex Taskbar 是一个原生 macOS 菜单栏小工具，用来显示 Codex 本地用量限制。

[English](#english)

![Codex Taskbar 菜单栏标题](docs/images/menu-bar-title.png)

它会读取本机 Codex 日志数据库，并显示 Codex 设置里同样的两个额度窗口：

- 5 小时窗口的剩余额度和重置时间
- 1 周窗口的剩余额度和重置时间

应用不会联网发送数据，只读取本机 Codex SQLite 日志数据库。

## 功能

- 原生 macOS 菜单栏应用
- 不依赖 SwiftBar
- 支持 5 秒、15 秒、60 秒刷新间隔
- 支持紧凑 / 详细两种标题样式
- 可选择是否在标题中显示 5 小时重置时间
- 可选择是否在标题中显示 1 周重置时间
- 支持开机启动
- 支持检查 GitHub Releases 更新
- 一键复制当前状态
- 对无数据、无日志、解析失败等状态有提示

## 截图

![Codex Taskbar 下拉菜单](docs/images/menu-dropdown.png)

菜单栏标题可以同时显示两个窗口和对应重置时间：

```text
5h 71% 22:57 | 1w 86% 6月22日
```

如果想让菜单栏更短，也可以在菜单中分别隐藏 5 小时或 1 周的重置时间。

## 构建

```bash
./scripts/build-app.sh
```

构建后的 App 会生成在：

```text
build/Codex Taskbar.app
```

## 打包

```bash
./scripts/package-dmg.sh
```

安装包会生成在：

```text
dist/Codex-Taskbar.dmg
```

## 运行

```bash
open "build/Codex Taskbar.app"
```

如果启动后暂时没有显示用量，可以先在 Codex 中运行 `/status`，或者发送一条 Codex 消息，让本地 rate-limit 事件刷新。

## 安装与安全提示

当前 Release 是未公证版本。它使用 ad-hoc 签名保证 App bundle 内部完整性，但没有 Apple Developer ID 签名和 Apple 公证。

这是因为当前项目还没有 Apple Developer 账号签发的 Developer ID 证书和 Apple 公证。首次打开时，macOS 可能会显示下面的 Gatekeeper 提示：

![Gatekeeper 拦截提示](docs/images/gatekeeper-blocked.png)

可以按下面步骤手动允许打开：

1. 在弹窗右上角点击 `?` 问号图标，打开 Apple 帮助说明。

   ![Apple 帮助说明](docs/images/gatekeeper-help.png)

2. 在帮助说明中点击蓝色链接 `为我打开“隐私与安全性”设置`。

3. 在系统设置的 `隐私与安全性` 页面向下找到 `安全性`，点击 `仍要打开`。

   ![隐私与安全性中点击仍要打开](docs/images/privacy-security-open-anyway.png)

4. 再次弹出确认窗口时，点击 `仍要打开`，并按系统提示输入登录密码。

   ![确认仍要打开](docs/images/gatekeeper-open-anyway-confirm.png)

完成后，`Codex Taskbar` 会被加入本机安全例外，之后可以像普通 App 一样打开。

如果 GUI 流程仍然被拦截，也可以使用终端移除隔离标记：

```bash
xattr -dr com.apple.quarantine "/Applications/Codex Taskbar.app"
open "/Applications/Codex Taskbar.app"
```

后续如果提供 Apple Developer ID 证书和公证凭据，可以改为正式签名和公证分发，安装时就不会出现这类 Gatekeeper 提示。

## 数据来源

Codex Taskbar 会查找：

```text
~/.codex/sqlite/logs_2.sqlite
~/.codex/logs_2.sqlite
```

它读取最新的 `codex.rate_limits` websocket 事件，并提取其中的 `primary` 和 `secondary` 两个额度窗口。

## 开机启动

使用菜单里的 `开机启动` 选项，可以把 Codex Taskbar 添加到 macOS 登录项，或从登录项中移除。较新的 macOS 版本第一次注册时，可能需要在系统设置中批准。

## Bartender 显示

Codex Taskbar 是文本型菜单栏项目，正常情况下在 Bartender 中应该显示类似：

```text
5h 71% 22:57 | 1w 86% 6月22日
```

如果 Bartender 中显示成灰色方块，通常表示它没有拿到稳定的菜单栏文字，或者该项目被放进了隐藏/始终隐藏区域。v0.1.2 起，App 会在启动和无数据状态下始终提供文本标题 `5h -- | 1w --`，并显式禁用状态栏图片，避免 Bartender 退回图标占位。

如果仍然显示异常：

1. 退出并重新打开 `Codex Taskbar`。
2. 在 Bartender 里把 `Codex Taskbar` 放到 `显示的项目`。
3. 打开 Codex 并运行 `/status`，或发送一条 Codex 消息，让本地用量事件刷新。

## 版本与更新

应用版本号由仓库根目录的 `VERSION` 文件管理，构建脚本会把它写入 App 的 `Info.plist`。

Codex Taskbar 会每天自动检查一次 GitHub Releases 最新版本，也可以在菜单中手动点击 `检查更新`。如果发现新版本，菜单中会显示更新提示，并可打开最新 Release 下载页面。

## 说明

这是一个非官方本地工具。Codex 本地日志格式未来可能变化，如果日志字段变更，应用可能需要同步更新解析逻辑。

---

## English

Codex Taskbar is a small native macOS menu bar app for showing local Codex usage limits.

![Codex Taskbar menu bar title](docs/images/menu-bar-title.png)

It reads the local Codex log database and displays the same two limit windows shown in Codex settings:

- 5-hour remaining usage and reset time
- 1-week remaining usage and reset time

The app does not send data over the network. It only reads the local Codex SQLite log database.

### Features

- Native macOS menu bar app
- No SwiftBar dependency
- 5-second, 15-second, or 60-second refresh interval
- Compact or detailed menu bar title
- Optional 5-hour reset time in the title
- Optional 1-week reset time in the title
- Launch at login toggle
- GitHub Releases update check
- One-click status copy
- Graceful empty and error states

### Screenshot

![Codex Taskbar dropdown menu](docs/images/menu-dropdown.png)

The menu bar title can show both windows and either reset time:

```text
5h 71% 22:57 | 1w 86% 6月22日
```

You can hide either reset time from the menu title if you prefer a shorter display.

### Build

```bash
./scripts/build-app.sh
```

The app bundle will be created at:

```text
build/Codex Taskbar.app
```

### Package

```bash
./scripts/package-dmg.sh
```

The distributable disk image will be created at:

```text
dist/Codex-Taskbar.dmg
```

### Run

```bash
open "build/Codex Taskbar.app"
```

If no usage appears yet, open Codex and run `/status` or send one Codex message so the local rate-limit event is refreshed.

### Installation and Security Notice

The current Release is not notarized. It uses an ad-hoc signature for bundle integrity, but it is not signed with an Apple Developer ID certificate and has not been notarized by Apple.

This is because the project does not yet have an Apple Developer ID certificate and Apple notarization. On first launch, macOS may show this Gatekeeper prompt:

![Gatekeeper blocked prompt](docs/images/gatekeeper-blocked.png)

To allow the app:

1. Click the `?` icon in the upper-right corner of the warning dialog.
2. In the Apple Help page, click the blue `Privacy & Security` quick link.

   ![Apple Help page](docs/images/gatekeeper-help.png)

3. In `System Settings` > `Privacy & Security`, scroll to `Security`, then click `Open Anyway`.

   ![Privacy & Security open anyway](docs/images/privacy-security-open-anyway.png)

4. In the confirmation dialog, click `Open Anyway` and enter your login password when prompted.

   ![Confirm open anyway](docs/images/gatekeeper-open-anyway-confirm.png)

After that, Codex Taskbar is saved as a local security exception and can be opened normally.

If the GUI flow is still blocked, remove the quarantine flag manually:

```bash
xattr -dr com.apple.quarantine "/Applications/Codex Taskbar.app"
open "/Applications/Codex Taskbar.app"
```

With an Apple Developer ID certificate and notarization credentials, future releases can be signed and notarized so this Gatekeeper warning does not appear.

### Data Source

Codex Taskbar looks for:

```text
~/.codex/sqlite/logs_2.sqlite
~/.codex/logs_2.sqlite
```

It reads the newest `codex.rate_limits` websocket event and extracts the `primary` and `secondary` rate-limit windows.

### Login Item

Use the `开机启动` menu item to add or remove Codex Taskbar from macOS Login Items. On recent macOS versions, the first registration may require approval in System Settings.

### Bartender Display

Codex Taskbar is a text-based menu bar item. In Bartender, it should normally look like:

```text
5h 71% 22:57 | 1w 86% 6月22日
```

If Bartender shows a gray square, it usually means Bartender did not receive a stable text title, or the item was moved into a hidden section. Since v0.1.2, the app always provides a text title, including the no-data state `5h -- | 1w --`, and explicitly disables status item images so Bartender does not fall back to an icon placeholder.

If it still looks wrong:

1. Quit and reopen `Codex Taskbar`.
2. Move `Codex Taskbar` into Bartender's visible items.
3. Open Codex and run `/status`, or send one Codex message to refresh the local usage event.

### Versioning and Updates

The app version is managed by the root `VERSION` file. The build script writes that version into the app `Info.plist`.

Codex Taskbar checks the latest GitHub Release once per day. You can also use `检查更新` from the menu. When a newer release is available, the menu shows an update prompt and opens the latest Release download page.

### Notes

This is an unofficial local utility. The Codex local log format may change in future Codex releases.
