import AppKit

final class QuotaRootView: NSView {
    var touchBarProvider: (() -> NSTouchBar?)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func makeTouchBar() -> NSTouchBar? {
        touchBarProvider?()
    }
}

final class QuotaViewController: NSViewController, NSTouchBarDelegate {
    var onRefresh: (() -> Void)?
    var onSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let fiveHourRow = QuotaRowView()
    private let weeklyRow = QuotaRowView()
    private let statusLabel = NSTextField(labelWithString: "尚未刷新")
    private let settingsButton = NSButton()
    private let refreshButton = NSButton()
    private let quitButton = NSButton()
    private var snapshot: QuotaSnapshot?
    private var isRefreshing = false

    override func loadView() {
        let rootView = QuotaRootView(frame: NSRect(x: 0, y: 0, width: 420, height: 174))
        rootView.touchBarProvider = { [weak self] in
            self?.buildTouchBar()
        }
        view = rootView
        buildContent(in: rootView)
        applyPlaceholder()
    }

    func apply(snapshot: QuotaSnapshot) {
        self.snapshot = snapshot
        isRefreshing = false

        fiveHourRow.configure(title: snapshot.fiveHour.title, bucket: snapshot.fiveHour)
        weeklyRow.configure(title: snapshot.weekly.title, bucket: snapshot.weekly)
        statusLabel.stringValue = "更新 \(formatUpdatedAt(snapshot.updatedAt))"
        statusLabel.textColor = .secondaryLabelColor
        refreshButton.isEnabled = true
        refreshTouchBar()
    }

    func setRefreshing(_ refreshing: Bool) {
        isRefreshing = refreshing
        refreshButton.isEnabled = !refreshing
        statusLabel.stringValue = refreshing ? "刷新中..." : statusLabel.stringValue
        statusLabel.textColor = .secondaryLabelColor
        refreshTouchBar()
    }

    func apply(error: Error) {
        isRefreshing = false
        refreshButton.isEnabled = true
        statusLabel.stringValue = error.localizedDescription
        statusLabel.textColor = .systemRed
        refreshTouchBar()
    }

    func focusForTouchBar() {
        view.window?.makeFirstResponder(view)
        refreshTouchBar()
    }

    private func buildContent(in rootView: NSView) {
        let titleLabel = NSTextField(labelWithString: "Codex 额度")
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        settingsButton.bezelStyle = .texturedRounded
        settingsButton.target = self
        settingsButton.action = #selector(settingsTapped)
        settingsButton.toolTip = "设置"

        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新")
        refreshButton.bezelStyle = .texturedRounded
        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)
        refreshButton.toolTip = "刷新额度"

        quitButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "退出")
        quitButton.bezelStyle = .texturedRounded
        quitButton.target = self
        quitButton.action = #selector(quitTapped)
        quitButton.toolTip = "退出"

        let header = NSStackView(views: [titleLabel, NSView(), settingsButton, refreshButton, quitButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.translatesAutoresizingMaskIntoConstraints = false

        let rows = NSStackView(views: [fiveHourRow, weeklyRow])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 10
        rows.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        statusLabel.setContentHuggingPriority(.required, for: .vertical)

        let content = NSStackView(views: [header, rows, statusLabel])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 10
        content.setCustomSpacing(8, after: rows)
        content.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(content)

        NSLayoutConstraint.activate([
            rootView.widthAnchor.constraint(equalToConstant: 420),
            rootView.heightAnchor.constraint(equalToConstant: 174),
            content.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 14),
            content.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12),
            header.widthAnchor.constraint(equalTo: content.widthAnchor),
            rows.widthAnchor.constraint(equalTo: content.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: content.widthAnchor),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 16),
            settingsButton.widthAnchor.constraint(equalToConstant: 26),
            refreshButton.widthAnchor.constraint(equalToConstant: 26),
            quitButton.widthAnchor.constraint(equalToConstant: 26)
        ])
    }

    private func applyPlaceholder() {
        fiveHourRow.configure(title: "5小时", bucket: nil)
        weeklyRow.configure(title: "周限额", bucket: nil)
    }

    @objc private func refreshTapped() {
        onRefresh?()
    }

    @objc private func settingsTapped() {
        onSettings?()
    }

    @objc private func quitTapped() {
        onQuit?()
    }

    private func formatUpdatedAt(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func refreshTouchBar() {
        guard let rootView = view as? QuotaRootView else {
            return
        }
        rootView.touchBar = buildTouchBar()
    }

    private func buildTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [
            .codexFiveHourQuota,
            .fixedSpaceSmall,
            .codexWeeklyQuota,
            .flexibleSpace,
            .codexRefresh
        ]
        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .codexFiveHourQuota:
            return quotaTouchBarItem(identifier: identifier, bucket: snapshot?.fiveHour, fallbackTitle: "5小时")
        case .codexWeeklyQuota:
            return quotaTouchBarItem(identifier: identifier, bucket: snapshot?.weekly, fallbackTitle: "周限额")
        case .codexRefresh:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(
                image: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新") ?? NSImage(),
                target: self,
                action: #selector(refreshTapped)
            )
            button.isEnabled = !isRefreshing
            button.toolTip = isRefreshing ? "刷新中..." : "刷新额度"
            item.view = button
            return item
        default:
            return nil
        }
    }

    private func quotaTouchBarItem(identifier: NSTouchBarItem.Identifier, bucket: QuotaBucket?, fallbackTitle: String) -> NSTouchBarItem {
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.view = TouchBarQuotaView(title: bucket?.title ?? fallbackTitle, bucket: bucket)
        return item
    }
}

private extension NSTouchBarItem.Identifier {
    static let codexFiveHourQuota = NSTouchBarItem.Identifier("com.colen.CodexQuotaBar.fiveHourQuota")
    static let codexWeeklyQuota = NSTouchBarItem.Identifier("com.colen.CodexQuotaBar.weeklyQuota")
    static let codexRefresh = NSTouchBarItem.Identifier("com.colen.CodexQuotaBar.refresh")
}
