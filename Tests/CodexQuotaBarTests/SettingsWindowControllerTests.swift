import AppKit
import ServiceManagement
import XCTest
@testable import CodexQuotaBar

final class SettingsWindowControllerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    func testOpeningSettingsOnlyReadsLoginItemState() {
        let loginItem = StubLoginItem(status: .notRegistered)
        let controller = makeController(loginItem)

        XCTAssertEqual(checkbox(in: controller).state, .off)
        XCTAssertEqual(loginItem.registerCalls, 0)
        XCTAssertEqual(loginItem.unregisterCalls, 0)
    }

    func testToggleRegistersAndUnregistersLoginItem() {
        let loginItem = StubLoginItem(status: .notRegistered)
        let controller = makeController(loginItem)
        let checkbox = checkbox(in: controller)

        checkbox.performClick(nil)
        XCTAssertEqual(loginItem.registerCalls, 1)
        XCTAssertEqual(checkbox.state, .on)

        checkbox.performClick(nil)
        XCTAssertEqual(loginItem.unregisterCalls, 1)
        XCTAssertEqual(checkbox.state, .off)
    }

    func testPendingApprovalIsShownAsMixedWithSettingsLink() {
        let loginItem = StubLoginItem(status: .notRegistered)
        loginItem.statusAfterRegister = .requiresApproval
        let controller = makeController(loginItem)

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(checkbox(in: controller).state, .mixed)
        XCTAssertTrue(labels(in: controller).contains { $0.stringValue == "等待系统允许" })
        XCTAssertFalse(button(titled: "去设置", in: controller).isHidden)
    }

    func testPendingApprovalCanBeCancelled() {
        let loginItem = StubLoginItem(status: .requiresApproval)
        let controller = makeController(loginItem)

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(loginItem.registerCalls, 0)
        XCTAssertEqual(loginItem.unregisterCalls, 1)
        XCTAssertEqual(checkbox(in: controller).state, .off)
        XCTAssertTrue(button(titled: "去设置", in: controller).isHidden)
    }

    func testApprovalRequiredAfterRegistrationErrorStillShowsSystemSettingsLink() {
        var status: SMAppService.Status = .notRegistered
        let controller = SettingsWindowController(
            settings: UserSettings(statusDisplayMode: .dualProgress, refreshIntervalSeconds: 300),
            loginItemStatus: { status },
            registerLoginItem: {
                status = .requiresApproval
                throw NSError(domain: "LoginItemTest", code: 3)
            },
            unregisterLoginItem: { XCTFail("Unexpected unregister") }
        )

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(checkbox(in: controller).state, .mixed)
        XCTAssertTrue(labels(in: controller).contains { $0.stringValue == "等待系统允许" })
        XCTAssertFalse(button(titled: "去设置", in: controller).isHidden)
        XCTAssertFalse(labels(in: controller).contains { $0.stringValue == "设置失败，请重试" })
    }

    func testDisablingDoesNotReregisterIfSystemAlreadyDisabledLoginItem() {
        let loginItem = StubLoginItem(status: .enabled)
        let controller = makeController(loginItem)
        loginItem.status = .notRegistered

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(checkbox(in: controller).state, .off)
        XCTAssertEqual(loginItem.registerCalls, 0)
        XCTAssertEqual(loginItem.unregisterCalls, 0)
    }

    func testRegistrationFailureRestoresSystemStateAndShowsError() {
        let loginItem = StubLoginItem(status: .notRegistered)
        loginItem.registerError = NSError(
            domain: "LoginItemTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Registration denied"]
        )
        let controller = makeController(loginItem)

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(checkbox(in: controller).state, .off)
        XCTAssertTrue(checkbox(in: controller).isEnabled)
        let errorHint = labels(in: controller).first { $0.stringValue == "设置失败，请重试" }
        XCTAssertEqual(errorHint?.toolTip, "Registration denied")
    }

    func testUnregistrationFailureKeepsRegisteredState() {
        let loginItem = StubLoginItem(status: .enabled)
        loginItem.unregisterError = NSError(domain: "LoginItemTest", code: 2)
        let controller = makeController(loginItem)

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(loginItem.unregisterCalls, 1)
        XCTAssertEqual(checkbox(in: controller).state, .on)
        XCTAssertTrue(labels(in: controller).contains { $0.stringValue == "设置失败，请重试" })
    }

    func testReturningToSettingsReadsChangesMadeInSystemSettings() {
        let loginItem = StubLoginItem(status: .requiresApproval)
        let controller = makeController(loginItem)
        loginItem.status = .enabled

        controller.windowDidBecomeKey(Notification(name: NSWindow.didBecomeKeyNotification))

        XCTAssertEqual(checkbox(in: controller).state, .on)
        XCTAssertTrue(button(titled: "去设置", in: controller).isHidden)
        XCTAssertEqual(loginItem.registerCalls, 0)
        XCTAssertEqual(loginItem.unregisterCalls, 0)
    }

    func testNeverRegisteredServiceCanBeEnabledFromNotFoundState() {
        let loginItem = StubLoginItem(status: .notFound)
        let controller = makeController(loginItem)

        XCTAssertEqual(checkbox(in: controller).state, .off)
        XCTAssertTrue(checkbox(in: controller).isEnabled)

        checkbox(in: controller).performClick(nil)

        XCTAssertEqual(loginItem.registerCalls, 1)
        XCTAssertEqual(checkbox(in: controller).state, .on)
    }

    private func makeController(_ loginItem: StubLoginItem) -> SettingsWindowController {
        SettingsWindowController(
            settings: UserSettings(statusDisplayMode: .dualProgress, refreshIntervalSeconds: 300),
            loginItemStatus: { loginItem.status },
            registerLoginItem: { try loginItem.register() },
            unregisterLoginItem: { try loginItem.unregister() }
        )
    }

    private func checkbox(in controller: SettingsWindowController) -> NSButton {
        button(titled: "开机自动启动", in: controller)
    }

    private func button(titled title: String, in controller: SettingsWindowController) -> NSButton {
        descendants(controller.window!.contentView!).compactMap { $0 as? NSButton }
            .first { $0.title == title }!
    }

    private func labels(in controller: SettingsWindowController) -> [NSTextField] {
        descendants(controller.window!.contentView!).compactMap { $0 as? NSTextField }
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }
}

private final class StubLoginItem {
    var status: SMAppService.Status
    var statusAfterRegister: SMAppService.Status = .enabled
    var registerCalls = 0
    var unregisterCalls = 0
    var registerError: Error?
    var unregisterError: Error?

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}
