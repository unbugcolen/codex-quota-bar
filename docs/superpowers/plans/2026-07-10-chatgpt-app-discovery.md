# ChatGPT App Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make CodexQuotaBar dynamically find the renamed ChatGPT desktop app while retaining compatibility with the legacy Codex app.

**Architecture:** Introduce a small `CodexExecutableLocator` that asks Launch Services for the `com.openai.codex` application, then checks the ChatGPT and Codex standard paths as fallbacks. Inject the locator into the existing fetcher so RPC transport and quota decoding remain unchanged.

**Tech Stack:** Swift 5.9, AppKit `NSWorkspace`, Foundation `FileManager`, Swift Package Manager, XCTest

---

## File Structure

- Create `Sources/CodexQuotaBar/CodexExecutableLocator.swift`: resolve and validate dynamic and fallback CLI paths.
- Modify `Sources/CodexQuotaBar/CodexRateLimitFetcher.swift`: resolve the executable at fetch time and preserve the current app-server operation.
- Modify `Package.swift`: add the XCTest target.
- Create `Tests/CodexQuotaBarTests/CodexExecutableLocatorTests.swift`: cover priority, fallback, deduplication, and failure details.
- Modify `README.md`: document dynamic ChatGPT/Codex discovery.

### Task 1: Add the executable locator contract and priority behavior

**Files:**
- Modify: `Package.swift`
- Create: `Tests/CodexQuotaBarTests/CodexExecutableLocatorTests.swift`
- Create: `Sources/CodexQuotaBar/CodexExecutableLocator.swift`

- [ ] **Step 1: Add the test target and write the first failing test**

Add to `Package.swift` after the executable target:

```swift
.testTarget(
    name: "CodexQuotaBarTests",
    dependencies: ["CodexQuotaBar"]
)
```

Create the test file with a helper that records checks and the first behavior test:

```swift
import XCTest
@testable import CodexQuotaBar

final class CodexExecutableLocatorTests: XCTestCase {
    func testResolvePrefersLaunchServicesApplication() throws {
        var checkedPaths: [String] = []
        let dynamicPath = "/Users/test/Applications/ChatGPT.app/Contents/Resources/codex"
        let locator = CodexExecutableLocator(
            applicationURL: { bundleIdentifier in
                XCTAssertEqual(bundleIdentifier, "com.openai.codex")
                return URL(fileURLWithPath: "/Users/test/Applications/ChatGPT.app")
            },
            isExecutable: { path in
                checkedPaths.append(path)
                return path == dynamicPath
            }
        )

        XCTAssertEqual(try locator.resolve(), dynamicPath)
        XCTAssertEqual(checkedPaths, [dynamicPath])
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter CodexExecutableLocatorTests/testResolvePrefersLaunchServicesApplication`

Expected: compilation fails because `CodexExecutableLocator` does not exist.

- [ ] **Step 3: Implement the minimal locator**

Create `CodexExecutableLocator.swift` with:

