import AppKit
import ServiceManagement

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    var onChange: ((UserSettings) -> Void)?

    private var settings: UserSettings
    private let modePopup = NSPopUpButton()
    private let intervalPopup = NSPopUpButton()
    private let fiveHourCheckbox = NSButton(checkboxWithTitle: "显示 5 小时额度", target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "开机自动启动", target: nil, action: nil)
    private let launchAtLoginHint = NSTextField(labelWithString: "登录后自动运行")
    private let loginItemsButton = NSButton(title: "去设置", target: nil, action: nil)
    private let loginItemStatus: () -> SMAppService.Status
    private let registerLoginItem: () throws -> Void
    private let unregisterLoginItem: () throws -> Void
    private var loginItemIsRegistered = false

    init(
        settings: UserSettings,
        loginItemStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
        registerLoginItem: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
        unregisterLoginItem: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
    ) {
        self.settings = settings
        self.loginItemStatus = loginItemStatus
        self.registerLoginItem = registerLoginItem
        self.unregisterLoginItem = unregisterLoginItem
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 232),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex 额度设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = buildContentView()
        applySettingsToControls()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        applySettingsToControls()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        updateLaunchAtLoginControls()
    }

    private func buildContentView() -> NSView {
        let root = NSView()

        let titleLabel = NSTextField(labelWithString: "设置")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let modeLabel = NSTextField(labelWithString: "菜单栏显示")
        modeLabel.alignment = .right
        let intervalLabel = NSTextField(labelWithString: "自动刷新")
        intervalLabel.alignment = .right
        let quotaLabel = NSTextField(labelWithString: "显示项目")
        quotaLabel.alignment = .right
        let startupLabel = NSTextField(labelWithString: "启动方式")
        startupLabel.alignment = .right

        modePopup.addItems(withTitles: StatusDisplayMode.allCases.map(\.title))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)

        intervalPopup.addItems(withTitles: UserSettings.refreshIntervalOptions.map(UserSettings.title(for:)))
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)
        fiveHourCheckbox.target = self
        fiveHourCheckbox.action = #selector(fiveHourVisibilityChanged)

        launchAtLoginCheckbox.allowsMixedState = true
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)
        launchAtLoginHint.font = .systemFont(ofSize: 11)
        launchAtLoginHint.textColor = .secondaryLabelColor
        launchAtLoginHint.lineBreakMode = .byTruncatingTail
        launchAtLoginHint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        loginItemsButton.font = .systemFont(ofSize: 11)
        loginItemsButton.isBordered = false
        loginItemsButton.contentTintColor = .controlAccentColor
        loginItemsButton.target = self
        loginItemsButton.action = #selector(openLoginItemsSettings)

        let loginHintRow = NSStackView(views: [launchAtLoginHint, loginItemsButton])
        loginHintRow.orientation = .horizontal
        loginHintRow.alignment = .centerY
        loginHintRow.spacing = 6
        loginHintRow.edgeInsets = NSEdgeInsets(top: 0, left: 22, bottom: 0, right: 0)
        let loginOptions = NSStackView(views: [launchAtLoginCheckbox, loginHintRow])
        loginOptions.orientation = .vertical
        loginOptions.alignment = .leading
        loginOptions.spacing = 3

        let grid = NSGridView(views: [
            [modeLabel, modePopup],
            [quotaLabel, fiveHourCheckbox],
            [intervalLabel, intervalPopup],
            [startupLabel, loginOptions]
        ])
        grid.column(at: 0).width = 84
        grid.column(at: 1).xPlacement = .fill
        grid.rowSpacing = 12
        grid.row(at: 3).yPlacement = .top
        grid.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView(views: [titleLabel, grid])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 18),
            modePopup.widthAnchor.constraint(equalToConstant: 180),
            intervalPopup.widthAnchor.constraint(equalToConstant: 180)
        ])

        return root
    }

    private func applySettingsToControls() {
        modePopup.selectItem(withTitle: settings.statusDisplayMode.title)
        fiveHourCheckbox.state = settings.showsFiveHourQuota ? .on : .off
        if let index = UserSettings.refreshIntervalOptions.firstIndex(of: settings.refreshIntervalSeconds) {
            intervalPopup.selectItem(at: index)
        }
        updateLaunchAtLoginControls()
    }

    private func updateLaunchAtLoginControls(error: Error? = nil) {
        let status = loginItemStatus()
        loginItemIsRegistered = status == .enabled || status == .requiresApproval
        launchAtLoginCheckbox.isEnabled = true
        launchAtLoginHint.textColor = .secondaryLabelColor
        launchAtLoginHint.toolTip = nil
        loginItemsButton.isHidden = status != .requiresApproval

        switch status {
        case .enabled:
            launchAtLoginCheckbox.state = .on
            launchAtLoginHint.stringValue = "登录后自动运行"
        case .requiresApproval:
            launchAtLoginCheckbox.state = .mixed
            launchAtLoginHint.stringValue = "等待系统允许"
        case .notRegistered, .notFound:
            launchAtLoginCheckbox.state = .off
            launchAtLoginHint.stringValue = "登录后自动运行"
        @unknown default:
            launchAtLoginCheckbox.state = .off
            launchAtLoginCheckbox.isEnabled = false
            launchAtLoginHint.stringValue = "暂时无法读取启动设置"
        }

        if let error, status != .requiresApproval {
            launchAtLoginHint.stringValue = "设置失败，请重试"
            launchAtLoginHint.textColor = .systemRed
            launchAtLoginHint.toolTip = error.localizedDescription
        }
    }

    @objc private func modeChanged() {
        let index = max(0, modePopup.indexOfSelectedItem)
        settings.statusDisplayMode = StatusDisplayMode.allCases[index]
        settings.save()
        onChange?(settings)
    }

    @objc private func intervalChanged() {
        let index = max(0, intervalPopup.indexOfSelectedItem)
        settings.refreshIntervalSeconds = UserSettings.refreshIntervalOptions[index]
        settings.save()
        onChange?(settings)
    }

    @objc private func fiveHourVisibilityChanged() {
        settings.showsFiveHourQuota = fiveHourCheckbox.state == .on
        settings.save()
        onChange?(settings)
    }

    @objc private func launchAtLoginChanged() {
        let shouldEnable = !loginItemIsRegistered
        launchAtLoginCheckbox.isEnabled = false
        do {
            let status = loginItemStatus()
            if shouldEnable, status == .notRegistered || status == .notFound {
                try registerLoginItem()
            } else if !shouldEnable, status == .enabled || status == .requiresApproval {
                try unregisterLoginItem()
            }
            updateLaunchAtLoginControls()
        } catch {
            updateLaunchAtLoginControls(error: error)
        }
    }

    @objc private func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
