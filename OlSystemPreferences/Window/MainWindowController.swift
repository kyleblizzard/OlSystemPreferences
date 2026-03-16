import Cocoa

/// What's currently shown in the window.
enum NavEntry: Equatable {
    case grid
    case pane(String)
}

class MainWindowController: NSWindowController, NSToolbarDelegate {

    private let gridViewController = GridViewController()
    private let navControl = SnowLeopardNavControl(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private let contentContainer = NSView()

    // Unified navigation history across all modes
    private var navBackStack: [NavEntry] = []
    private var navForwardStack: [NavEntry] = []
    private var currentEntry: NavEntry = .grid
    private var currentPaneVC: NSViewController?

    // Toolbar
    private let toolbarIdentifier = NSToolbar.Identifier("MainToolbar")
    private let navItemID = NSToolbarItem.Identifier("nav")
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
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = false
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = SnowLeopardColors.gridBackground
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.center()

        self.init(window: window)

        navControl.backAction = { [weak self] in self?.goBack() }
        navControl.forwardAction = { [weak self] in self?.goForward() }

        setupToolbar()
        setupContentContainer()
        setupContent()
        updateNavButtons()
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func setupContentContainer() {
        guard let windowContentView = window?.contentView else { return }

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        windowContentView.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            contentContainer.topAnchor.constraint(equalTo: windowContentView.topAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor),
        ])
    }

    private func setupContent() {
        gridViewController.delegate = self
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(gridViewController.view)
        NSLayoutConstraint.activate([
            gridViewController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            gridViewController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            gridViewController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            gridViewController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
    }

    // MARK: - Unified Navigation

    private func navigateTo(_ entry: NavEntry) {
        guard entry != currentEntry else { return }

        // Push current onto back stack
        navBackStack.append(currentEntry)
        navForwardStack.removeAll()

        applyEntry(entry)
        updateNavButtons()
    }

    private func goBack() {
        SoundService.playNavigate()
        guard let prev = navBackStack.popLast() else { return }
        navForwardStack.append(currentEntry)
        applyEntry(prev)
        updateNavButtons()
    }

    private func goForward() {
        SoundService.playNavigate()
        guard let next = navForwardStack.popLast() else { return }
        navBackStack.append(currentEntry)
        applyEntry(next)
        updateNavButtons()
    }

    private func updateNavButtons() {
        navControl.backEnabled = !navBackStack.isEmpty
        navControl.forwardEnabled = !navForwardStack.isEmpty
    }

    /// Tear down whatever is currently showing, then show the new entry.
    private func applyEntry(_ entry: NavEntry) {
        tearDownCurrentView()
        currentEntry = entry

        switch entry {
        case .grid:
            showGrid()
        case .pane(let id):
            showPane(id)
        }
    }

    private func tearDownCurrentView() {
        if let paneVC = currentPaneVC {
            (paneVC as? PaneProtocol)?.paneWillDisappear()
            paneVC.view.removeFromSuperview()
            currentPaneVC = nil
        }
        gridViewController.view.removeFromSuperview()
    }

    private func showGrid() {
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(gridViewController.view)
        NSLayoutConstraint.activate([
            gridViewController.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            gridViewController.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            gridViewController.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            gridViewController.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        window?.animateResize(to: AppConstants.gridWindowSize)
        window?.title = "System Preferences"
    }

    private func showPane(_ id: String) {
        guard let pane = PaneRegistry.createPane(id) else {
            showGrid()
            return
        }
        pane.paneWillAppear()

        let paneView = pane.viewController.view
        paneView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(paneView)
        NSLayoutConstraint.activate([
            paneView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            paneView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            paneView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            paneView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])

        let paneSize = NSSize(width: pane.preferredPaneSize.width, height: pane.preferredPaneSize.height + 32)
        window?.animateResize(to: paneSize)
        window?.title = pane.paneTitle
        currentPaneVC = pane.viewController
    }

    // MARK: - Public for AppDelegate menus

    @objc func switchToGrid() {
        navigateTo(.grid)
    }

    // MARK: - NSToolbarDelegate

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case navItemID:
            let item = NSToolbarItem(itemIdentifier: navItemID)
            item.label = "Navigation"
            navControl.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                navControl.widthAnchor.constraint(equalToConstant: 56),
                navControl.heightAnchor.constraint(equalToConstant: 24),
            ])
            item.view = navControl
            return item

        case showAllItemID:
            let item = NSToolbarItem(itemIdentifier: showAllItemID)
            item.label = "Show All"
            item.toolTip = "Show All Preferences"
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Show All")
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(switchToGrid)
            button.font = SnowLeopardFonts.label(size: 11)
            item.view = button
            return item

        case searchItemID:
            let item = NSSearchToolbarItem(itemIdentifier: searchItemID)
            item.searchField.delegate = self
            item.searchField.font = SnowLeopardFonts.label(size: 12)
            item.label = "Search"
            return item

        default:
            return nil
        }
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [navItemID, showAllItemID, .flexibleSpace, searchItemID]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }
}

// MARK: - GridViewControllerDelegate

extension MainWindowController: GridViewControllerDelegate {
    func gridViewController(_ controller: GridViewController, didSelectItem item: PreferenceItem) {
        SoundService.playClick()
        if PaneRegistry.createPane(item.id) != nil {
            navigateTo(.pane(item.id))
        } else {
            item.open()
        }
    }
}

// MARK: - NSSearchFieldDelegate

extension MainWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        if currentEntry != .grid {
            // Navigate to grid without pushing if we're searching
            tearDownCurrentView()
            currentEntry = .grid
            showGrid()
            updateNavButtons()
        }
        gridViewController.filterItems(searchText: searchField.stringValue)
    }
}

