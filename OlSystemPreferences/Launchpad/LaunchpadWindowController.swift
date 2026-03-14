import Cocoa
import QuartzCore

// MARK: - Data Models

struct LaunchpadApp {
    let name: String
    let icon: NSImage
    let url: URL
    let bundleIdentifier: String?
    let isUtility: Bool
}

struct LaunchpadFolder {
    var name: String
    var apps: [LaunchpadApp]
}

enum LaunchpadEntry {
    case app(LaunchpadApp)
    case folder(LaunchpadFolder)

    var sortName: String {
        switch self {
        case .app(let app): return app.name
        case .folder(let folder): return folder.name
        }
    }
}

// MARK: - App Scanner

enum LaunchpadAppScanner {

    private static var cachedApps: [LaunchpadApp]?

    static func scan(forceRescan: Bool = false) -> [LaunchpadApp] {
        if !forceRescan, let cached = cachedApps {
            return cached
        }

        var apps: [LaunchpadApp] = []
        let fm = FileManager.default

        let topPaths = [
            "/Applications",
            "/System/Applications",
            NSString("~/Applications").expandingTildeInPath,
        ]

        for basePath in topPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: basePath) else { continue }
            for item in contents {
                let fullPath = (basePath as NSString).appendingPathComponent(item)
                if item.hasSuffix(".app") {
                    addApp(at: fullPath, to: &apps)
                } else {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                        if let subs = try? fm.contentsOfDirectory(atPath: fullPath) {
                            for sub in subs where sub.hasSuffix(".app") {
                                addApp(at: (fullPath as NSString).appendingPathComponent(sub), to: &apps)
                            }
                        }
                    }
                }
            }
        }

        // Deduplicate by bundle ID
        var seen = Set<String>()
        apps = apps.filter { app in
            guard let bid = app.bundleIdentifier else { return true }
            if seen.contains(bid) { return false }
            seen.insert(bid)
            return true
        }

        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        cachedApps = apps
        return apps
    }

    private static func addApp(at path: String, to apps: inout [LaunchpadApp]) {
        let url = URL(fileURLWithPath: path)
        let name = url.deletingPathExtension().lastPathComponent
        let rawIcon = NSWorkspace.shared.icon(forFile: path)
        // Pre-render to exact display size as bitmap — eliminates per-frame scaling
        let icon = prerenderIcon(rawIcon, toSize: LaunchpadConstants.iconSize)
        let bundleId = Bundle(path: path)?.bundleIdentifier
        let isUtility = path.contains("/Utilities/")
        apps.append(LaunchpadApp(name: name, icon: icon, url: url, bundleIdentifier: bundleId, isUtility: isUtility))
    }

    /// Rasterizes a multi-rep icon to an exact-size bitmap. Drawing a pre-rendered
    /// bitmap is a simple blit — no scaling, no rep selection, no interpolation.
    private static func prerenderIcon(_ source: NSImage, toSize size: CGFloat) -> NSImage {
        let scale: CGFloat = 2.0  // @2x for retina
        let px = Int(size * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return source }

        rep.size = NSSize(width: size, height: size)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        source.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                    from: .zero, operation: .sourceOver, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: NSSize(width: size, height: size))
        result.addRepresentation(rep)
        return result
    }
}

// MARK: - Launchpad Window (key + keyboard shortcuts)

private class LaunchpadWindow: NSWindow {
    override var canBecomeKey: Bool { true }

