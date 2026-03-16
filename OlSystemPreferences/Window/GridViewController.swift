import Cocoa

protocol GridViewControllerDelegate: AnyObject {
    func gridViewController(_ controller: GridViewController, didSelectItem item: PreferenceItem)
}

class GridViewController: NSViewController {

    weak var delegate: GridViewControllerDelegate?

    private var detectedApps: [PreferenceItem] = []
    private var allItems: [PreferenceItem] = []
    private var sections: [(category: PaneCategory, items: [PreferenceItem])] = []

    /// The current search query — used for dimming non-matching items instead of hiding them
    private var currentSearchText: String = ""

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.autohidesScrollers = true
        sv.drawsBackground = true
        sv.backgroundColor = SnowLeopardColors.gridBackground
        sv.documentView = collectionView
        return sv
    }()

    private lazy var collectionView: NSCollectionView = {
        let cv = NSCollectionView()
        cv.collectionViewLayout = createLayout()
        cv.delegate = self
        cv.dataSource = self
        cv.backgroundColors = [SnowLeopardColors.gridBackground]
        cv.isSelectable = true
        cv.register(GridItemView.self, forItemWithIdentifier: GridItemView.identifier)
        cv.register(
            GridSectionHeaderView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: GridSectionHeaderView.identifier
        )
        return cv
    }()

    override func loadView() {
        view = NSView()
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Detect installed apps on background queue, then update UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = AppDetector.detectInstalledApps()
            DispatchQueue.main.async {
                self?.detectedApps = apps
                self?.reloadAllItems(searchText: "")
            }
        }

        // Show system prefs immediately
        reloadAllItems(searchText: "")
    }

    func filterItems(searchText: String) {
        currentSearchText = searchText
        reloadAllItems(searchText: searchText)
    }

    private func reloadAllItems(searchText: String) {
        // Always show all items — Snow Leopard dims non-matches instead of hiding them
        allItems = PreferenceItem.allItems + detectedApps
        rebuildSections()
        collectionView.reloadData()
    }

    /// Check whether a given item matches the current search query
    private func itemMatchesSearch(_ item: PreferenceItem) -> Bool {
        guard !currentSearchText.isEmpty else { return true }
        let query = currentSearchText.lowercased()
        return item.title.lowercased().contains(query) ||
            item.keywords.contains(where: { $0.lowercased().contains(query) })
    }

    private func createLayout() -> NSCollectionViewFlowLayout {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = AppConstants.gridItemSize
        layout.minimumInteritemSpacing = AppConstants.gridInteritemSpacing
        layout.minimumLineSpacing = AppConstants.gridLineSpacing
        layout.sectionInset = AppConstants.gridSectionInset
        layout.headerReferenceSize = NSSize(width: 0, height: AppConstants.headerHeight)
        return layout
    }

    private func rebuildSections() {
        var grouped: [PaneCategory: [PreferenceItem]] = [:]
        for item in allItems {
            grouped[item.category, default: []].append(item)
        }
        sections = PaneCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category: category, items: items)
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension GridViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let view = collectionView.makeItem(withIdentifier: GridItemView.identifier, for: indexPath)
        guard let gridItem = view as? GridItemView else { return view }
        let item = sections[indexPath.section].items[indexPath.item]
        gridItem.configure(
            title: item.title,
            icon: item.icon,
            tintColor: item.isAppItem ? nil : item.iconColor
        )
        // Dim non-matching items during search — Snow Leopard spotlight behavior
        gridItem.isDimmed = !itemMatchesSearch(item)
        return gridItem
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
        at indexPath: IndexPath
    ) -> NSView {
        if kind == NSCollectionView.elementKindSectionHeader {
            let header = collectionView.makeSupplementaryView(
                ofKind: kind,
                withIdentifier: GridSectionHeaderView.identifier,
                for: indexPath
            )
            if let sectionHeader = header as? GridSectionHeaderView {
                sectionHeader.titleLabel.stringValue = sections[indexPath.section].category.rawValue
            }
            return header
        }
        return NSView()
    }
}

// MARK: - NSCollectionViewDelegate

extension GridViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let item = sections[indexPath.section].items[indexPath.item]
        delegate?.gridViewController(self, didSelectItem: item)

        // Deselect after a brief moment so the highlight flashes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            collectionView.deselectItems(at: indexPaths)
        }
    }
}
