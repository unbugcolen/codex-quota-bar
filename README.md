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

应用每次刷新会通过 macOS Launch Services，按 Bundle ID `com.openai.codex` 查找已安装的 ChatGPT/Codex 应用，然后启动应用包中的 `Contents/Resources/codex app-server --listen stdio://`。如果 Launch Services 未返回可用的内置 CLI，则依次检查新版 `/Applications/ChatGPT.app/Contents/Resources/codex` 和旧版 `/Applications/Codex.app/Contents/Resources/codex`。

随后发送 `initialize` 和 `account/rateLimits/read` 两个 JSON-RPC 请求。界面在新数据回来后才替换旧数据；刷新失败时保留已有额度，仅显示错误状态。