    var dismissHandler: (() -> Void)?
    var keyboardHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command, event.charactersIgnoringModifiers == "w" {
            dismissHandler?()
            return
        }
        if let handler = keyboardHandler, handler(event) {
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Collection View (forwards background clicks + page swipe)

private class LaunchpadCollectionView: NSCollectionView {
    var onBackgroundClick: (() -> Void)?
    var onPageSwipe: ((Int) -> Void)?  // -1 = prev, +1 = next

    private var swipeAccumulator: CGFloat = 0
    private var isTrackpadSwiping = false

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if indexPathForItem(at: point) != nil {
            super.mouseDown(with: event)
        } else {
            onBackgroundClick?()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.hasPreciseScrollingDeltas {
            // Trackpad gesture — accumulate horizontal delta
            swipeAccumulator += event.scrollingDeltaX

            if event.phase == .ended || event.phase == .cancelled {
                if swipeAccumulator > 60 {
                    onPageSwipe?(-1)  // swipe right → previous page
                } else if swipeAccumulator < -60 {
                    onPageSwipe?(1)   // swipe left → next page
                }
                swipeAccumulator = 0
            }
            // Don't call super — suppress default scrolling
        } else {
            // Discrete mouse wheel
            let delta = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : -event.scrollingDeltaY
            if delta > 2 {
                onPageSwipe?(-1)
            } else if delta < -2 {
                onPageSwipe?(1)
            }
        }
    }
}

// MARK: - Page Indicator Dots

private class PageDotsView: NSView {
    var numberOfPages: Int = 1 {
        didSet { if numberOfPages != oldValue { needsDisplay = true } }
    }
    var currentPage: Int = 0 {
        didSet { if currentPage != oldValue { needsDisplay = true } }
    }
    var onPageClicked: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard numberOfPages > 1 else { return }

        let dotSize = LaunchpadConstants.pageDotSize
        let spacing = LaunchpadConstants.pageDotSpacing
        let totalWidth = CGFloat(numberOfPages) * dotSize + CGFloat(numberOfPages - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.midY

        for i in 0..<numberOfPages {
            let x = startX + CGFloat(i) * (dotSize + spacing)
            let rect = NSRect(x: x, y: centerY - dotSize / 2, width: dotSize, height: dotSize)
            let path = NSBezierPath(ovalIn: rect)
            if i == currentPage {
                NSColor(white: 1.0, alpha: 0.95).setFill()
            } else {
                NSColor(white: 1.0, alpha: 0.3).setFill()
            }
            path.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard numberOfPages > 1 else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let dotSize = LaunchpadConstants.pageDotSize
        let spacing = LaunchpadConstants.pageDotSpacing
        let totalWidth = CGFloat(numberOfPages) * dotSize + CGFloat(numberOfPages - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2

        for i in 0..<numberOfPages {
            let x = startX + CGFloat(i) * (dotSize + spacing)
            let hitRect = NSRect(x: x - 6, y: 0, width: dotSize + 12, height: bounds.height)
            if hitRect.contains(loc) {
                onPageClicked?(i)
                return
            }
        }
    }
}

// MARK: - Launchpad Window Controller

class LaunchpadWindowController: NSWindowController {

    var onDismiss: (() -> Void)?

    private var allApps: [LaunchpadApp] = []
    private var entries: [LaunchpadEntry] = []
    private var folderOverlay: FolderOverlayView?
    private var folderSourceRect: NSRect = .zero
    private var cachedArrangement: LaunchpadArrangement?
    private var entriesDirty = true

    // Pagination
    private var pages: [[LaunchpadEntry]] = [[]]
    private var currentPage: Int = 0
    private var columnsPerPage: Int = 7
    private var rowsPerPage: Int = 5
    private var itemsPerPage: Int { columnsPerPage * rowsPerPage }
    private var isSearching: Bool = false
    private var isTransitioning: Bool = false

    // Keyboard navigation
    private var keyboardIndex: Int? = nil  // index within current page display

    // UI
    private let backgroundView = NSVisualEffectView()
    private let dimView = DimView()
    private let searchField = NSSearchField()
    private let scrollView = NSScrollView()
    private let collectionView = LaunchpadCollectionView()
    private let closeButton = NSButton()
    private let pageDots = PageDotsView()

    // Jiggle mode
    private var isJiggling = false
    private var highlightedDropTarget: Int?

    /// Items currently shown: either current page or all search results.
    private var displayEntries: [LaunchpadEntry] {
        if isSearching {
            return entries
        }
        guard currentPage >= 0, currentPage < pages.count else { return [] }
        return pages[currentPage]
    }

    convenience init() {
        let frame = Self.launchpadFrame(for: NSScreen.main ?? NSScreen.screens[0])
        let lpWindow = LaunchpadWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        lpWindow.level = .floating
        lpWindow.isOpaque = false
        lpWindow.backgroundColor = .clear
        lpWindow.hasShadow = true
        lpWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        self.init(window: lpWindow)

        lpWindow.dismissHandler = { [weak self] in self?.dismiss() }
        lpWindow.keyboardHandler = { [weak self] event in
            self?.handleKeyboard(event) ?? false
        }

        // Rounded corners
        lpWindow.contentView?.wantsLayer = true
        lpWindow.contentView?.layer?.cornerRadius = LaunchpadConstants.windowCornerRadius
        lpWindow.contentView?.layer?.masksToBounds = true

        setupUI()
        loadApps()
    }

    private static func launchpadFrame(for screen: NSScreen) -> NSRect {
        let sf = screen.visibleFrame
        let fraction = LaunchpadConstants.windowScreenFraction
        let w = sf.width * fraction
        let h = sf.height * fraction
        let x = sf.origin.x + (sf.width - w) / 2
        let y = sf.origin.y + (sf.height - h) / 2
        return NSRect(x: x, y: y, width: w, height: h)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Blurred background
        backgroundView.material = .fullScreenUI
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.appearance = NSAppearance(named: .darkAqua)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundView)

        // Dark overlay — click to dismiss
        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.onClick = { [weak self] in self?.handleBackgroundClick() }
        contentView.addSubview(dimView)

        // Search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search"
        searchField.font = NSFont.systemFont(ofSize: 16)
        searchField.appearance = NSAppearance(named: .darkAqua)
        searchField.focusRingType = .none
        searchField.delegate = self
        contentView.addSubview(searchField)

        // Close button (top-left)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .circular
        closeButton.isBordered = false
        closeButton.wantsLayer = true
        closeButton.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        closeButton.layer?.cornerRadius = 14
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.contentTintColor = NSColor(white: 1.0, alpha: 0.8)
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)
        contentView.addSubview(closeButton)

        // Collection view — single page, no scrolling
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = LaunchpadConstants.itemSize
        layout.minimumInteritemSpacing = LaunchpadConstants.interitemSpacing
        layout.minimumLineSpacing = LaunchpadConstants.lineSpacing

        collectionView.collectionViewLayout = layout
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.register(LaunchpadItemView.self, forItemWithIdentifier: LaunchpadItemView.identifier)
        collectionView.onBackgroundClick = { [weak self] in self?.handleBackgroundClick() }
        collectionView.onPageSwipe = { [weak self] delta in self?.navigatePageBy(delta) }

        // Drag and drop
        collectionView.registerForDraggedTypes([.string])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)

        scrollView.documentView = collectionView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.wantsLayer = true
        contentView.addSubview(scrollView)

        // Long press for jiggle mode
        let longPress = NSPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = LaunchpadConstants.longPressMinDuration
        collectionView.addGestureRecognizer(longPress)

        // Right-click context menu
        let menu = NSMenu()
        let newFolderItem = NSMenuItem(title: "New Folder", action: #selector(contextNewFolder(_:)), keyEquivalent: "")
        newFolderItem.target = self
        menu.addItem(newFolderItem)
        let jiggleItem = NSMenuItem(title: "Edit Layout", action: #selector(contextEditLayout(_:)), keyEquivalent: "")
        jiggleItem.target = self
        menu.addItem(jiggleItem)
        collectionView.menu = menu

        // Page indicator dots
        pageDots.translatesAutoresizingMaskIntoConstraints = false
        pageDots.onPageClicked = { [weak self] page in self?.goToPage(page, animated: true) }
        contentView.addSubview(pageDots)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            dimView.topAnchor.constraint(equalTo: contentView.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: LaunchpadConstants.searchTopOffset),
            searchField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            searchField.widthAnchor.constraint(equalToConstant: LaunchpadConstants.searchFieldWidth),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 30),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: pageDots.topAnchor),

            pageDots.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            pageDots.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            pageDots.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            pageDots.heightAnchor.constraint(equalToConstant: LaunchpadConstants.pageDotsHeight),
        ])
    }

    @objc private func closeButtonClicked() {
        dismiss()
    }

    private func handleBackgroundClick() {
        keyboardIndex = nil
        updateKeyboardHighlight()
        if isJiggling {
            exitJiggleMode()
        } else if folderOverlay != nil {
            closeFolderOverlay(animated: true)
        } else {
            dismiss()
        }
    }

    // MARK: - Data Loading

    private func loadApps() {
        guard allApps.isEmpty else { return }  // already loaded
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = LaunchpadAppScanner.scan()
            DispatchQueue.main.async {
                self?.allApps = apps
                self?.cachedArrangement = LaunchpadPersistence.load()
                self?.buildEntries(searchText: "")
                self?.entriesDirty = false
            }
        }
    }

    private func buildEntries(searchText: String) {
        let apps: [LaunchpadApp]
        if searchText.isEmpty {
            apps = allApps
        } else {
            let q = searchText.lowercased()
            apps = allApps.filter { $0.name.lowercased().contains(q) }
        }

        if searchText.isEmpty {
            // Restore from cached arrangement
            if let arrangement = cachedArrangement {
                entries = restoreFromArrangement(arrangement, allApps: apps)
                paginateEntries()
                reloadCurrentPage()
                return
            }

            // Default: group utilities into a folder
            var utilities: [LaunchpadApp] = []
            var regular: [LaunchpadApp] = []
            for app in apps {
                if app.isUtility {
                    utilities.append(app)
                } else {
                    regular.append(app)
                }
            }
            entries = regular.map { .app($0) }
            if !utilities.isEmpty {
                entries.append(.folder(LaunchpadFolder(name: "Utilities", apps: utilities)))
            }
        } else {
            entries = apps.map { .app($0) }
        }

        entries.sort { $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending }
        paginateEntries()
        reloadCurrentPage()
    }

    private func restoreFromArrangement(_ arrangement: LaunchpadArrangement, allApps: [LaunchpadApp]) -> [LaunchpadEntry] {
        let appsByBundleId = Dictionary(allApps.compactMap { app -> (String, LaunchpadApp)? in
            guard let bid = app.bundleIdentifier else { return nil }
            return (bid, app)
        }, uniquingKeysWith: { first, _ in first })

        var usedBundleIds = Set<String>()
        var result: [LaunchpadEntry] = []

        for entry in arrangement.entries {
            switch entry {
            case .app(let bundleId):
                if let app = appsByBundleId[bundleId] {
                    result.append(.app(app))
                    usedBundleIds.insert(bundleId)
                }
            case .folder(let name, let bundleIds):
                let folderApps = bundleIds.compactMap { appsByBundleId[$0] }
                if folderApps.count == 1 {
                    result.append(.app(folderApps[0]))
                    usedBundleIds.formUnion(bundleIds)
                } else if !folderApps.isEmpty {
                    result.append(.folder(LaunchpadFolder(name: name, apps: folderApps)))
                    usedBundleIds.formUnion(bundleIds)
                }
            }
        }

        // Append new apps not in saved arrangement
        for app in allApps {
            guard let bid = app.bundleIdentifier else {
                result.append(.app(app))
                continue
            }
            if !usedBundleIds.contains(bid) {
                result.append(.app(app))
            }
        }

        return result
    }

    private func saveArrangement() {
        var arrangementEntries: [LaunchpadArrangement.Entry] = []
        for entry in entries {
            switch entry {
            case .app(let app):
                if let bid = app.bundleIdentifier {
                    arrangementEntries.append(.app(bundleIdentifier: bid))
                }
            case .folder(let folder):
                let bids = folder.apps.compactMap(\.bundleIdentifier)
                arrangementEntries.append(.folder(name: folder.name, appBundleIdentifiers: bids))
            }
        }
        let arrangement = LaunchpadArrangement(entries: arrangementEntries)
        cachedArrangement = arrangement
        LaunchpadPersistence.save(arrangement)
    }

    // MARK: - Pagination

    private func calculateGrid() {
        let bounds = scrollView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        let itemW = LaunchpadConstants.itemSize.width
        let itemH = LaunchpadConstants.itemSize.height
        let hGap = LaunchpadConstants.interitemSpacing
        let vGap = LaunchpadConstants.lineSpacing
        let inset = LaunchpadConstants.sectionInset

        let availW = bounds.width - inset.left - inset.right
        let availH = bounds.height - inset.top - inset.bottom

        columnsPerPage = min(LaunchpadConstants.maxColumns,
                             max(1, Int((availW + hGap) / (itemW + hGap))))
        rowsPerPage = min(LaunchpadConstants.maxRows,
                          max(1, Int((availH + vGap) / (itemH + vGap))))
    }

    private func paginateEntries() {
        calculateGrid()
        let perPage = itemsPerPage
        guard perPage > 0 else {
            pages = [entries]
            return
        }
        pages = stride(from: 0, to: max(entries.count, 1), by: perPage).map {
            Array(entries[$0..<min($0 + perPage, entries.count)])
        }
        if pages.isEmpty { pages = [[]] }
        currentPage = min(currentPage, pages.count - 1)
        updatePageDots()
    }

    private func centeredSectionInset() -> NSEdgeInsets {
        let bounds = scrollView.bounds
        let itemW = LaunchpadConstants.itemSize.width
        let itemH = LaunchpadConstants.itemSize.height
        let hGap = LaunchpadConstants.interitemSpacing
        let vGap = LaunchpadConstants.lineSpacing

        let gridW = CGFloat(columnsPerPage) * itemW + CGFloat(max(0, columnsPerPage - 1)) * hGap
        let gridH = CGFloat(rowsPerPage) * itemH + CGFloat(max(0, rowsPerPage - 1)) * vGap

        let hInset = max(20, (bounds.width - gridW) / 2)
        let vInset = max(10, (bounds.height - gridH) / 2)

        return NSEdgeInsets(top: vInset, left: hInset, bottom: vInset, right: hInset)
    }

    private func reloadCurrentPage() {
        if let layout = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
            layout.sectionInset = isSearching ? LaunchpadConstants.sectionInset : centeredSectionInset()
        }
        collectionView.reloadData()
        updatePageDots()
    }

    private func updatePageDots() {
        let count = isSearching ? 1 : pages.count
        pageDots.numberOfPages = count
        pageDots.currentPage = currentPage
        pageDots.isHidden = count <= 1
    }

    // MARK: - Page Navigation

    private func navigatePageBy(_ delta: Int) {
        goToPage(currentPage + delta, animated: true)
    }

    private func goToPage(_ page: Int, animated: Bool) {
        guard !isSearching, !isTransitioning else { return }
        let targetPage = max(0, min(page, pages.count - 1))
        guard targetPage != currentPage else { return }

        keyboardIndex = nil
        SoundService.playNavigate()

        if animated {
            isTransitioning = true
            let direction: CATransitionSubtype = targetPage > currentPage ? .fromRight : .fromLeft

            let transition = CATransition()
            transition.type = .push
            transition.subtype = direction
            transition.duration = LaunchpadConstants.pageTransitionDuration
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            scrollView.layer?.add(transition, forKey: "pageTransition")

            currentPage = targetPage
            reloadCurrentPage()

            // Clear flag after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + transition.duration) { [weak self] in
                self?.isTransitioning = false
            }
        } else {
            currentPage = targetPage
            reloadCurrentPage()
        }
    }

    // MARK: - Public API

    func show() {
        guard let screen = NSScreen.main else { return }
        window?.setFrame(Self.launchpadFrame(for: screen), display: true)

        // Recalculate grid for current window size
        calculateGrid()

        if entriesDirty {
            buildEntries(searchText: "")
            entriesDirty = false
        } else {
            paginateEntries()
            reloadCurrentPage()
        }

        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)

        window?.alphaValue = 0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = LaunchpadConstants.showDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.window?.animator().alphaValue = 1.0
        }
    }

    func dismiss() {
        exitJiggleMode()
        closeFolderOverlay(animated: false)
        keyboardIndex = nil
        onDismiss?()
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = LaunchpadConstants.dismissDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
            if let self = self, !self.searchField.stringValue.isEmpty {
                self.searchField.stringValue = ""
                self.isSearching = false
                self.buildEntries(searchText: "")
            }
        })
    }

    var isVisible: Bool {
        window?.isVisible ?? false
    }

    func dismissIfShowing() {
        guard isVisible else { return }
        dismiss()
    }

    func toggle() {
        if isVisible { dismiss() } else { show() }
    }

    // MARK: - Keyboard Navigation

    override func cancelOperation(_ sender: Any?) {
        if folderOverlay != nil {
            closeFolderOverlay(animated: true)
        } else if isJiggling {
            exitJiggleMode()
        } else {
            dismiss()
        }
    }

    private func handleKeyboard(_ event: NSEvent) -> Bool {
        // Don't handle if search field is first responder and has text
        if window?.firstResponder === searchField.currentEditor(), !searchField.stringValue.isEmpty {
            return false
        }

        let display = displayEntries
        guard !display.isEmpty else { return false }

        switch event.keyCode {
        case 123: // Left arrow
            moveKeyboardIndex(by: -1)
            return true
        case 124: // Right arrow
            moveKeyboardIndex(by: 1)
            return true
        case 126: // Up arrow
            moveKeyboardIndex(by: -columnsPerPage)
            return true
        case 125: // Down arrow
            moveKeyboardIndex(by: columnsPerPage)
            return true
        case 36, 76: // Return / Enter
            if let idx = keyboardIndex, idx < display.count {
                activateEntry(at: idx)
            }
            return true
        case 49: // Spacebar
            if let idx = keyboardIndex, idx < display.count {
                activateEntry(at: idx)
                return true
            }
            return false
        default:
            return false
        }
    }

    private func moveKeyboardIndex(by delta: Int) {
        let display = displayEntries
        guard !display.isEmpty else { return }

        if keyboardIndex == nil {
            // First key press activates keyboard mode at first item
            keyboardIndex = 0
            updateKeyboardHighlight()
            return
        }

        let current = keyboardIndex!
        let newIndex = current + delta

        if newIndex < 0 {
            // Wrap to previous page
            if !isSearching && currentPage > 0 {
                goToPage(currentPage - 1, animated: true)
                // Place highlight at last item of new page
                DispatchQueue.main.asyncAfter(deadline: .now() + LaunchpadConstants.pageTransitionDuration + 0.05) { [weak self] in
                    guard let self = self else { return }
                    self.keyboardIndex = max(0, self.displayEntries.count - 1)
                    self.updateKeyboardHighlight()
                }
            }
            return
        }

        if newIndex >= display.count {
            // Wrap to next page
            if !isSearching && currentPage < pages.count - 1 {
                goToPage(currentPage + 1, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + LaunchpadConstants.pageTransitionDuration + 0.05) { [weak self] in
                    self?.keyboardIndex = 0
                    self?.updateKeyboardHighlight()
                }
            }
            return
        }

        keyboardIndex = newIndex
        SoundService.playNavigate()
        updateKeyboardHighlight()
    }

    private func updateKeyboardHighlight() {
        for item in collectionView.visibleItems() {
            if let lpItem = item as? LaunchpadItemView {
                lpItem.isKeyboardHighlighted = false
            }
        }
        guard let idx = keyboardIndex else { return }
        let indexPath = IndexPath(item: idx, section: 0)
        if let item = collectionView.item(at: indexPath) as? LaunchpadItemView {
            item.isKeyboardHighlighted = true
        }
    }

    private func activateEntry(at displayIndex: Int) {
        let display = displayEntries
        guard displayIndex < display.count else { return }
        let itemView = collectionView.item(at: IndexPath(item: displayIndex, section: 0))?.view

        switch display[displayIndex] {
        case .app(let app):
            launchApp(app, fromItemView: itemView)
        case .folder(let folder):
            let globalIdx = globalIndex(forDisplayIndex: displayIndex)
            showFolder(folder, from: IndexPath(item: displayIndex, section: 0), globalIndex: globalIdx)
        }
    }

    /// Convert a display-local index to the global `entries` array index.
    private func globalIndex(forDisplayIndex displayIndex: Int) -> Int {
        if isSearching {
            return displayIndex
        }
        return currentPage * itemsPerPage + displayIndex
    }

    // MARK: - App Launching

    private func launchApp(_ app: LaunchpadApp, fromItemView itemView: NSView? = nil) {
        guard let itemView = itemView else {
            NSWorkspace.shared.open(app.url)
            dismiss()
            return
        }

        itemView.wantsLayer = true
        guard let layer = itemView.layer else {
            NSWorkspace.shared.open(app.url)
            dismiss()
            return
        }

        let frame = itemView.frame
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.position = CGPoint(x: frame.midX, y: frame.midY)
        layer.zPosition = 1000

        let duration = LaunchpadConstants.launchDuration

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 1.0
        scaleAnim.toValue = LaunchpadConstants.launchScale
        scaleAnim.duration = duration
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        scaleAnim.fillMode = .forwards
        scaleAnim.isRemovedOnCompletion = false

        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0
        fadeAnim.toValue = 0.0
        fadeAnim.duration = duration
        fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fadeAnim.fillMode = .forwards
        fadeAnim.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            NSWorkspace.shared.open(app.url)
            layer.removeAllAnimations()
            layer.transform = CATransform3DIdentity
            layer.opacity = 1.0
            layer.zPosition = 0
            layer.anchorPoint = CGPoint(x: 0, y: 0)
            layer.position = frame.origin
            self?.dismissAfterLaunch()
        }
        layer.add(scaleAnim, forKey: "launchScale")
        layer.add(fadeAnim, forKey: "launchFade")
        CATransaction.commit()

        exitJiggleMode()
        closeFolderOverlay(animated: false)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.backgroundView.animator().alphaValue = 0
            self.dimView.animator().alphaValue = 0
            self.searchField.animator().alphaValue = 0
            self.closeButton.animator().alphaValue = 0
            self.pageDots.animator().alphaValue = 0
            for visibleItem in self.collectionView.visibleItems() where visibleItem.view !== itemView {
                visibleItem.view.animator().alphaValue = 0
            }
        }
    }

    private func dismissAfterLaunch() {
        window?.orderOut(nil)
        backgroundView.alphaValue = 1
        dimView.alphaValue = 1
        searchField.alphaValue = 1
        closeButton.alphaValue = 1
        pageDots.alphaValue = 1
        for item in collectionView.visibleItems() {
            item.view.alphaValue = 1
        }
        if !searchField.stringValue.isEmpty {
            searchField.stringValue = ""
            isSearching = false
            buildEntries(searchText: "")
        }
    }

    // MARK: - Jiggle Mode

    @objc private func handleLongPress(_ gesture: NSPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        if !isJiggling {
            enterJiggleMode()
        }
    }

    private func enterJiggleMode() {
        isJiggling = true
        keyboardIndex = nil
        updateKeyboardHighlight()
        for item in collectionView.visibleItems() {
            addJiggleAnimation(to: item)
        }
    }

    private func exitJiggleMode() {
        guard isJiggling else { return }
        isJiggling = false
        highlightedDropTarget = nil
        for item in collectionView.visibleItems() {
            item.view.layer?.removeAnimation(forKey: "jiggle")
            if let lpItem = item as? LaunchpadItemView {
                lpItem.isDropTarget = false
            }
        }
    }

    private func addJiggleAnimation(to item: NSCollectionViewItem) {
        guard isJiggling else { return }
        item.view.wantsLayer = true

        let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let angle = LaunchpadConstants.jiggleAngle
        anim.values = [angle, -angle, angle]
        anim.duration = LaunchpadConstants.jiggleDuration
        anim.repeatCount = .infinity
        anim.isAdditive = true
        anim.timeOffset = Double.random(in: 0..<anim.duration)
        item.view.layer?.add(anim, forKey: "jiggle")
    }

    // MARK: - Context Menu

    @objc private func contextNewFolder(_ sender: Any?) {
        let folder = LaunchpadFolder(name: "New Folder", apps: [])
        entries.append(.folder(folder))
        saveArrangement()
        paginateEntries()
        reloadCurrentPage()
        if !isJiggling { enterJiggleMode() }
    }

    @objc private func contextEditLayout(_ sender: Any?) {
        if isJiggling {
            exitJiggleMode()
        } else {
            enterJiggleMode()
        }
    }

    // MARK: - Folders

    private func showFolder(_ folder: LaunchpadFolder, from indexPath: IndexPath, globalIndex: Int) {
        closeFolderOverlay(animated: false)
        guard let contentView = window?.contentView else { return }

        if let attrs = collectionView.layoutAttributesForItem(at: indexPath) {
            folderSourceRect = collectionView.convert(attrs.frame, to: contentView)
        } else {
            folderSourceRect = NSRect(x: contentView.bounds.midX - 66, y: contentView.bounds.midY - 66, width: 132, height: 132)
        }

        let overlay = FolderOverlayView(folder: folder)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.onAppClicked = { [weak self] app, itemView in self?.launchApp(app, fromItemView: itemView) }
        overlay.onDismiss = { [weak self] in self?.closeFolderOverlay(animated: true) }
        overlay.onRemoveApp = { [weak self] appIndex in self?.removeAppFromFolder(atGlobal: globalIndex, appIndex: appIndex) }
        overlay.onRenameFolder = { [weak self] newName in self?.renameFolder(atGlobal: globalIndex, to: newName) }
        overlay.isJiggling = isJiggling
        contentView.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        folderOverlay = overlay

        // Force layout so containerView has its final frame
        overlay.layoutSubtreeIfNeeded()

        let containerView = overlay.containerView
        containerView.wantsLayer = true
        guard let containerLayer = containerView.layer else {
            overlay.alphaValue = 1.0
            return
        }

        containerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        let cf = containerView.frame
        containerLayer.position = CGPoint(x: cf.midX, y: cf.midY)

        let scaleX = folderSourceRect.width / cf.width
        let scaleY = folderSourceRect.height / cf.height
        let tx = folderSourceRect.midX - cf.midX
        let ty = folderSourceRect.midY - cf.midY

        var initial = CATransform3DIdentity
        initial = CATransform3DTranslate(initial, tx, ty, 0)
        initial = CATransform3DScale(initial, scaleX, scaleY, 1)

        overlay.alphaValue = 0

        let spring = CASpringAnimation(keyPath: "transform")
        spring.fromValue = NSValue(caTransform3D: initial)
        spring.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        spring.damping = LaunchpadConstants.springDamping
        spring.stiffness = LaunchpadConstants.springStiffness
        spring.mass = 1.0
        spring.duration = spring.settlingDuration

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer.transform = CATransform3DIdentity
        containerLayer.add(spring, forKey: "popOpen")
        CATransaction.commit()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            overlay.animator().alphaValue = 1.0
        }
    }

    private func closeFolderOverlay(animated: Bool) {
        guard let overlay = folderOverlay else { return }
        folderOverlay = nil

        if animated {
            let containerView = overlay.containerView
            containerView.wantsLayer = true
            guard let containerLayer = containerView.layer else {
                overlay.removeFromSuperview()
                return
            }

            let cf = containerView.frame
            let scaleX = folderSourceRect.width / max(cf.width, 1)
            let scaleY = folderSourceRect.height / max(cf.height, 1)
            let tx = folderSourceRect.midX - cf.midX
            let ty = folderSourceRect.midY - cf.midY

            var target = CATransform3DIdentity
            target = CATransform3DTranslate(target, tx, ty, 0)
            target = CATransform3DScale(target, scaleX, scaleY, 1)

            let spring = CASpringAnimation(keyPath: "transform")
            spring.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            spring.toValue = NSValue(caTransform3D: target)
            spring.damping = LaunchpadConstants.springDamping * 1.5
            spring.stiffness = LaunchpadConstants.springStiffness
            spring.mass = 1.0
            spring.duration = spring.settlingDuration

            CATransaction.begin()
            CATransaction.setCompletionBlock { overlay.removeFromSuperview() }
            CATransaction.setDisableActions(true)
            containerLayer.transform = target
            containerLayer.add(spring, forKey: "popClose")
            CATransaction.commit()

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = LaunchpadConstants.folderCloseDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                overlay.animator().alphaValue = 0
            }
        } else {
            overlay.removeFromSuperview()
        }
    }

    // MARK: - Folder Manipulation

    private func createOrAddToFolder(sourceDisplayIndex: Int, targetDisplayIndex: Int) {
        let srcGlobal = globalIndex(forDisplayIndex: sourceDisplayIndex)
        let tgtGlobal = globalIndex(forDisplayIndex: targetDisplayIndex)
        guard srcGlobal != tgtGlobal,
              srcGlobal < entries.count,
              tgtGlobal < entries.count else { return }

        let sourceEntry = entries[srcGlobal]
        let targetEntry = entries[tgtGlobal]
        guard case .app(let sourceApp) = sourceEntry else { return }

        switch targetEntry {
        case .app(let targetApp):
            let folder = LaunchpadFolder(name: "New Folder", apps: [targetApp, sourceApp])
            entries[tgtGlobal] = .folder(folder)
            entries.remove(at: srcGlobal)
        case .folder(var folder):
            folder.apps.append(sourceApp)
            entries[tgtGlobal] = .folder(folder)
            entries.remove(at: srcGlobal)
        }

        saveArrangement()
        paginateEntries()
        reloadCurrentPage()
    }

    private func reorderEntry(sourceDisplayIndex: Int, targetDisplayIndex: Int) {
        let srcGlobal = globalIndex(forDisplayIndex: sourceDisplayIndex)
        let tgtGlobal = globalIndex(forDisplayIndex: targetDisplayIndex)
        guard srcGlobal != tgtGlobal,
              srcGlobal < entries.count,
              tgtGlobal <= entries.count else { return }

        let entry = entries.remove(at: srcGlobal)
        let insertAt = tgtGlobal > srcGlobal ? tgtGlobal - 1 : tgtGlobal
        entries.insert(entry, at: min(insertAt, entries.count))

        saveArrangement()
        paginateEntries()
        reloadCurrentPage()
    }

    private func removeAppFromFolder(atGlobal folderIndex: Int, appIndex: Int) {
        guard folderIndex < entries.count,
              case .folder(var folder) = entries[folderIndex],
              appIndex < folder.apps.count else { return }

        let app = folder.apps.remove(at: appIndex)

        if folder.apps.count <= 1 {
            if let remainingApp = folder.apps.first {
                entries[folderIndex] = .app(remainingApp)
            } else {
                entries.remove(at: folderIndex)
            }
        } else {
            entries[folderIndex] = .folder(folder)
        }

        entries.append(.app(app))

        saveArrangement()
        closeFolderOverlay(animated: true)
        paginateEntries()
        reloadCurrentPage()
    }

    private func renameFolder(atGlobal folderIndex: Int, to newName: String) {
        guard folderIndex < entries.count,
              case .folder(var folder) = entries[folderIndex] else { return }
        folder.name = newName
        entries[folderIndex] = .folder(folder)
        saveArrangement()
        // No need to reload — overlay already updated
    }
}

