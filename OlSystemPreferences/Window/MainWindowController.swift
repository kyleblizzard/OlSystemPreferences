import Cocoa

class MainWindowController: NSWindowController, NSToolbarDelegate {

    private let gridViewController = GridViewController()

    // Toolbar item identifiers
    private let toolbarIdentifier = NSToolbar.Identifier("MainToolbar")
    private let backItemID = NSToolbarItem.Identifier("back")
    private let forwardItemID = NSToolbarItem.Identifier("forward")
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
        // Clear search and show all items
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
        case backItemID:
            let item = NSToolbarItem(itemIdentifier: backItemID)
            item.label = "Back"
            item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
            item.isEnabled = false
            return item

        case forwardItemID:
            let item = NSToolbarItem(itemIdentifier: forwardItemID)
            item.label = "Forward"
            item.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
            item.isEnabled = false
            return item

        case showAllItemID:
            let item = NSToolbarItem(itemIdentifier: showAllItemID)
            item.label = "Show All"
            item.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Show All")
            item.action = #selector(showAll(_:))
            item.target = self
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