```swift
import AppKit
import Foundation

struct CodexExecutableLocator {
    static let bundleIdentifier = "com.openai.codex"
    static let fallbackPaths = [
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex"
    ]

    private let applicationURL: (String) -> URL?
    private let isExecutable: (String) -> Bool

    init(
        applicationURL: @escaping (String) -> URL? = { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) },
        isExecutable: @escaping (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.applicationURL = applicationURL
        self.isExecutable = isExecutable
    }

    func resolve() throws -> String {
        var candidates: [String] = []
        if let appURL = applicationURL(Self.bundleIdentifier) {
            candidates.append(
                appURL.appendingPathComponent("Contents/Resources/codex").path
            )
        }
        candidates.append(contentsOf: Self.fallbackPaths)

        var checked = Set<String>()
        let uniqueCandidates = candidates.filter { checked.insert($0).inserted }
        if let executable = uniqueCandidates.first(where: isExecutable) {
            return executable
        }
        throw CodexExecutableLocatorError.notFound(checkedPaths: uniqueCandidates)
    }
}

enum CodexExecutableLocatorError: LocalizedError, Equatable {
    case notFound(checkedPaths: [String])

    var errorDescription: String? {
        switch self {
        case .notFound(let checkedPaths):
            return "找不到 ChatGPT/Codex 内置的 codex 可执行文件。已检查：\(checkedPaths.joined(separator: "，"))"
        }
    }
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run: `swift test --filter CodexExecutableLocatorTests/testResolvePrefersLaunchServicesApplication`

Expected: one test passes.

- [ ] **Step 5: Commit the first locator behavior**

```bash
git add Package.swift Sources/CodexQuotaBar/CodexExecutableLocator.swift Tests/CodexQuotaBarTests/CodexExecutableLocatorTests.swift
git commit -m "feat: locate ChatGPT executable through Launch Services"
```

### Task 2: Cover fixed-path fallback and failure diagnostics

**Files:**
- Modify: `Tests/CodexQuotaBarTests/CodexExecutableLocatorTests.swift`
- Modify: `Sources/CodexQuotaBar/CodexExecutableLocator.swift`

- [ ] **Step 1: Write failing tests for fallback, deduplication, and errors**

Append these tests:

```swift
func testResolveFallsBackToChatGPTStandardPath() throws {
    let expected = CodexExecutableLocator.fallbackPaths[0]
    let locator = CodexExecutableLocator(
        applicationURL: { _ in URL(fileURLWithPath: "/Moved/ChatGPT.app") },
        isExecutable: { $0 == expected }
    )

    XCTAssertEqual(try locator.resolve(), expected)
}

func testResolveFallsBackToLegacyCodexStandardPath() throws {
    let expected = CodexExecutableLocator.fallbackPaths[1]
    let locator = CodexExecutableLocator(
        applicationURL: { _ in nil },
        isExecutable: { $0 == expected }
    )

    XCTAssertEqual(try locator.resolve(), expected)
}

func testResolveChecksDuplicateCandidateOnlyOnce() throws {
    var checkedPaths: [String] = []
    let chatGPTApp = URL(fileURLWithPath: "/Applications/ChatGPT.app")
    let locator = CodexExecutableLocator(
        applicationURL: { _ in chatGPTApp },
        isExecutable: { path in
            checkedPaths.append(path)
            return path == CodexExecutableLocator.fallbackPaths[1]
        }
    )

    XCTAssertEqual(try locator.resolve(), CodexExecutableLocator.fallbackPaths[1])
    XCTAssertEqual(checkedPaths, CodexExecutableLocator.fallbackPaths)
}

func testResolveFailureListsEveryCheckedPath() {
    let dynamicPath = "/Moved/ChatGPT.app/Contents/Resources/codex"
    let locator = CodexExecutableLocator(
        applicationURL: { _ in URL(fileURLWithPath: "/Moved/ChatGPT.app") },
        isExecutable: { _ in false }
    )

    XCTAssertThrowsError(try locator.resolve()) { error in
        guard case .notFound(let checkedPaths)? = error as? CodexExecutableLocatorError else {
            return XCTFail("unexpected error: \(error)")
        }
        XCTAssertEqual(checkedPaths, [dynamicPath] + CodexExecutableLocator.fallbackPaths)
        XCTAssertTrue(error.localizedDescription.contains("ChatGPT/Codex"))
    }
}
```

- [ ] **Step 2: Run the locator suite and verify RED where behavior is incomplete**

Run: `swift test --filter CodexExecutableLocatorTests`

Expected: the new tests expose any ordering, duplicate-check, or diagnostic mismatch. If they already pass because Task 1's minimal implementation fully expresses these requirements, retain them as regression tests and continue without adding production code.

- [ ] **Step 3: Make only the locator changes required by the failing assertions**

Keep candidate ordering as dynamic, ChatGPT fallback, then Codex fallback; keep stable first-occurrence deduplication and return the complete ordered candidate array in `notFound`.

- [ ] **Step 4: Run the locator suite and verify GREEN**

Run: `swift test --filter CodexExecutableLocatorTests`

Expected: five tests pass with no warnings or errors.

- [ ] **Step 5: Commit fallback coverage**

```bash
git add Sources/CodexQuotaBar/CodexExecutableLocator.swift Tests/CodexQuotaBarTests/CodexExecutableLocatorTests.swift
git commit -m "test: cover ChatGPT and Codex executable fallbacks"
```

### Task 3: Integrate dynamic resolution into quota fetching

**Files:**
- Modify: `Sources/CodexQuotaBar/CodexRateLimitFetcher.swift`
- Create: `Tests/CodexQuotaBarTests/CodexRateLimitFetcherTests.swift`

- [ ] **Step 1: Write a failing fetcher integration test**

Create `CodexRateLimitFetcherTests.swift`:

```swift
import XCTest
@testable import CodexQuotaBar