// MARK: - NSCollectionViewDataSource & Delegate

extension LaunchpadWindowController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        displayEntries.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let view = collectionView.makeItem(withIdentifier: LaunchpadItemView.identifier, for: indexPath)
        guard let item = view as? LaunchpadItemView else { return view }

        let display = displayEntries
        guard indexPath.item < display.count else { return view }

        switch display[indexPath.item] {
        case .app(let app):
            item.configureApp(name: app.name, icon: app.icon)
        case .folder(let folder):
            item.configureFolder(name: folder.name, appIcons: folder.apps.map(\.icon))
        }

        item.isDropTarget = (highlightedDropTarget == indexPath.item)
        item.isKeyboardHighlighted = (keyboardIndex == indexPath.item)

        if isJiggling {
            addJiggleAnimation(to: item)
        }

        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        collectionView.deselectItems(at: indexPaths)

        keyboardIndex = nil
        updateKeyboardHighlight()

        let display = displayEntries
        guard indexPath.item < display.count else { return }

        let itemView = collectionView.item(at: indexPath)?.view

        switch display[indexPath.item] {
        case .app(let app):
            launchApp(app, fromItemView: itemView)
        case .folder(let folder):
            let globalIdx = globalIndex(forDisplayIndex: indexPath.item)
            showFolder(folder, from: indexPath, globalIndex: globalIdx)
        }
    }

    // MARK: - Drag Source

    func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        isJiggling
    }

    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard isJiggling else { return nil }
        return "\(indexPath.item)" as NSString
    }

    // MARK: - Drag Destination

    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        let targetIndex = proposedDropIndexPath.pointee.item
        let display = displayEntries

        if proposedDropOperation.pointee == .on && targetIndex < display.count {
            if let sourceStr = draggingInfo.draggingPasteboard.string(forType: .string),
               let sourceIndex = Int(sourceStr),
               sourceIndex < display.count {
                if case .folder = display[sourceIndex] {
                    updateDropHighlight(nil)
                    return []
                }
            }
            updateDropHighlight(targetIndex)
            return .move
        } else {
            updateDropHighlight(nil)
            return .move
        }
    }

    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        updateDropHighlight(nil)

        guard let sourceStr = draggingInfo.draggingPasteboard.string(forType: .string),
              let sourceIndex = Int(sourceStr) else { return false }

        if dropOperation == .on {
            createOrAddToFolder(sourceDisplayIndex: sourceIndex, targetDisplayIndex: indexPath.item)
        } else {
            reorderEntry(sourceDisplayIndex: sourceIndex, targetDisplayIndex: indexPath.item)
        }
        return true
    }

    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, dragOperation operation: NSDragOperation) {
        updateDropHighlight(nil)
    }

    private func updateDropHighlight(_ index: Int?) {
        guard highlightedDropTarget != index else { return }
        if let old = highlightedDropTarget,
           let item = collectionView.item(at: IndexPath(item: old, section: 0)) as? LaunchpadItemView {
            item.isDropTarget = false
        }
        highlightedDropTarget = index
        if let new = index,
           let item = collectionView.item(at: IndexPath(item: new, section: 0)) as? LaunchpadItemView {
            item.isDropTarget = true
        }
    }
}

