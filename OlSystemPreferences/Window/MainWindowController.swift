import Cocoa

class MainWindowController: NSWindowController, NSToolbarDelegate {

    private let navigationManager = NavigationManager()
    private var paneRegistry: [String: PaneProtocol] = [:]
    private var allPanes: [PaneProtocol] = []

    private let gridViewController = GridViewController()
    private var currentPaneViewController: NSViewController?

    private let containerView = NSView()
    private let rootViewController = NSViewController()

    // Toolbar item identifiers
    private let toolbarIdentifier = NSToolbar.Identifier("MainToolbar")
    private let backItemID = NSToolbarItem.Identifier("back")
    private let forwardItemID = NSToolbarItem.Identifier("forward")
    private let showAllItemID = NSToolbarItem.Identifier("showAll")
    private let searchItemID = NSToolbarItem.Identifier("search")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AppConstants.gridWindowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "System Preferences"
        window.minSize = AppConstants.windowMinSize
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.center()

        self.init(window: window)

        // Set a root view controller so we can use addChild
        rootViewController.view = NSView()
        window.contentViewController = rootViewController

        setupToolbar()
        setupContent()
        registerPanes()
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func setupContent() {
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = rootViewController.view
        contentView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        gridViewController.delegate = self
        showGridView(animated: false)
    }

    private func registerPanes() {
        let panes: [PaneProtocol] = [
            GeneralPaneViewController(),
            DockPaneViewController(),
            SoundPaneViewController(),
            DesktopScreenSaverPaneViewController(),
            DisplaysPaneViewController(),
            KeyboardPaneViewController(),
            MouseTrackpadPaneViewController(),
        ]

        for pane in panes {
            paneRegistry[pane.paneIdentifier] = pane
        }
        allPanes = panes
        gridViewController.setPanes(panes)
    }

    // MARK: - Navigation

    private func showGridView(animated: Bool) {
        removeCurrent()
        rootViewController.addChild(gridViewController)
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(gridViewController.view)
        NSLayoutConstraint.activate([
            gridViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            gridViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gridViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gridViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        currentPaneViewController = nil
        window?.title = "System Preferences"

        if animated {
            window?.animateResize(to: AppConstants.gridWindowSize)
        } else {
            window?.setContentSize(AppConstants.gridWindowSize)
        }
        updateToolbarState()
    }

    private func showPane(identifier: String, animated: Bool = true) {
        guard let pane = paneRegistry[identifier] else { return }

        pane.reloadFromSystem()
        pane.paneWillAppear()

        removeCurrent()

        let vc = pane.viewController
        rootViewController.addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
        currentPaneViewController = vc
        window?.title = pane.paneTitle

        if animated {
            window?.animateResize(to: pane.preferredPaneSize)
        } else {
            window?.setContentSize(pane.preferredPaneSize)
        }
        updateToolbarState()
    }

    private func removeCurrent() {
        if let current = currentPaneViewController {
            // Notify the pane it's disappearing
            if let pane = allPanes.first(where: { $0.viewController === current }) {
                pane.paneWillDisappear()
            }
            current.view.removeFromSuperview()
            current.removeFromParent()
        } else {
            gridViewController.view.removeFromSuperview()
            gridViewController.removeFromParent()
        }
    }

    private func updateToolbarState() {
        window?.toolbar?.items.forEach { item in
            switch item.itemIdentifier {
            case backItemID:
                item.isEnabled = navigationManager.canGoBack
            case forwardItemID:
                item.isEnabled = navigationManager.canGoForward
            case showAllItemID:
                item.isEnabled = currentPaneViewController != nil
            default:
                break
            }
        }
    }

    // MARK: - Toolbar Actions

    @objc private func goBack(_ sender: Any?) {
        if let previous = navigationManager.goBack() {
            if previous == "__grid__" {
                showGridView(animated: true)
            } else {
                showPane(identifier: previous)
            }
        } else {
            navigationManager.showAll()
            showGridView(animated: true)
        }
    }

    @objc private func goForward(_ sender: Any?) {
        if let next = navigationManager.goForward() {
            showPane(identifier: next)
        }
    }

    @objc func showAll(_ sender: Any?) {
        navigationManager.showAll()
        showGridView(animated: true)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case backItemID:
            let item = NSToolbarItem(itemIdentifier: backItemID)
            item.label = "Back"
            item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
            item.action = #selector(goBack(_:))
            item.target = self
            item.isEnabled = false
            return item

        case forwardItemID:
            let item = NSToolbarItem(itemIdentifier: forwardItemID)
            item.label = "Forward"
            item.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
            item.action = #selector(goForward(_:))
            item.target = self
            item.isEnabled = false
            return item

        case showAllItemID:
            let item = NSToolbarItem(itemIdentifier: showAllItemID)
            item.label = "Show All"
            item.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Show All")
            item.action = #selector(showAll(_:))
            item.target = self
            item.isEnabled = false
            return item

        case searchItemID:
            let item = NSSearchToolbarItem(itemIdentifier: searchItemID)
            item.searchField.delegate = self
            item.label = "Search"
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            backItemID,
            forwardItemID,
            showAllItemID,
            .flexibleSpace,
            searchItemID,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
}

// MARK: - GridViewControllerDelegate

extension MainWindowController: GridViewControllerDelegate {
    func gridViewController(_ controller: GridViewController, didSelectPane identifier: String) {
        navigationManager.navigateTo(identifier)
        showPane(identifier: identifier)
    }
}

// MARK: - NSSearchFieldDelegate

extension MainWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        let text = searchField.stringValue

        if currentPaneViewController != nil {
            // Return to grid if we're in a pane and user starts searching
            navigationManager.showAll()
            showGridView(animated: true)
        }
        gridViewController.filterPanes(searchText: text)
    }
}
