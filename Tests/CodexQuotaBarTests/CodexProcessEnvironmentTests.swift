import XCTest
@testable import CodexQuotaBar

final class CodexProcessEnvironmentTests: XCTestCase {
    private let proxySettings: [String: Any] = [
        "HTTPEnable": 1, "HTTPProxy": "127.0.0.1", "HTTPPort": 7897,
        "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 7897,
        "ExceptionsList": ["localhost", "127.0.0.1", "*.local", "10.0.0.0/8", "<local>"]
    ]

    func testGUIEnvironmentUsesSystemProxiesAndExceptions() {
        let environment = CodexRateLimitFetcher.appServerEnvironment(
            environment: ["HOME": "/Users/test"], proxySettings: proxySettings
        )

        XCTAssertEqual(environment["HTTP_PROXY"], "http://127.0.0.1:7897")
        XCTAssertEqual(environment["HTTPS_PROXY"], "http://127.0.0.1:7897")
        XCTAssertEqual(environment["NO_PROXY"], "localhost,127.0.0.1,.local,10.0.0.0/8")
        XCTAssertEqual(environment["HOME"], "/Users/test")
    }

    func testExplicitProxyAndBypassEnvironmentIsPreserved() {
        let original = ["HTTP_PROXY": "", "https_proxy": "http://custom:8080", "no_proxy": "internal"]
        let environment = CodexRateLimitFetcher.appServerEnvironment(
            environment: original, proxySettings: proxySettings
        )

        XCTAssertEqual(environment, original)
    }

    func testExplicitGlobalProxyIsNotOverriddenBySystemProxy() {
        for key in ["ALL_PROXY", "all_proxy"] {
            let original = [key: "socks5h://custom:1080"]
            XCTAssertEqual(
                CodexRateLimitFetcher.appServerEnvironment(environment: original, proxySettings: proxySettings),
                original
            )
        }
    }

    func testOnlyMissingSchemeUsesSystemProxy() {
        let environment = CodexRateLimitFetcher.appServerEnvironment(
            environment: ["HTTPS_PROXY": "http://custom:8080", "NO_PROXY": ""],
            proxySettings: proxySettings
        )

        XCTAssertEqual(environment["HTTPS_PROXY"], "http://custom:8080")
        XCTAssertEqual(environment["HTTP_PROXY"], "http://127.0.0.1:7897")
        XCTAssertEqual(environment["NO_PROXY"], "")
    }

    func testDisabledOrInvalidSystemProxiesAreIgnored() {
        let settings: [String: Any] = [
            "HTTPEnable": 0, "HTTPProxy": "127.0.0.1", "HTTPPort": 7897,
            "HTTPSEnable": 1, "HTTPSProxy": "127.0.0.1", "HTTPSPort": 0
        ]

        XCTAssertEqual(
            CodexRateLimitFetcher.appServerEnvironment(environment: [:], proxySettings: settings), [:]
        )
    }

    func testMissingSystemSettingsPreserveEnvironment() {
        let original = ["PATH": "/usr/bin"]
        XCTAssertEqual(
            CodexRateLimitFetcher.appServerEnvironment(environment: original, proxySettings: nil), original
        )
    }
}
