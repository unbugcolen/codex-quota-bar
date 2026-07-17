import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var statusItem: NSStatusItem = {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = StatusItemConfiguration.autosaveName
        return item
    }()
    private let popover = NSPopover()
    private let viewController = QuotaViewController()
    private let fetcher = CodexRateLimitFetcher()
    private var settings = UserSettings.load()
    private lazy var statusMenu = StatusItemMenuFactory.build(
        target: self,
        refreshAction: #selector(refreshFromMenu),
        settingsAction: #selector(settingsFromMenu),
        quitAction: #selector(quitFromMenu)
    )
    private var settingsWindowController: SettingsWindowController?
    private var refreshTimer: Timer?
    private var sessionDidBecomeActiveObserver: NSObjectProtocol?
    private var isRefreshing = false
    private var lastSnapshot: QuotaSnapshot?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        configureRefreshTimer()
        sessionDidBecomeActiveObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleNotchAdjustment()
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let sessionDidBecomeActiveObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sessionDidBecomeActiveObserver)
        }
    }

    private func configureStatusItem() {
        statusItem.isVisible = true

        guard let button = statusItem.button else {
            return
        }
        applyStatusItemPlaceholder()
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        viewController.onQuit = { [weak self] in
            self?.quitFromMenu()
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

        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
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

    private func showStatusMenu() {
        statusItem.menu = statusMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshFromMenu() {
        popover.performClose(nil)
        refresh()
    }

    @objc private func settingsFromMenu() {
        popover.performClose(nil)
        showSettings()
    }

    @objc private func quitFromMenu() {
        NSApplication.shared.terminate(nil)
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
        case .miniProgress:
            statusItem.length = 34
            button.alignment = .right
            button.image = nil
            button.imagePosition = .noImage
            if let compactPercent {
                button.title = "\(Int(round(compactPercent)))%"
            } else {
                button.title = isError ? "!" : "--"
            }
        case .compactProgress:
            statusItem.length = 78
            button.alignment = .center
            button.title = ""
            button.image = StatusBarProgressRenderer.compactImage(
                fiveHourPercent: fiveHour,
                weeklyPercent: weekly,
                appearance: button.effectiveAppearance
            )
            button.imagePosition = .imageOnly
        case .singleProgress:
            statusItem.length = 98
            button.alignment = .center
            button.title = ""
            button.image = StatusBarProgressRenderer.singleImage(
                percent: compactPercent,
                appearance: button.effectiveAppearance
            )
            button.imagePosition = .imageOnly
        case .dualProgress:
            statusItem.length = 122
            button.alignment = .center
            button.title = ""
            button.image = StatusBarProgressRenderer.image(
                fiveHourPercent: fiveHour,
                weeklyPercent: weekly,
                appearance: button.effectiveAppearance
            )
            button.imagePosition = .imageOnly
        case .text:
            statusItem.length = NSStatusItem.variableLength
            button.alignment = .center
            button.image = nil
            button.imagePosition = .noImage
            if let compactPercent {
                button.title = "Codex \(Int(round(compactPercent)))%"
            } else {
                button.title = isError ? "Codex !" : "Codex --"
            }
        }
        button.setAccessibilityLabel(accessibilityStatus(fiveHour: fiveHour, weekly: weekly, isError: isError))
        scheduleNotchAdjustment()
    }

    private func scheduleNotchAdjustment() {
        guard settings.statusDisplayMode == .miniProgress else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.adjustMiniStatusItemForCameraHousing()
        }
    }

    private func adjustMiniStatusItemForCameraHousing() {
        guard settings.statusDisplayMode == .miniProgress,
              let window = statusItem.button?.window,
              let screen = window.screen else {
            return
        }
        statusItem.length = StatusItemConfiguration.visibleLength(
            baseLength: 34,
            itemFrame: window.frame,
            leftSafeArea: screen.auxiliaryTopLeftArea,
            rightSafeArea: screen.auxiliaryTopRightArea
        )
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
