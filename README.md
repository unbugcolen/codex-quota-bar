# CodexQuotaBar

macOS 菜单栏 + Touch Bar 小应用，用本机 Codex app-server 读取额度，不抓网页。

## 运行

```bash
cd ./codex-quota-bar
swift run
```

## 打包成菜单栏 App

```bash
cd ./codex-quota-bar
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open .build/release/CodexQuotaBar.app
```

应用每次刷新会通过 macOS Launch Services，按 Bundle ID `com.openai.codex` 查找已安装的 ChatGPT/Codex 应用，并按以下顺序检查应用包内的 CLI：

1. `Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`（新版签名 CLI）
2. `Contents/Resources/codex-cli/bin/codex`（新版启动入口）
3. `Contents/Resources/codex`（旧版布局）

如果 Launch Services 未返回可用的内置 CLI，则依次在 `/Applications/ChatGPT.app` 和 `/Applications/Codex.app` 中检查这些路径。

随后启动 `codex app-server --listen stdio://`，等待 `initialize` 成功，发送 `initialized` 通知，再请求 `account/rateLimits/read`。读取进程保留已有代理环境；缺少对应代理环境变量时，会采用 macOS 系统 HTTP/HTTPS 代理及排除列表，支持从 Finder 或登录项启动。

界面在新数据回来后才替换旧数据；刷新失败时保留已有额度，仅显示错误状态。5 小时与周额度按服务返回的窗口长度识别；只有周额度时，5 小时显示 `--`，避免把周额度重复显示为 5 小时额度。

在设置中取消勾选“显示 5 小时额度”，即可只显示周额度。开关会立即更新菜单栏、弹窗和 Touch Bar，并在重启后保留；关闭时双条进度改为单条周额度进度，弹窗同步缩短。

在设置中勾选“开机自动启动”，应用会在当前账户登录 macOS 后自动运行。开关直接读取系统登录项状态；如果需要系统允许，会显示“等待系统允许”，点击“去设置”即可打开登录项设置。取消勾选会移除登录启动项。

此功能使用 macOS 13 起提供的 [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)。请使用打包后的 `.app`；打包脚本会进行本机临时签名。建议将 `.app` 放到“应用程序”目录后再启用，以免清理构建目录时删除应用。