final class CodexRateLimitFetcherTests: XCTestCase {
    func testFetchReportsLocatorFailureWithoutStartingOperation() {
        let expectation = expectation(description: "completion")
        let expected = CodexExecutableLocatorError.notFound(checkedPaths: ["/missing/codex"])
        let fetcher = CodexRateLimitFetcher(resolveExecutable: { throw expected })

        fetcher.fetch { result in
            guard case .failure(let error) = result else {
                return XCTFail("expected failure")
            }
            XCTAssertEqual(error as? CodexExecutableLocatorError, expected)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }
}
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `swift test --filter CodexRateLimitFetcherTests/testFetchReportsLocatorFailureWithoutStartingOperation`

Expected: compilation fails because the fetcher has no `resolveExecutable` initializer.

- [ ] **Step 3: Inject resolution and resolve on every fetch**

Replace the stored fixed path and initializer at the top of `CodexRateLimitFetcher` with:

```swift
final class CodexRateLimitFetcher {
    private let resolveExecutable: () throws -> String

    init(resolveExecutable: @escaping () throws -> String = CodexExecutableLocator().resolve) {
        self.resolveExecutable = resolveExecutable
    }

    func fetch(completion: @escaping (Result<QuotaSnapshot, Error>) -> Void) {
        do {
            let executablePath = try resolveExecutable()
            RateLimitFetchOperation(executablePath: executablePath, completion: completion).start()
        } catch {
            DispatchQueue.main.async {
                completion(.failure(error))
            }
        }
    }
}
```

Remove `FetchError.codexExecutableMissing` and its message because executable validation is now owned by the locator. Retain the operation's defensive executable check, but report `CodexExecutableLocatorError.notFound(checkedPaths: [executablePath])` if the file disappears between resolution and process start.

- [ ] **Step 4: Run focused and complete tests**

Run: `swift test --filter CodexRateLimitFetcherTests`

Expected: one test passes.

Run: `swift test`

Expected: all six tests pass.

- [ ] **Step 5: Commit fetcher integration**

```bash
git add Sources/CodexQuotaBar/CodexRateLimitFetcher.swift Tests/CodexQuotaBarTests/CodexRateLimitFetcherTests.swift
git commit -m "fix: resolve ChatGPT executable before quota fetch"
```

### Task 4: Update documentation and verify against the installed ChatGPT app

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update runtime documentation**

Replace the fixed-path description with:

```markdown
应用每次刷新都会通过 macOS Launch Services 查找 Bundle ID 为
`com.openai.codex` 的 ChatGPT/Codex 应用，并启动应用包中的：

```text
Contents/Resources/codex app-server --listen stdio://
```

如果 Launch Services 暂时无法返回安装位置，则依次检查 ChatGPT 和旧版 Codex 的标准安装路径。
```

- [ ] **Step 2: Run all automated verification**

Run: `swift test`

Expected: all tests pass with no failures.

Run: `swift build`

Expected: the executable builds successfully with no errors.

- [ ] **Step 3: Verify the production discovery path on this Mac**

Run:

```bash
swift -e 'import AppKit; if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") { print(url.path) } else { exit(1) }'
```

Expected: prints the installed ChatGPT application path.

Run the resolved `Contents/Resources/codex app-server --listen stdio://`, send `initialize` and `account/rateLimits/read`, and confirm response ID 2 contains `rateLimits.primary` and `rateLimits.secondary`. Do not print authentication tokens or unrelated local configuration.

- [ ] **Step 4: Check the final diff**

Run: `git diff --check HEAD~3..HEAD && git status --short`

Expected: no whitespace errors and only the intended README change remains uncommitted.

- [ ] **Step 5: Commit documentation**

```bash
git add README.md
git commit -m "docs: describe ChatGPT quota discovery"
```
