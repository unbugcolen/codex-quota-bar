import XCTest
@testable import CodexQuotaBar

final class StatusItemConfigurationTests: XCTestCase {
    func testStatusItemUsesStableAutosaveName() {
        XCTAssertEqual(StatusItemConfiguration.autosaveName, "CodexQuotaBar.menuBarItem.v3")
    }

    func testVisibleLengthBridgesCameraHousingIntoRightSafeArea() {
        XCTAssertEqual(
            StatusItemConfiguration.visibleLength(
                baseLength: 34,
                itemFrame: CGRect(x: 798, y: 950, width: 36, height: 32),
                leftSafeArea: CGRect(x: 0, y: 950, width: 663, height: 32),
                rightSafeArea: CGRect(x: 848, y: 950, width: 664, height: 32)
            ),
            84
        )
    }

    func testVisibleLengthStaysCompactInRightSafeArea() {
        XCTAssertEqual(
            StatusItemConfiguration.visibleLength(
                baseLength: 34,
                itemFrame: CGRect(x: 1200, y: 950, width: 36, height: 32),
                leftSafeArea: CGRect(x: 0, y: 950, width: 663, height: 32),
                rightSafeArea: CGRect(x: 848, y: 950, width: 664, height: 32)
            ),
            34
        )
    }

    func testVisibleLengthStaysCompactInLeftSafeArea() {
        XCTAssertEqual(
            StatusItemConfiguration.visibleLength(
                baseLength: 34,
                itemFrame: CGRect(x: 500, y: 950, width: 36, height: 32),
                leftSafeArea: CGRect(x: 0, y: 950, width: 663, height: 32),
                rightSafeArea: CGRect(x: 848, y: 950, width: 664, height: 32)
            ),
            34
        )
    }
}
