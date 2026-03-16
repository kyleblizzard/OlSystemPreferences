import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    var mainWindowController: MainWindowController?
    private lazy var aboutWindowController = AboutWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["ClassicSoundsEnabled": true])

        setupMainMenu()

        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        mainWindowController?.window?.orderFrontRegardless()

        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        SoundService.playStartup()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Actions

    @objc private func showAbout(_ sender: Any?) {
        aboutWindowController.showWindow(nil)
        aboutWindowController.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func showDashboard(_ sender: Any?) {
        mainWindowController?.toggleDashboard(nil)
    }

    @objc private func viewAsIcons(_ sender: Any?) {
        mainWindowController?.switchToGrid()
    }

    @objc private func viewAsCoverFlow(_ sender: Any?) {
        mainWindowController?.switchToCoverFlow()
    }

    // MARK: - Menu Bar

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(withTitle: "About System Preferences", action: #selector(showAbout(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let hideItem = NSMenuItem(title: "Hide System Preferences", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hideItem)
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit System Preferences", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu (for search field)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        // View menu (F1, F5)
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenuItem.submenu = viewMenu

        let showAllItem = NSMenuItem(title: "Show All Preferences", action: #selector(viewAsIcons(_:)), keyEquivalent: "l")
        viewMenu.addItem(showAllItem)
        viewMenu.addItem(NSMenuItem.separator())
        let coverFlowItem = NSMenuItem(title: "as Cover Flow", action: #selector(viewAsCoverFlow(_:)), keyEquivalent: "2")
        viewMenu.addItem(coverFlowItem)
        viewMenu.addItem(NSMenuItem.separator())
        let dashboardItem = NSMenuItem(title: "Dashboard", action: #selector(showDashboard(_:)), keyEquivalent: "")
        dashboardItem.keyEquivalent = String(UnicodeScalar(NSF4FunctionKey)!)
        dashboardItem.keyEquivalentModifierMask = []
        viewMenu.addItem(dashboardItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}