// MARK: - NSSearchFieldDelegate

extension LaunchpadWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        let text = field.stringValue
        isSearching = !text.isEmpty
        keyboardIndex = nil
        currentPage = 0
        buildEntries(searchText: text)
    }
}

// MARK: - Dim Overlay (click to dismiss)

private class DimView: NSView {
    var onClick: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.3).cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

// MARK: - Launchpad Grid Item

class LaunchpadItemView: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("LaunchpadItemView")

    var isDropTarget: Bool = false {
        didSet { dropHighlightView.isHidden = !isDropTarget }
    }

    var isKeyboardHighlighted: Bool = false {
        didSet { keyboardHighlightView.isHidden = !isKeyboardHighlighted }
    }

    private let iconView: NSImageView = {
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    private let nameLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.translatesAutoresizingMaskIntoConstraints = false
        l.alignment = .center
        l.font = NSFont.systemFont(ofSize: 12)
        l.textColor = .white
        l.maximumNumberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let folderIconView: FolderIconView = {
        let v = FolderIconView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let dropHighlightView: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.3).cgColor
        v.layer?.cornerRadius = 16
        v.layer?.borderWidth = 2
        v.layer?.borderColor = NSColor(white: 1.0, alpha: 0.5).cgColor
        v.isHidden = true
        return v
    }()

    private let keyboardHighlightView: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.15).cgColor
        v.layer?.cornerRadius = 14
        v.layer?.borderWidth = 2
        v.layer?.borderColor = NSColor(calibratedRed: 0.4, green: 0.6, blue: 1.0, alpha: 0.8).cgColor
        v.isHidden = true
        return v
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        view.layer?.shouldRasterize = true
        view.layer?.rasterizationScale = (NSScreen.main?.backingScaleFactor ?? 2.0)

        view.layer?.shadowOffset = CGSize(width: 0, height: -2)
        view.layer?.shadowRadius = 4
        view.layer?.shadowColor = NSColor(white: 0, alpha: 0.5).cgColor
        view.layer?.shadowOpacity = 1.0

        view.addSubview(keyboardHighlightView)
        view.addSubview(dropHighlightView)
        view.addSubview(iconView)
        view.addSubview(folderIconView)
        view.addSubview(nameLabel)

        let d = LaunchpadConstants.iconSize
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: d),
            iconView.heightAnchor.constraint(equalToConstant: d),

            folderIconView.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            folderIconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            folderIconView.widthAnchor.constraint(equalToConstant: d),
            folderIconView.heightAnchor.constraint(equalToConstant: d),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            dropHighlightView.topAnchor.constraint(equalTo: view.topAnchor, constant: -4),
            dropHighlightView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -4),
            dropHighlightView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 4),
            dropHighlightView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 4),

            keyboardHighlightView.topAnchor.constraint(equalTo: view.topAnchor, constant: -6),
            keyboardHighlightView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -6),
            keyboardHighlightView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 6),
            keyboardHighlightView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 6),
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        view.layer?.removeAnimation(forKey: "jiggle")
        isDropTarget = false
        isKeyboardHighlighted = false
    }

    func configureApp(name: String, icon: NSImage) {
        nameLabel.stringValue = name
        iconView.image = icon
        iconView.isHidden = false
        folderIconView.isHidden = true
    }

    func configureFolder(name: String, appIcons: [NSImage]) {
        nameLabel.stringValue = name
        iconView.isHidden = true
        folderIconView.isHidden = false
        folderIconView.setIcons(appIcons)
    }
}

