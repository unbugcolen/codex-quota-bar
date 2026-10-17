import AppKit

final class QuotaRootView: NSView {
    var touchBarProvider: (() -> NSTouchBar?)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
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
    private var showsFiveHourQuota = true
    private var heightConstraint: NSLayoutConstraint?

    var contentSize: NSSize {
        let additionalHeight = showsFiveHourQuota ? fiveHourRow.preferredHeight + 16 : 0
        return NSSize(width: 320, height: 100 + weeklyRow.preferredHeight + additionalHeight)
    }

    override func loadView() {
        let rootView = QuotaRootView(frame: NSRect(origin: .zero, size: contentSize))
        rootView.touchBarProvider = { [weak self] in
            self?.buildTouchBar()
        }
        view = rootView
        buildContent(in: rootView)
        applyPlaceholder()
        fiveHourRow.isHidden = !showsFiveHourQuota
        updateContentSize()
    }

    func setShowsFiveHourQuota(_ showsFiveHourQuota: Bool) {
        self.showsFiveHourQuota = showsFiveHourQuota
        _ = view
        fiveHourRow.isHidden = !showsFiveHourQuota
        updateContentSize()
        refreshTouchBar()
    }

    func apply(snapshot: QuotaSnapshot) {
        _ = view
        self.snapshot = snapshot
        isRefreshing = false

        fiveHourRow.configure(title: snapshot.fiveHour.title, bucket: snapshot.fiveHour)
        weeklyRow.configure(title: snapshot.weekly.title, bucket: snapshot.weekly)
        updateContentSize()
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
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        settingsButton.target = self
        settingsButton.action = #selector(settingsTapped)
        settingsButton.toolTip = "设置"

        refreshButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "刷新")
        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)
        refreshButton.toolTip = "刷新额度"

        for button in [settingsButton, refreshButton] {
            button.isBordered = false
            button.focusRingType = .none
            button.contentTintColor = .secondaryLabelColor
            button.image = button.image?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        }

        quitButton.title = "退出"
        quitButton.font = .systemFont(ofSize: 10.5)
        quitButton.isBordered = false
        quitButton.focusRingType = .none
        quitButton.contentTintColor = .secondaryLabelColor
        quitButton.target = self
        quitButton.action = #selector(quitTapped)
        quitButton.toolTip = "退出"

        let header = NSStackView(views: [titleLabel, NSView(), settingsButton, refreshButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false

        let rows = NSStackView(views: [fiveHourRow, weeklyRow])
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 16
        rows.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 10.5)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        statusLabel.setContentHuggingPriority(.required, for: .vertical)

        let footer = NSStackView(views: [statusLabel, NSView(), quitButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.translatesAutoresizingMaskIntoConstraints = false

        let content = NSStackView(views: [header, rows, footer])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 18
        content.setCustomSpacing(16, after: rows)
        content.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(content)

        let heightConstraint = rootView.heightAnchor.constraint(equalToConstant: contentSize.height)
        self.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            rootView.widthAnchor.constraint(equalToConstant: 320),
            heightConstraint,
            content.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -12),
            header.widthAnchor.constraint(equalTo: content.widthAnchor),
            header.heightAnchor.constraint(equalToConstant: 22),
            rows.widthAnchor.constraint(equalTo: content.widthAnchor),
            fiveHourRow.widthAnchor.constraint(equalTo: rows.widthAnchor),
            weeklyRow.widthAnchor.constraint(equalTo: rows.widthAnchor),
            footer.widthAnchor.constraint(equalTo: content.widthAnchor),
            footer.heightAnchor.constraint(equalToConstant: 16),
            settingsButton.widthAnchor.constraint(equalToConstant: 22),
            settingsButton.heightAnchor.constraint(equalToConstant: 22),
            refreshButton.widthAnchor.constraint(equalToConstant: 22),
            refreshButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    private func updateContentSize() {
        heightConstraint?.constant = contentSize.height
        preferredContentSize = contentSize
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
        formatter.timeStyle = .short
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
        var identifiers: [NSTouchBarItem.Identifier] = []
        if showsFiveHourQuota {
            identifiers += [.codexFiveHourQuota, .fixedSpaceSmall]
        }
        identifiers += [
            .codexWeeklyQuota,
            .flexibleSpace,
            .codexRefresh
        ]
        touchBar.defaultItemIdentifiers = identifiers
        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .codexFiveHourQuota:
            guard showsFiveHourQuota else { return nil }
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
