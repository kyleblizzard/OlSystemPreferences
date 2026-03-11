import Cocoa

class MainWindowController: NSWindowController, NSToolbarDelegate {

    private let gridViewController = GridViewController()
    private let navControl = SnowLeopardNavControl(frame: NSRect(x: 0, y: 0, width: 56, height: 24))

    // Toolbar item identifiers
    private let toolbarIdentifier = NSToolbar.Identifier("MainToolbar")
    private let navItemID = NSToolbarItem.Identifier("nav")
    private let showAllItemID = NSToolbarItem.Identifier("showAll")
    private let searchItemID = NSToolbarItem.Identifier("search")

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: AppConstants.gridWindowSize),
            styleMask: [.titled, .closable, .miniaturizable],
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
        window.center()

        self.init(window: window)

        setupToolbar()
        setupContent()
    }

    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: toolbarIdentifier)
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        window?.toolbar = toolbar
    }

    private func setupContent() {
        let contentView = window?.contentView ?? NSView()

        gridViewController.delegate = self
        gridViewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(gridViewController.view)

        NSLayoutConstraint.activate([
            gridViewController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            gridViewController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            gridViewController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            gridViewController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    // MARK: - Toolbar Actions

    @objc func showAll(_ sender: Any?) {
        if let toolbar = window?.toolbar {
            for item in toolbar.items {
                if let searchItem = item as? NSSearchToolbarItem {
                    searchItem.searchField.stringValue = ""
                }
            }
        }
        gridViewController.filterItems(searchText: "")
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
            item.view = navControl
            item.minSize = navControl.intrinsicContentSize
            item.maxSize = navControl.intrinsicContentSize
            return item

        case showAllItemID:
            let item = NSToolbarItem(itemIdentifier: showAllItemID)
            item.label = "Show All"
            let button = SnowLeopardShowAllButton(frame: NSRect(x: 0, y: 0, width: 32, height: 24))
            button.target = self
            button.action = #selector(showAll(_:))
            item.view = button
            item.minSize = NSSize(width: 32, height: 24)
            item.maxSize = NSSize(width: 32, height: 24)
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
        return [
            navItemID,
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
    func gridViewController(_ controller: GridViewController, didSelectItem item: PreferenceItem) {
        item.open()
    }
}

// MARK: - NSSearchFieldDelegate

extension MainWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else { return }
        gridViewController.filterItems(searchText: searchField.stringValue)
    }
}
