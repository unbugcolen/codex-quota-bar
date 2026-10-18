import AppKit
import XCTest
@testable import CodexQuotaBar

final class StatusBarProgressRendererTests: XCTestCase {
    func testSingleProgressReclaimsSpaceForIconAndHiddenBranding() {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            let images = StatusBarBranding.allCases.map { branding in
                StatusBarProgressRenderer.singleImage(
                    percent: 88, branding: branding, appearance: NSAppearance(named: appearance)
                )
            }

            XCTAssertLessThan(images[1].size.width, images[0].size.width)
            XCTAssertLessThan(images[2].size.width, images[1].size.width)
            XCTAssertTrue(images.allSatisfy { $0.size.height == 18 })
            XCTAssertTrue(images.allSatisfy { !$0.isTemplate })
        }
    }

    func testChatGPTIconIsBundledWithRetinaRepresentation() throws {
        let icon = try XCTUnwrap(StatusBarProgressRenderer.chatGPTIcon())

        XCTAssertTrue(icon.isTemplate)
        XCTAssertEqual(icon.size, NSSize(width: 16, height: 16))
        XCTAssertTrue(icon.representations.contains { $0.pixelsWide >= 36 })
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: XCTUnwrap(icon.tiffRepresentation)))
        XCTAssertTrue((0..<bitmap.pixelsHigh).contains { y in
            (0..<bitmap.pixelsWide).contains { x in
                (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0
            }
        })
    }

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