// MARK: - Folder Icon (3x3 mini grid — cached as bitmap)

private class FolderIconView: NSView {
    private var appIcons: [NSImage] = []
    private var cachedImage: NSImage?

    func setIcons(_ icons: [NSImage]) {
        appIcons = icons
        cachedImage = nil
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if let cached = cachedImage {
            cached.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
            return
        }

        renderFolderIcon()
        cachedImage?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    private func renderFolderIcon() {
        let size = bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let scale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
        let px = Int(size.width * scale)
        let py = Int(size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: py,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return }

        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect,
                                xRadius: LaunchpadConstants.folderIconCornerRadius,
                                yRadius: LaunchpadConstants.folderIconCornerRadius)
        NSColor(white: 1.0, alpha: 0.22).setFill()
        path.fill()
        NSColor(white: 1.0, alpha: 0.12).setStroke()
        path.lineWidth = 1
        path.stroke()

        let cols = 3
        let padding = LaunchpadConstants.folderIconPadding
        let gap = LaunchpadConstants.folderIconGap
        let available = rect.width - padding * 2 - gap * CGFloat(cols - 1)
        let miniSize = available / CGFloat(cols)

        for (i, icon) in appIcons.prefix(9).enumerated() {
            let row = i / cols
            let col = i % cols
            let x = padding + CGFloat(col) * (miniSize + gap)
            let y = rect.height - padding - CGFloat(row + 1) * miniSize - CGFloat(row) * gap
            icon.draw(in: NSRect(x: x, y: y, width: miniSize, height: miniSize),
                      from: .zero, operation: .sourceOver, fraction: 1.0)
        }

        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: size)
        result.addRepresentation(rep)
        cachedImage = result
    }
}

