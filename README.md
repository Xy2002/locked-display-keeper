# Locked Display Keeper

让 Mac **锁屏后继续亮屏**。适用于立即锁屏、远程软件断开后锁屏等场景。

A small macOS helper that keeps the display awake while your session is locked, then releases its power assertion after you unlock.

它在当前用户锁屏时申请系统防熄屏请求，解锁后释放。随登录启动，不修改密码、屏保计时或系统电源设置，不模拟鼠标和键盘，也不需要网络连接。

## 快速安装

需要 macOS 13 或更新版本，以及已登录的图形桌面会话。最低版本是编译目标，不代表所有版本都经过实机验证；已验证范围见下文。

### 下载现成安装包

1. 前往 [Releases](https://github.com/Xy2002/locked-display-keeper/releases/latest)，下载 `locked-display-keeper-0.1.0-macos-universal.zip` 并解压。
2. 打开终端，进入解压后的目录，执行：

```bash
./install.sh
./manage.sh status
```

通用安装包同时包含 Apple Silicon 和 Intel 架构，无需安装 Xcode。二进制仅做了本地 ad-hoc 签名，**没有 Apple Developer ID 签名或公证**。如果 macOS 拦截运行，请使用下面的源码安装方式，不要关闭 Gatekeeper。

发布页也提供 `.sha256` 文件。将它和 ZIP 放在同一目录后，可以核对下载是否完整：

```bash
shasum -a 256 -c locked-display-keeper-0.1.0-macos-universal.zip.sha256
```

### 从源码安装

先确保已安装 Apple Command Line Tools。没有安装时，在终端执行 `xcode-select --install` 并完成系统安装提示，然后：

```bash
git clone https://github.com/Xy2002/locked-display-keeper.git
cd locked-display-keeper
./install.sh
./manage.sh status
```

源码安装会在本机用 Swift 编译。整个安装过程使用当前账户，**不要加 `sudo`**。重复运行安装命令会更新本工具并重新启动服务。

## 怎么使用

安装成功后，直接按 `Control + Command + Q` 锁屏，或让远程软件在断开时锁屏。服务会在检测到锁定后保持显示器亮着，解锁仍按 macOS 原有方式验证。

如果还想闲置后自动锁屏，请在系统设置中配置：

- 屏幕保护程序：按需设置，例如闲置 2 分钟后启动。
- “屏幕保护程序启动或显示器关闭后需要密码”：立即。
- 闲置关闭显示器：按需设置；要一直亮屏可选“永不”。

本工具不会替你设置自动锁屏时间。不同 macOS 版本的屏保选项位置可能不同。

### 管理服务

在下载包或源码目录中执行：

```bash
./manage.sh status     # 是否运行，以及当前防熄屏请求
./manage.sh logs       # 最近 50 行状态日志
./manage.sh stop       # 停止，并禁用后续登录自启
./manage.sh start      # 恢复运行和登录自启
./manage.sh uninstall  # 卸载服务和程序，保留日志
```

安装后可以删除下载包或源码目录。管理脚本也保存在安装目录，例如：

```bash
"$HOME/Library/Application Support/LockedDisplayKeeper/manage.sh" stop
```

安装位置：

| 内容 | 当前用户目录下的位置 |
| --- | --- |
| 程序与管理脚本 | `~/Library/Application Support/LockedDisplayKeeper/` |
| 登录服务 | `~/Library/LaunchAgents/local.user.locked-display-keeper.plist` |
| 状态日志 | `~/Library/Logs/LockedDisplayKeeper.log` |

停止或卸载后，macOS 会恢复原有的锁屏熄屏行为。日志只记录锁定状态、请求状态和时间，不读取密码或桌面内容；日志保存在本机，不自动上传。

## 为什么“永不熄屏”还会黑屏

这个工具源于一次 UU 远程排查。实际日志显示，远程连接结束后，UU 发起立即锁屏，macOS 的登录窗口启用独立的 5 秒超时，随后关闭显示器。该次行为没有被“闲置关闭显示器：永不”阻止。

Locked Display Keeper 在锁定期间持有 `PreventUserIdleDisplaySleep` 请求。实测登录窗口在准备熄屏时会检查这类请求，并推迟熄屏。

这是一个实际观察到的触发链，不保证所有 macOS 版本、远程软件或黑屏问题都出于同一原因。

## 验证与限制

### 已观察到的行为

开发验证设备为 Mac mini M4，macOS 27.0，build `26A428`：

- 锁定状态下，连续多个 30 秒超时周期均被本工具的防熄屏请求阻止。
- 解锁后释放防熄屏请求；再次锁屏后重新申请，已重复观察。
- 本地程序运行和系统日志相互印证。屏幕保持亮着时，锁定状态仍然存在。

仓库的 CI 检查构建、命令行参数、限时运行退出和脚本语法。**CI 通过不等于实际显示器、远程断连或屏保行为已验证。** Intel 架构及其他 macOS 版本的锁屏行为仍需实机验证。

### 安装后的实测方法

1. 运行 `./manage.sh logs`，确认服务启动。
2. 锁屏或断开远程，保持锁定至少 60 秒，期间不要使用触控 ID、Apple Watch 或密码解锁。
3. 确认显示器保持亮着，恢复桌面仍需要验证。
4. 解锁后查看日志，应出现 `display_assertion=off`。
5. 再次锁屏，应出现 `display_assertion=on`。

如果要验证“闲置自动锁屏”，还需要单独等待你设置的屏保时间。播放视频、远程连接或其他应用持有的防休眠请求可能影响该测试。

### 适用边界

- 只在当前用户的控制台会话锁定时保持显示器亮着。关机、主动睡眠、合盖、显示器断电或硬件连接中断仍可熄屏。
- 如果服务启动前显示器已经关闭，它不会主动点亮显示器。正常唤醒屏幕后即可生效。
- 锁定判断使用系统会话字典中的 `CGSSessionScreenIsLocked` 和分布式通知。这些锁定标识不属于 Apple 承诺稳定的公开接口，系统升级后需要重新验证。
- 启动前的 FileVault 解锁画面和注销后的登录窗口不在用户级服务的工作范围内。快速用户切换尚未实测。
- 长时间亮屏会增加耗电；对 OLED 显示器，应结合显示器自身说明安排使用时间。

## 故障排查

先执行：

```bash
./manage.sh status
./manage.sh logs
pmset -g assertions
```

锁定时，应能看到名为 `Keep display on while screen is locked` 的请求。解锁后，本工具的该请求应消失；其他应用的请求可能仍然存在。

如果服务显示没有加载，执行 `./manage.sh start`。如果日志持续出现 `session=unavailable`，确认你已登录 Mac 图形桌面；SSH、CI 或受限沙箱中的直接运行可能读不到会话。

提交 Issue 时请提供 macOS 版本、芯片类型、显示器连接方式、锁屏方式和相关日志片段。不要上传密码、设备识别码或完整系统日志。

## 开发

无第三方依赖，使用系统 Foundation、CoreGraphics 和 IOKit。

```bash
./scripts/build.sh            # 本机架构
./tests/smoke.sh              # 不改变安装配置
./scripts/package.sh         # Apple Silicon + Intel 通用 ZIP 和 SHA-256
.build/LockedDisplayKeeper --duration 60  # 前台限时运行，退出时释放请求
```

服务监听锁定/解锁通知，并每秒核对会话状态以补偿丢失的通知。正常退出会释放电源请求；进程意外退出时，由系统清理其请求，LaunchAgent 会尝试重启服务。

相关资料：[Apple 电源管理接口](https://developer.apple.com/documentation/iokit/iopmlib_h/iopmassertiontypes)、[Apple 屏幕保护程序说明](https://support.apple.com/guide/mac-help/mchl4b68853d/mac)。

## 许可证

[MIT](LICENSE)。欢迎反馈其他机型和 macOS 版本的验证结果。
