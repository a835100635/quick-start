import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var launcherManager: LauncherManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        launcherManager = LauncherManager()
        HotKeys.shared.register { [weak self] in
            self?.launcherManager.toggleFullMenu()
        }
        buildMainMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotKeys.shared.unregister()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc private func openSettings() {
        launcherManager.showSettings()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quick Start 设置…", action: #selector(openSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Quick Start", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        appMenu.item(withTitle: "Quick Start 设置…")?.target = self

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