// MARK: - Folder Overlay (expanded folder with editable title)

class FolderOverlayView: NSView {
    var onAppClicked: ((LaunchpadApp, NSView?) -> Void)?
    var onDismiss: (() -> Void)?
    var onRemoveApp: ((Int) -> Void)?
    var onRenameFolder: ((String) -> Void)?
    var isJiggling: Bool = false

    private let folder: LaunchpadFolder
    let containerView = NSVisualEffectView()
    private let titleField = NSTextField()

    init(folder: LaunchpadFolder) {
        self.folder = folder
        super.init(frame: .zero)
        wantsLayer = true
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        layer?.backgroundColor = NSColor(white: 0, alpha: 0.4).cgColor

        containerView.material = .hudWindow
        containerView.blendingMode = .withinWindow
        containerView.state = .active
        containerView.appearance = NSAppearance(named: .darkAqua)
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 20
        containerView.layer?.masksToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        // Editable title field
        titleField.stringValue = folder.name
        titleField.font = NSFont.systemFont(ofSize: 22, weight: .medium)
        titleField.textColor = .white
        titleField.alignment = .center
        titleField.isBezeled = false
        titleField.drawsBackground = false
        titleField.isEditable = true
        titleField.isSelectable = true
        titleField.focusRingType = .none
        titleField.delegate = self
        titleField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleField)

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = LaunchpadConstants.folderItemSize
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 12
        layout.sectionInset = NSEdgeInsets(top: 10, left: 20, bottom: 20, right: 20)

