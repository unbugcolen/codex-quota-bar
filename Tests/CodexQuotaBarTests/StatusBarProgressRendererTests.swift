import AppKit
import XCTest
@testable import CodexQuotaBar

final class StatusBarProgressRendererTests: XCTestCase {
    func testMiniImageFitsCrowdedNotchMenuBars() {
        let mini = StatusBarProgressRenderer.miniImage(
            fiveHourPercent: 72,
            weeklyPercent: 38,
            appearance: nil
        )

        XCTAssertLessThanOrEqual(mini.size.width, 30)
    }

    func testCompactImageIsShorterThanStandardDualProgressImage() {
        let compact = StatusBarProgressRenderer.compactImage(
            fiveHourPercent: 72,
            weeklyPercent: 38,
            appearance: nil
        )
        let standard = StatusBarProgressRenderer.image(
            fiveHourPercent: 72,
            weeklyPercent: 38,
            appearance: nil
        )

        XCTAssertLessThanOrEqual(compact.size.width, 76)
        XCTAssertLessThan(compact.size.width, standard.size.width)
    }
}
