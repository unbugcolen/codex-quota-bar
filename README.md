# CodexQuotaBar

macOS 菜单栏 + Touch Bar 小应用，用本机 Codex app-server 读取额度，不抓网页。

## 运行

```bash
cd /Users/colen/code/CodexQuotaBar
swift run
```

## 打包成菜单栏 App

```bash
cd /Users/colen/code/CodexQuotaBar
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open .build/release/CodexQuotaBar.app
```

应用每次刷新会启动：

```bash
/Applications/Codex.app/Contents/Resources/codex app-server --listen stdio://
```

随后发送 `initialize` 和 `account/rateLimits/read` 两个 JSON-RPC 请求。界面在新数据回来后才替换旧数据；刷新失败时保留已有额度，仅显示错误状态。