        let cv = NSCollectionView()
        cv.collectionViewLayout = layout
        cv.backgroundColors = [.clear]
        cv.isSelectable = true
        cv.dataSource = self
        cv.delegate = self
        cv.register(FolderAppItemView.self, forItemWithIdentifier: FolderAppItemView.identifier)

        let scroll = NSScrollView()
        scroll.documentView = cv
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        containerView.addSubview(scroll)

        let rows = ceil(Double(folder.apps.count) / 4.0)
        let contentHeight = min(420, CGFloat(rows) * (LaunchpadConstants.folderItemSize.height + 12) + 80)

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: LaunchpadConstants.folderOverlayWidth),
            containerView.heightAnchor.constraint(equalToConstant: contentHeight),

            titleField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleField.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleField.widthAnchor.constraint(lessThanOrEqualTo: containerView.widthAnchor, constant: -40),

            scroll.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if !containerView.frame.contains(loc) {
            onDismiss?()
        }
    }
}

extension FolderOverlayView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        let newName = titleField.stringValue.trimmingCharacters(in: .whitespaces)
        if !newName.isEmpty {
            onRenameFolder?(newName)
        } else {
            titleField.stringValue = folder.name
        }
    }
}

extension FolderOverlayView: NSCollectionViewDataSource, NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        folder.apps.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let view = collectionView.makeItem(withIdentifier: FolderAppItemView.identifier, for: indexPath)
        if let item = view as? FolderAppItemView {
            let app = folder.apps[indexPath.item]
            item.configure(name: app.name, icon: app.icon)
            item.showRemoveButton = isJiggling
            item.onRemove = { [weak self] in
                self?.onRemoveApp?(indexPath.item)
            }
        }
        return view
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        collectionView.deselectItems(at: indexPaths)
        let itemView = collectionView.item(at: indexPath)?.view
        onAppClicked?(folder.apps[indexPath.item], itemView)
    }
}

