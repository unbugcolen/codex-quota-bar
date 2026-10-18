import XCTest
@testable import CodexQuotaBar

final class UserSettingsTests: XCTestCase {
    func testLoadDefaultsToMiniProgressDisplay() {
        let suiteName = "UserSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = UserSettings.load(defaults: defaults)

        XCTAssertEqual(settings.statusDisplayMode, .miniProgress)
        XCTAssertEqual(settings.statusBarBranding, .codexText)
    }

    func testBrandingChoicePersistsWithoutChangingOtherSettings() throws {
        let suiteName = "UserSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        for branding in StatusBarBranding.allCases {
            let settings = UserSettings(
                statusDisplayMode: .singleProgress,
                refreshIntervalSeconds: 600,
                showsFiveHourQuota: false,
                statusBarBranding: branding
            )
            settings.save(defaults: defaults)

            let restored = UserSettings.load(defaults: defaults)
            XCTAssertEqual(restored.statusBarBranding, branding)
            XCTAssertEqual(restored.statusDisplayMode, .singleProgress)
            XCTAssertEqual(restored.refreshIntervalSeconds, 600)
            XCTAssertFalse(restored.showsFiveHourQuota)
        }
    }

    func testUnknownBrandingFallsBackToExistingCodexText() throws {
        let suiteName = "UserSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("futureBranding", forKey: "statusBarBranding")

        XCTAssertEqual(UserSettings.load(defaults: defaults).statusBarBranding, .codexText)
    }
}
