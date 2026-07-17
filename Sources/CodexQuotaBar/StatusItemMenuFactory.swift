import AppKit

enum StatusItemMenuFactory {
    static func build(
        target: AnyObject,
        refreshAction: Selector,
        settingsAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "刷新", action: refreshAction, keyEquivalent: "r")
        refreshItem.target = target
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "设置...", action: settingsAction, keyEquivalent: ",")
        settingsItem.target = target
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 Codex Quota Bar", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
