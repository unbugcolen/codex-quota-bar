import AppKit
import XCTest
@testable import CodexQuotaBar

final class StatusItemMenuFactoryTests: XCTestCase {
    func testBuildIncludesQuitItemWiredToTarget() {
        let target = MenuActionTarget()

        let menu = StatusItemMenuFactory.build(
            target: target,
            refreshAction: #selector(MenuActionTarget.refresh),
            settingsAction: #selector(MenuActionTarget.settings),
            quitAction: #selector(MenuActionTarget.quit)
        )

        let quitItem = menu.items.last
        XCTAssertEqual(quitItem?.title, "退出 Codex Quota Bar")
        XCTAssertTrue(quitItem?.target === target)
        XCTAssertEqual(quitItem?.action, #selector(MenuActionTarget.quit))
        XCTAssertEqual(quitItem?.keyEquivalent, "q")
    }
}

private final class MenuActionTarget: NSObject {
    @objc func refresh() {}
    @objc func settings() {}
    @objc func quit() {}
}
