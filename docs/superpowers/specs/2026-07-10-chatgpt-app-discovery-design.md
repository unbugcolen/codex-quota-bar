# ChatGPT App 动态发现设计

## 背景

CodexQuotaBar 当前将额度读取程序固定为
`/Applications/Codex.app/Contents/Resources/codex`。Codex 桌面应用更新为 ChatGPT 后，应用包变为
`ChatGPT.app`，导致原路径不存在，额度刷新在启动 app-server 前即失败。

本机验证表明新版 ChatGPT 仍内置 `Contents/Resources/codex`，Bundle ID 仍为
`com.openai.codex`，`account/rateLimits/read` RPC 及现有额度响应结构保持兼容。因此本次只修复可执行文件发现，不调整额度协议或展示口径。

## 目标

- 使用 macOS Launch Services 动态定位 Bundle ID 为 `com.openai.codex` 的桌面应用。
- 同时兼容新版 `ChatGPT.app` 和旧版 `Codex.app`。
- 在 Launch Services 暂时无法返回安装位置时保留固定路径兜底。
- 对“应用不存在”和“应用存在但内置 CLI 不可执行”提供可理解的错误信息。

## 非目标

- 不抓取 ChatGPT 网页或浏览器会话。
- 不改变 JSON-RPC 方法、额度窗口选择或百分比计算。
- 不增加用户配置项或设置界面。
- 不展示响应中新出现的重置额度或其他模型额度。

## 设计

新增一个职责单一、可测试的可执行文件定位组件。生产环境通过 `NSWorkspace` 按 Bundle ID 查询应用 URL，并在应用包中查找 `Contents/Resources/codex`。定位器按以下顺序解析：

1. Launch Services 返回的应用包内 CLI。
2. `/Applications/ChatGPT.app/Contents/Resources/codex`。
3. `/Applications/Codex.app/Contents/Resources/codex`。

只有通过 `FileManager.isExecutableFile(atPath:)` 验证的候选路径才能返回。候选路径去重，避免动态路径与固定路径相同时重复检查。

`CodexRateLimitFetcher` 在每次刷新开始时调用定位器，再把解析出的路径交给现有 `RateLimitFetchOperation`。每次刷新重新解析，可以正确处理应用更新、重命名或移动，而无需重启 CodexQuotaBar。现有 app-server 生命周期、超时和 JSON-RPC 解析逻辑保持不变。

为便于单元测试，定位组件接收“按 Bundle ID 查询 URL”和“判断文件是否可执行”的依赖；生产环境使用 `NSWorkspace` 与 `FileManager`，测试使用确定性闭包，不访问真实 `/Applications`。

## 错误处理

如果没有可执行候选项，错误信息说明未找到 ChatGPT/Codex 内置的 `codex` 程序，并列出已检查的动态或固定候选路径。现有界面继续保留上次成功额度，仅在首次读取失败时显示错误状态。

## 测试

增加 Swift Package 测试目标，覆盖：

- Launch Services 返回有效应用时优先使用其内置 CLI。
- 动态候选无效时回退新版 ChatGPT 固定路径。
- 新版路径无效时回退旧版 Codex 固定路径。
- 所有候选均无效时返回包含检查路径的定位错误。
- 动态候选与固定候选相同时不会重复检查。

完成后运行聚焦单元测试和 `swift build`，并用当前安装的 ChatGPT 应用执行一次真实额度读取验证。

## 文档

README 改为说明通过 Launch Services 动态发现 ChatGPT/Codex，并保留两个标准安装路径作为兜底；额度读取仍只使用本机 app-server。
