import Cocoa

class DesktopScreenSaverPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "desktopscreensaver" }
    var paneTitle: String { "Desktop & Screen Saver" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "photo", accessibilityDescription: "Desktop & Screen Saver") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] { ["desktop", "wallpaper", "background", "screen saver", "hot corner"] }
    var viewController: NSViewController { self }

    private let tabView = NSTabView()

    // Desktop tab
    private let wallpaperPreview = NSImageView()
    private let wallpaperGrid = NSCollectionView()
    private var wallpaperPaths: [URL] = []

    // Screen Saver tab
    private let screenSaverPopup = NSPopUpButton()
    private let startAfterLabel = NSTextField(labelWithString: "Start after:")
    private let startAfterPopup = NSPopUpButton()

    override func loadView() {
        view = NSView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let desktopTab = NSTabViewItem(identifier: "desktop")
        desktopTab.label = "Desktop"
        desktopTab.view = createDesktopTab()

        let screensaverTab = NSTabViewItem(identifier: "screensaver")
        screensaverTab.label = "Screen Saver"
        screensaverTab.view = createScreenSaverTab()

        tabView.addTabViewItem(desktopTab)
        tabView.addTabViewItem(screensaverTab)

        view.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])
    }

    private func createDesktopTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // Wallpaper preview
        wallpaperPreview.translatesAutoresizingMaskIntoConstraints = false
        wallpaperPreview.imageScaling = .scaleProportionallyUpOrDown
        wallpaperPreview.wantsLayer = true
        wallpaperPreview.layer?.cornerRadius = 6
        wallpaperPreview.layer?.borderWidth = 1
        wallpaperPreview.layer?.borderColor = NSColor.separatorColor.cgColor
        wallpaperPreview.widthAnchor.constraint(equalToConstant: 280).isActive = true
        wallpaperPreview.heightAnchor.constraint(equalToConstant: 175).isActive = true

        // Wallpaper grid in a scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = wallpaperGrid

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 80, height: 60)
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        wallpaperGrid.collectionViewLayout = layout
        wallpaperGrid.delegate = self
        wallpaperGrid.dataSource = self
        wallpaperGrid.backgroundColors = [.clear]
        wallpaperGrid.isSelectable = true
        wallpaperGrid.register(WallpaperItem.self, forItemWithIdentifier: WallpaperItem.identifier)

        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        // Choose button
        let chooseButton = NSButton(title: "Choose...", target: self, action: #selector(chooseWallpaper(_:)))

        stack.addArrangedSubview(wallpaperPreview)
        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(chooseButton)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    private func createScreenSaverTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        // Start after
        startAfterPopup.addItems(withTitles: ["Never", "1 Minute", "2 Minutes", "5 Minutes", "10 Minutes", "20 Minutes", "30 Minutes", "1 Hour"])
        startAfterPopup.target = self
        startAfterPopup.action = #selector(startAfterChanged(_:))
        let startRow = NSStackView(views: [startAfterLabel, startAfterPopup])
        startRow.spacing = 12

        // Hot corners button
        let hotCornersButton = NSButton(title: "Hot Corners...", target: self, action: #selector(showHotCorners(_:)))

        stack.addArrangedSubview(startRow)
        stack.addArrangedSubview(hotCornersButton)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    func reloadFromSystem() {
        // Current wallpaper
        if let screen = NSScreen.main,
           let url = NSWorkspace.shared.desktopImageURL(for: screen) {
            wallpaperPreview.image = NSImage(contentsOf: url)
        }

        // Load system wallpapers
        wallpaperPaths.removeAll()
        let searchPaths = [
            "/System/Library/Desktop Pictures",
            "/Library/Desktop Pictures",
        ]
        for path in searchPaths {
            let url = URL(fileURLWithPath: path)
            if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                let images = contents.filter { ext in
                    let e = ext.pathExtension.lowercased()
                    return ["jpg", "jpeg", "png", "heic", "tiff"].contains(e)
                }
                wallpaperPaths.append(contentsOf: images)
            }
        }
        wallpaperGrid.reloadData()

        // Screen saver start-after
        let idleTime = readIdleTime()
        let timeToIndex: [Int: Int] = [0: 0, 60: 1, 120: 2, 300: 3, 600: 4, 1200: 5, 1800: 6, 3600: 7]
        startAfterPopup.selectItem(at: timeToIndex[idleTime] ?? 0)
    }

    private func readIdleTime() -> Int {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "read", "com.apple.screensaver", "idleTime"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           let val = Int(str) {
            return val
        }
        return 0
    }

    // MARK: - Actions

    @objc private func chooseWallpaper(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK, let url = panel.url, let screen = NSScreen.main {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
                self.wallpaperPreview.image = NSImage(contentsOf: url)
            }
        }
    }

    @objc private func startAfterChanged(_ sender: NSPopUpButton) {
        let times = [0, 60, 120, 300, 600, 1200, 1800, 3600]
        let seconds = times[sender.indexOfSelectedItem]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "write", "com.apple.screensaver", "idleTime", "-int", "\(seconds)"]
        try? process.run()
        process.waitUntilExit()
    }

    @objc private func showHotCorners(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Hot Corners"
        alert.informativeText = "Hot Corners configuration will be available in a future update."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Wallpaper Collection View

class WallpaperItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("WallpaperItem")

    private let imagePreview: NSImageView = {
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 4
        iv.layer?.masksToBounds = true
        return iv
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.addSubview(imagePreview)
        NSLayoutConstraint.activate([
            imagePreview.topAnchor.constraint(equalTo: view.topAnchor),
            imagePreview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imagePreview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imagePreview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override var isSelected: Bool {
        didSet {
            view.layer?.borderWidth = isSelected ? 2 : 0
            view.layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
    }

    func configure(with url: URL) {
        // Load thumbnail asynchronously
        DispatchQueue.global(qos: .utility).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                self.imagePreview.image = img
            }
        }
    }
}

extension DesktopScreenSaverPaneViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return wallpaperPaths.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: WallpaperItem.identifier, for: indexPath)
        if let wallpaperItem = item as? WallpaperItem {
            wallpaperItem.configure(with: wallpaperPaths[indexPath.item])
        }
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first, let screen = NSScreen.main else { return }
        let url = wallpaperPaths[indexPath.item]
        try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        wallpaperPreview.image = NSImage(contentsOf: url)
    }
}
