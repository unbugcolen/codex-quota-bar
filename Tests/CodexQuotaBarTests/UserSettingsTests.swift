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
    }
}
