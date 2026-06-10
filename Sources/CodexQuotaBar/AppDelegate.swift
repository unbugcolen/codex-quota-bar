import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let viewController = QuotaViewController()
    private let fetcher = CodexRateLimitFetcher()
    private var settings = UserSettings.load()
    private var settingsWindowController: SettingsWindowController?
    private var refreshTimer: Timer?
    private var isRefreshing = false
    private var lastSnapshot: QuotaSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        configureRefreshTimer()
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }
        applyStatusItemPlaceholder()
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Codex 额度"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 420, height: 174)
        popover.contentViewController = viewController

        viewController.onRefresh = { [weak self] in
            self?.refresh()
        }
        viewController.onSettings = { [weak self] in
            self?.showSettings()
        }
        viewController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }

    private func configureRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: settings.refreshIntervalSeconds, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            viewController.focusForTouchBar()
        }
    }

    private func refresh() {
        guard !isRefreshing else {
            return
        }
        isRefreshing = true
        viewController.setRefreshing(true)

        fetcher.fetch { [weak self] result in
            guard let self else {
                return
            }
            self.isRefreshing = false

            switch result {
            case .success(let snapshot):
                self.lastSnapshot = snapshot
                self.viewController.apply(snapshot: snapshot)
                self.updateStatusItem(with: snapshot)
            case .failure(let error):
                self.viewController.apply(error: error)
                if self.lastSnapshot == nil {
                    self.applyStatusItemError()
                }
            }
        }
    }

    private func updateStatusItem(with snapshot: QuotaSnapshot) {
        applyStatusItem(snapshot: snapshot, isError: false)
    }

    private func applyStatusItemPlaceholder() {
        applyStatusItem(snapshot: nil, isError: false)
    }

    private func applyStatusItemError() {
        applyStatusItem(snapshot: nil, isError: true)
    }

    private func applyStatusItem(snapshot: QuotaSnapshot?, isError: Bool) {
        guard let button = statusItem.button else {
            return
        }

        let fiveHour = snapshot?.fiveHour.remainingPercent
        let weekly = snapshot?.weekly.remainingPercent
        let compactPercent = [fiveHour, weekly].compactMap { $0 }.min()

        switch settings.statusDisplayMode {
        case .singleProgress:
            statusItem.length = 98
            button.title = ""
            button.image = StatusBarProgressRenderer.singleImage(
                percent: compactPercent,
                appearance: button.effectiveAppearance
            )
            button.imagePosition = .imageOnly
        case .dualProgress:
            statusItem.length = 122
            button.title = ""
            button.image = StatusBarProgressRenderer.image(
                fiveHourPercent: fiveHour,
                weeklyPercent: weekly,
                appearance: button.effectiveAppearance
            )
            button.imagePosition = .imageOnly
        case .text:
            statusItem.length = NSStatusItem.variableLength
            button.image = nil
            button.imagePosition = .noImage
            if let compactPercent {
                button.title = "Codex \(Int(round(compactPercent)))%"
            } else {
                button.title = isError ? "Codex !" : "Codex --"
            }
        }
        button.setAccessibilityLabel(accessibilityStatus(fiveHour: fiveHour, weekly: weekly, isError: isError))
    }

    private func accessibilityStatus(fiveHour: Double?, weekly: Double?, isError: Bool) -> String {
        if isError {
            return "Codex 额度读取失败"
        }
        guard let fiveHour, let weekly else {
            return "Codex 额度未刷新"
        }
        return "Codex 额度，5 小时剩余 \(Int(round(fiveHour)))%，周限额剩余 \(Int(round(weekly)))%"
    }

    private func showSettings() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController(settings: settings)
            controller.onChange = { [weak self] updatedSettings in
                self?.apply(updatedSettings: updatedSettings)
            }
            settingsWindowController = controller
        }
        settingsWindowController?.show()
    }

    private func apply(updatedSettings: UserSettings) {
        settings = updatedSettings
        configureRefreshTimer()
        if let snapshot = lastSnapshot {
            updateStatusItem(with: snapshot)
        } else {
            applyStatusItemPlaceholder()
        }
    }
}
