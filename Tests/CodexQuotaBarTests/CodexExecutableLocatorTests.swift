import XCTest
@testable import CodexQuotaBar

final class CodexExecutableLocatorTests: XCTestCase {
    func testResolvePrefersLaunchServicesApplication() throws {
        let applicationPath = "/Users/test/Applications/ChatGPT.app"
        let executablePath = applicationPath + "/Contents/Resources/codex"
        var checkedPaths: [String] = []

        let locator = CodexExecutableLocator(
            applicationURL: { bundleIdentifier in
                XCTAssertEqual(bundleIdentifier, "com.openai.codex")
                return URL(fileURLWithPath: applicationPath)
            },
            isExecutable: { path in
                checkedPaths.append(path)
                return path == executablePath
            }
        )

        XCTAssertEqual(try locator.resolve(), executablePath)
        XCTAssertEqual(checkedPaths, [executablePath])
    }
}
