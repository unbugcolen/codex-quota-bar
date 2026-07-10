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
                return path == CodexExecutableLocator.fallbackPaths[1]
            }
        )

        XCTAssertEqual(try locator.resolve(), CodexExecutableLocator.fallbackPaths[1])
        XCTAssertEqual(checkedPaths, CodexExecutableLocator.fallbackPaths)
    }

    func testResolveFailureListsEveryCheckedPath() {
        let applicationPath = "/Moved/ChatGPT.app"
        let dynamicPath = applicationPath + "/Contents/Resources/codex"
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

            XCTAssertEqual(checkedPaths, [dynamicPath] + CodexExecutableLocator.fallbackPaths)
            XCTAssertTrue(error.localizedDescription.contains("ChatGPT"))
            XCTAssertTrue(error.localizedDescription.contains("Codex"))
            XCTAssertTrue(error.localizedDescription.contains(dynamicPath))
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
