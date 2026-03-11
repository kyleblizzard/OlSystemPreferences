import Cocoa

protocol GridViewControllerDelegate: AnyObject {
    func gridViewController(_ controller: GridViewController, didSelectPane identifier: String)
}

class GridViewController: NSViewController {

    weak var delegate: GridViewControllerDelegate?

    private var panes: [PaneProtocol] = []
    private var filteredPanes: [PaneProtocol] = []
    private var sections: [(category: PaneCategory, panes: [PaneProtocol])] = []

    private lazy var scrollView: NSScrollView = {
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.hasVerticalScroller = true
        sv.hasHorizontalScroller = false
        sv.drawsBackground = false
        sv.documentView = collectionView
        return sv
    }()

    private lazy var collectionView: NSCollectionView = {
        let cv = NSCollectionView()
        cv.collectionViewLayout = createLayout()
        cv.delegate = self
        cv.dataSource = self
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        cv.register(GridItemView.self, forItemWithIdentifier: GridItemView.identifier)
        cv.register(
            GridSectionHeaderView.self,
            forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
            withIdentifier: NSUserInterfaceItemIdentifier("GridSectionHeaderView")
        )
        return cv
    }()

    func setPanes(_ panes: [PaneProtocol]) {
        self.panes = panes
        self.filteredPanes = panes
        rebuildSections()
        collectionView.reloadData()
    }

    func filterPanes(searchText: String) {
        if searchText.isEmpty {
            filteredPanes = panes
        } else {
            let query = searchText.lowercased()
            filteredPanes = panes.filter { pane in
                pane.paneTitle.lowercased().contains(query) ||
                pane.searchKeywords.contains(where: { $0.lowercased().contains(query) })
            }
        }
        rebuildSections()
        collectionView.reloadData()
    }

    override func loadView() {
        view = NSView()
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func createLayout() -> NSCollectionViewFlowLayout {
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = AppConstants.gridItemSize
        layout.minimumInteritemSpacing = AppConstants.gridInteritemSpacing
        layout.minimumLineSpacing = AppConstants.gridLineSpacing
        layout.sectionInset = AppConstants.gridSectionInset
        layout.headerReferenceSize = NSSize(width: 0, height: 30)
        return layout
    }

    private func rebuildSections() {
        var grouped: [PaneCategory: [PaneProtocol]] = [:]
        for pane in filteredPanes {
            grouped[pane.paneCategory, default: []].append(pane)
        }
        sections = PaneCategory.allCases.compactMap { category in
            guard let panes = grouped[category], !panes.isEmpty else { return nil }
            return (category: category, panes: panes)
        }
    }
}

// MARK: - NSCollectionViewDataSource

extension GridViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].panes.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: GridItemView.identifier, for: indexPath)
        guard let gridItem = item as? GridItemView else { return item }
        let pane = sections[indexPath.section].panes[indexPath.item]
        gridItem.configure(title: pane.paneTitle, icon: pane.paneIcon)
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
                withIdentifier: NSUserInterfaceItemIdentifier("GridSectionHeaderView"),
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
        let pane = sections[indexPath.section].panes[indexPath.item]
        delegate?.gridViewController(self, didSelectPane: pane.paneIdentifier)
        // Deselect after navigation
        collectionView.deselectItems(at: indexPaths)
    }
}
