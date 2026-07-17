import Foundation
import XCTest

final class BuildAppConfigurationTests: XCTestCase {
    func testPackagedBundleUsesSwiftRunStatusItemIdentity() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = projectRoot.appendingPathComponent("Resources/Info.plist")
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        let infoPlist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: infoPlistData, format: nil) as? [String: Any]
        )

        XCTAssertEqual(infoPlist["CFBundleIdentifier"] as? String, "CodexQuotaBar")
    }
}
