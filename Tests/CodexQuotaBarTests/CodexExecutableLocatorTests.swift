import XCTest
@testable import CodexQuotaBar

final class CodexExecutableLocatorTests: XCTestCase {
    func testResolvePrefersLaunchServicesApplication() throws {
        let applicationPath = "/Users/test/Applications/ChatGPT.app"
        let executablePath = applicationPath + "/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
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

    func testResolveSupportsMovedApplicationWrapper() throws {
        let applicationPath = "/Moved/ChatGPT.app"
        let executablePath = applicationPath + "/Contents/Resources/codex-cli/bin/codex"
        let locator = CodexExecutableLocator(
            applicationURL: { _ in URL(fileURLWithPath: applicationPath) },
            isExecutable: { $0 == executablePath }
        )

        XCTAssertEqual(try locator.resolve(), executablePath)
    }

    func testResolveSupportsMovedApplicationLegacyLayout() throws {
        let applicationPath = "/Moved/Codex.app"
        let executablePath = applicationPath + "/Contents/Resources/codex"
        let locator = CodexExecutableLocator(
            applicationURL: { _ in URL(fileURLWithPath: applicationPath) },
            isExecutable: { $0 == executablePath }
        )

        XCTAssertEqual(try locator.resolve(), executablePath)
    }

    func testResolveFallsBackToNewChatGPTStandardPath() throws {
        let expectedPath = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        let locator = CodexExecutableLocator(
            applicationURL: { _ in nil },
            isExecutable: { $0 == expectedPath }
        )

        XCTAssertEqual(try locator.resolve(), expectedPath)
    }

    func testResolvePrefersSignedCLIOverWrapperAndLegacyCLI() throws {
        let applicationPath = "/Moved/ChatGPT.app"
        let locator = CodexExecutableLocator(
            applicationURL: { _ in URL(fileURLWithPath: applicationPath) },
            isExecutable: { $0.hasPrefix(applicationPath + "/Contents/Resources/") }
        )

        XCTAssertEqual(
            try locator.resolve(),
            applicationPath + "/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
        )
    }

    func testResolveFallsBackToChatGPTStandardPath() throws {
        let expectedPath = "/Applications/ChatGPT.app/Contents/Resources/codex"
        let locator = CodexExecutableLocator(
            applicationURL: { _ in
                URL(fileURLWithPath: "/Moved/ChatGPT.app")
            },
            isExecutable: { path in
                path == expectedPath
            }
        )

        XCTAssertEqual(try locator.resolve(), expectedPath)
    }

    func testResolveFallsBackToLegacyCodexStandardPath() throws {
        let expectedPath = "/Applications/Codex.app/Contents/Resources/codex"
        let locator = CodexExecutableLocator(
            applicationURL: { _ in nil },
            isExecutable: { path in
                path == expectedPath
            }
        )

        XCTAssertEqual(try locator.resolve(), expectedPath)
    }

    func testResolveChecksDuplicateCandidateOnlyOnce() throws {
        var checkedPaths: [String] = []
        let locator = CodexExecutableLocator(
            applicationURL: { _ in
                URL(fileURLWithPath: "/Applications/ChatGPT.app")
            },
            isExecutable: { path in
                checkedPaths.append(path)
                return path == "/Applications/Codex.app/Contents/Resources/codex"
            }
        )

        XCTAssertEqual(try locator.resolve(), "/Applications/Codex.app/Contents/Resources/codex")
        XCTAssertEqual(checkedPaths, CodexExecutableLocator.fallbackPaths)
    }

    func testResolveFailureListsEveryCheckedPath() {
        let applicationPath = "/Moved/ChatGPT.app"
        let dynamicPaths = [
            applicationPath + "/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
            applicationPath + "/Contents/Resources/codex-cli/bin/codex",
            applicationPath + "/Contents/Resources/codex"
        ]
        let locator = CodexExecutableLocator(
            applicationURL: { _ in
                URL(fileURLWithPath: applicationPath)
            },
            isExecutable: { _ in false }
        )

        XCTAssertThrowsError(try locator.resolve()) { error in
            guard case .notFound(let checkedPaths)? = error as? CodexExecutableLocatorError else {
                return XCTFail("Expected notFound error, got \(error)")
            }

            XCTAssertEqual(checkedPaths, dynamicPaths + CodexExecutableLocator.fallbackPaths)
            XCTAssertTrue(error.localizedDescription.contains("ChatGPT"))
            XCTAssertTrue(error.localizedDescription.contains("Codex"))
            for path in dynamicPaths {
                XCTAssertTrue(error.localizedDescription.contains(path))
            }
            XCTAssertTrue(
                error.localizedDescription.contains(
                    "/Applications/ChatGPT.app/Contents/Resources/codex"
                )
            )
            XCTAssertTrue(
                error.localizedDescription.contains(
                    "/Applications/Codex.app/Contents/Resources/codex"
                )
            )
        }
    }
}