// MARK: - Folder App Item (smaller, inside expanded folder)

private class FolderAppItemView: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("FolderAppItemView")

    var showRemoveButton: Bool = false {
        didSet { removeButton.isHidden = !showRemoveButton }
    }
    var onRemove: (() -> Void)?

    private let iconView: NSImageView = {
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    private let nameLabel: NSTextField = {
        let l = NSTextField(labelWithString: "")
        l.translatesAutoresizingMaskIntoConstraints = false
        l.alignment = .center
        l.font = NSFont.systemFont(ofSize: 10)
        l.textColor = .white
        l.maximumNumberOfLines = 1
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let removeButton: NSButton = {
        let b = NSButton(title: "", target: nil, action: nil)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.bezelStyle = .circular
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.8).cgColor
        b.layer?.cornerRadius = 10
        b.attributedTitle = NSAttributedString(
            string: "\u{2715}",
            attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            ]
        )
        b.isHidden = true
        return b
    }()

    override func loadView() {
        view = NSView()
        view.addSubview(iconView)
        view.addSubview(nameLabel)
        view.addSubview(removeButton)

        let iconSize = LaunchpadConstants.folderIconSize
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: view.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            removeButton.topAnchor.constraint(equalTo: view.topAnchor, constant: -6),
            removeButton.leadingAnchor.constraint(equalTo: iconView.leadingAnchor, constant: -6),
            removeButton.widthAnchor.constraint(equalToConstant: 20),
            removeButton.heightAnchor.constraint(equalToConstant: 20),
        ])

        removeButton.target = self
        removeButton.action = #selector(removeTapped)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        showRemoveButton = false
        onRemove = nil
    }

    @objc private func removeTapped() {
        onRemove?()
    }

    func configure(name: String, icon: NSImage) {
        nameLabel.stringValue = name
        iconView.image = icon
    }
}
