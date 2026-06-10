import AppKit

final class SettingsWindowController: NSWindowController {
    var onChange: ((UserSettings) -> Void)?

    private var settings: UserSettings
    private let modePopup = NSPopUpButton()
    private let intervalPopup = NSPopUpButton()

    init(settings: UserSettings) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 138),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex 额度设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
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

    private func buildContentView() -> NSView {
        let root = NSView()

        let titleLabel = NSTextField(labelWithString: "设置")
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)

        let modeLabel = NSTextField(labelWithString: "菜单栏显示")
        modeLabel.alignment = .right
        let intervalLabel = NSTextField(labelWithString: "自动刷新")
        intervalLabel.alignment = .right

        modePopup.addItems(withTitles: StatusDisplayMode.allCases.map(\.title))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)

        intervalPopup.addItems(withTitles: UserSettings.refreshIntervalOptions.map(UserSettings.title(for:)))
        intervalPopup.target = self
        intervalPopup.action = #selector(intervalChanged)

        let grid = NSGridView(views: [
            [modeLabel, modePopup],
            [intervalLabel, intervalPopup]
        ])
        grid.column(at: 0).width = 84
        grid.column(at: 1).xPlacement = .fill
        grid.rowSpacing = 12
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
        if let index = UserSettings.refreshIntervalOptions.firstIndex(of: settings.refreshIntervalSeconds) {
            intervalPopup.selectItem(at: index)
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
}
