import Cocoa

/// What's currently shown in the window / as an overlay.
enum NavEntry: Equatable {
    case grid
    case pane(String)
    case launchpad
    case dashboard
    case coverFlow
}

class MainWindowController: NSWindowController, NSToolbarDelegate {

    private let gridViewController = GridViewController()
    private let navControl = SnowLeopardNavControl(frame: NSRect(x: 0, y: 0, width: 56, height: 24))
    private lazy var launchpadController = LaunchpadWindowController()
    private lazy var dashboardController = DashboardWindowController()
    private lazy var coverFlowVC = CoverFlowViewController()

    // Mode bar in content area
    private let modeBar = ModeBarBackgroundView()
    private let modeSegment: NSSegmentedControl = {
        let seg = NSSegmentedControl()
        seg.segmentCount = 4
        seg.trackingMode = .selectOne
        seg.segmentStyle = .texturedRounded
        let titles = ["Preferences", "Launchpad", "Dashboard", "Cover Flow"]
        for (i, t) in titles.enumerated() {
            seg.setLabel(t, forSegment: i)
            seg.setWidth(0, forSegment: i)
        }
        seg.selectedSegment = 0
        seg.controlSize = .regular
        seg.font = NSFont(name: "Lucida Grande", size: 11)
        seg.translatesAutoresizingMaskIntoConstraints = false
        return seg
    }()
    private let contentContainer = NSView()

    // Unified navigation history across all modes
    private var navBackStack: [NavEntry] = []
    private var navForwardStack: [NavEntry] = []
    private var currentEntry: NavEntry = .grid
    private var currentPaneVC: NSViewController?
    private var isNavigating = false

    // Toolbar
    private let toolbarIdentifier = NSToolbar.Identifier("MainToolbar")
    private let navItemID = NSToolbarItem.Identifier("nav")
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

        launchpadController.onDismiss = { [weak self] in self?.overlayDidDismiss() }
        dashboardController.onDismiss = { [weak self] in self?.overlayDidDismiss() }

        setupToolbar()
        setupModeBar()
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

    private func setupModeBar() {
        guard let windowContentView = window?.contentView else { return }

        modeBar.translatesAutoresizingMaskIntoConstraints = false
        windowContentView.addSubview(modeBar)

        // Segmented control centered in the mode bar
        modeSegment.target = self
        modeSegment.action = #selector(modeSegmentChanged(_:))
        modeBar.addSubview(modeSegment)

        // Content container sits below mode bar
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        windowContentView.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            modeBar.topAnchor.constraint(equalTo: windowContentView.topAnchor),
            modeBar.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor),
            modeBar.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor),
            modeBar.heightAnchor.constraint(equalToConstant: 32),

            modeSegment.centerXAnchor.constraint(equalTo: modeBar.centerXAnchor),
            modeSegment.centerYAnchor.constraint(equalTo: modeBar.centerYAnchor),

            contentContainer.topAnchor.constraint(equalTo: modeBar.bottomAnchor),
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

    /// Called when Launchpad/Dashboard dismiss themselves (ESC, background click, etc.)
    private func overlayDidDismiss() {
        guard !isNavigating else { return }
        guard currentEntry == .launchpad || currentEntry == .dashboard else { return }
        navBackStack.append(currentEntry)
        navForwardStack.removeAll()
        currentEntry = .grid
        updateNavButtons()
    }

    private func updateNavButtons() {
        navControl.backEnabled = !navBackStack.isEmpty
        navControl.forwardEnabled = !navForwardStack.isEmpty

        // Highlight the correct mode segment
        let selectedIndex: Int
        switch currentEntry {
        case .grid, .pane: selectedIndex = 0
        case .launchpad:   selectedIndex = 1
        case .dashboard:   selectedIndex = 2
        case .coverFlow:   selectedIndex = 3
        }
        modeSegment.selectedSegment = selectedIndex
    }

    /// Tear down whatever is currently showing, then show the new entry.
    private func applyEntry(_ entry: NavEntry) {
        // Tear down current (suppress onDismiss callbacks during navigation)
        isNavigating = true
        tearDownCurrentView()
        isNavigating = false

        // Apply new
        currentEntry = entry

        switch entry {
        case .grid:
            showGrid()
        case .pane(let id):
            showPane(id)
        case .launchpad:
            showGrid() // grid behind the overlay
            launchpadController.show()
        case .dashboard:
            showGrid()
            dashboardController.show()
        case .coverFlow:
            showCoverFlowView()
        }
    }

    private func tearDownCurrentView() {
        // Dismiss overlays
        launchpadController.dismissIfShowing()
        dashboardController.dismissIfShowing()

        // Remove in-window views
        if let paneVC = currentPaneVC {
            (paneVC as? PaneProtocol)?.paneWillDisappear()
            paneVC.view.removeFromSuperview()
            currentPaneVC = nil
        }
        gridViewController.view.removeFromSuperview()
        coverFlowVC.view.removeFromSuperview()
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

        let paneSize = NSSize(width: pane.preferredPaneSize.width, height: pane.preferredPaneSize.height + 64)
        window?.animateResize(to: paneSize)
        window?.title = pane.paneTitle
        currentPaneVC = pane.viewController
    }

    private func showCoverFlowView() {
        coverFlowVC.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(coverFlowVC.view)
        NSLayoutConstraint.activate([
            coverFlowVC.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            coverFlowVC.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            coverFlowVC.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            coverFlowVC.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        window?.animateResize(to: NSSize(width: 768, height: 680))
        window?.title = "Cover Flow"
        window?.makeFirstResponder(coverFlowVC)
    }

    // MARK: - Mode button handler

    @objc private func modeSegmentChanged(_ sender: NSSegmentedControl) {
        SoundService.playClick()
        switch sender.selectedSegment {
        case 0: navigateTo(.grid)
        case 1: navigateTo(.launchpad)
        case 2: navigateTo(.dashboard)
        case 3: navigateTo(.coverFlow)
        default: break
        }
    }

    // MARK: - Public for AppDelegate menus

    func switchToGrid() {
        navigateTo(.grid)
    }

    func switchToCoverFlow() {
        navigateTo(.coverFlow)
    }

    @objc func toggleDashboard(_ sender: Any?) {
        if currentEntry == .dashboard {
            navigateTo(.grid)
        } else {
            navigateTo(.dashboard)
        }
    }

    @objc func toggleLaunchpad(_ sender: Any?) {
        if currentEntry == .launchpad {
            navigateTo(.grid)
        } else {
            navigateTo(.launchpad)
        }
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
        [navItemID, .flexibleSpace, searchItemID]
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

// MARK: - Mode Bar Background View

/// Custom-drawn mode bar with subtle gradient and bottom border line (Snow Leopard style).
private class ModeBarBackgroundView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }

    override func draw(_ dirtyRect: NSRect) {
        // Subtle gradient: slightly lighter at top, modeBarBackground at bottom
        let topColor = SnowLeopardColors.modeBarBackground.blended(withFraction: 0.15, of: .white)
            ?? SnowLeopardColors.modeBarBackground
        let gradient = NSGradient(starting: topColor, ending: SnowLeopardColors.modeBarBackground)
        gradient?.draw(in: bounds, angle: 270)

        // 1px bottom border line
        SnowLeopardColors.modeBarBorder.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
}
