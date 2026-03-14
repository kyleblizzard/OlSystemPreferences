import Cocoa
import UniformTypeIdentifiers

class DesktopScreenSaverPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "desktopscreensaver" }
    var paneTitle: String { "Desktop & Screen Saver" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "photo", accessibilityDescription: "Desktop & Screen Saver") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 560) }
    var searchKeywords: [String] { ["desktop", "wallpaper", "background", "screen saver", "hot corner", "screensaver"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Wallpaper-Settings.extension" }

    // MARK: - Tab view

    private let tabView = AquaTabView()

    // MARK: - Desktop tab controls

    private let monitorFrame = MonitorFrameView()
    private let wallpaperPreview = NSImageView()
    private let wallpaperGrid = NSCollectionView()
    private var wallpaperPaths: [URL] = []

    // MARK: - Screen Saver tab controls

    private let saverTable = NSTableView()
    private let saverMonitorFrame = MonitorFrameView()
    private let saverPreviewLabel = NSTextField(labelWithString: "")
    private let saverPreviewImage = NSImageView()
    private var screenSaverNames: [String] = []
    private var screenSaverPaths: [String] = []
    private let startAfterPopup = AquaPopUpButton(items: [], selectedIndex: 0)
    private let showClockCheck = AquaCheckbox(title: "Show clock when screen saver is active", isChecked: false)

    // Idle times in seconds mapped to popup indices
    private let idleTimes = [0, 60, 120, 300, 600, 1200, 1800, 3600]
    private let idleLabels = ["Never", "1 Minute", "2 Minutes", "5 Minutes", "10 Minutes", "20 Minutes", "30 Minutes", "1 Hour"]

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12

        // Pane header
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        header.widthAnchor.constraint(equalToConstant: 620).isActive = true
        outerStack.addArrangedSubview(header)

        // Separator below header
        outerStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 620))

        // Tab view
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTab(title: "Desktop", view: createDesktopTab())
        tabView.addTab(title: "Screen Saver", view: createScreenSaverTab())

        outerStack.addArrangedSubview(tabView)

        view.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            outerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            outerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.widthAnchor.constraint(equalToConstant: 620),
            tabView.heightAnchor.constraint(equalToConstant: 440),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - Desktop Tab

    private func createDesktopTab() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        // Monitor frame with wallpaper preview inside
        monitorFrame.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            monitorFrame.widthAnchor.constraint(equalToConstant: 280),
            monitorFrame.heightAnchor.constraint(equalToConstant: 200),
        ])

        wallpaperPreview.translatesAutoresizingMaskIntoConstraints = false
        wallpaperPreview.imageScaling = .scaleProportionallyUpOrDown
        wallpaperPreview.wantsLayer = true
        monitorFrame.contentView.addSubview(wallpaperPreview)
        NSLayoutConstraint.activate([
            wallpaperPreview.topAnchor.constraint(equalTo: monitorFrame.contentView.topAnchor),
            wallpaperPreview.leadingAnchor.constraint(equalTo: monitorFrame.contentView.leadingAnchor),
            wallpaperPreview.trailingAnchor.constraint(equalTo: monitorFrame.contentView.trailingAnchor),
            wallpaperPreview.bottomAnchor.constraint(equalTo: monitorFrame.contentView.bottomAnchor),
        ])

        stack.addArrangedSubview(monitorFrame)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Wallpaper grid in a scroll view inside a section box
        let gridBox = SnowLeopardPaneHelper.makeSectionBox(title: "Apple Wallpapers")
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.documentView = wallpaperGrid

        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 80, height: 60)
        layout.minimumInteritemSpacing = 6
        layout.minimumLineSpacing = 6
        layout.sectionInset = NSEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        wallpaperGrid.collectionViewLayout = layout
        wallpaperGrid.delegate = self
        wallpaperGrid.dataSource = self
        wallpaperGrid.backgroundColors = [.white]
        wallpaperGrid.isSelectable = true
        wallpaperGrid.register(WallpaperItem.self, forItemWithIdentifier: WallpaperItem.identifier)

        let gridContent = NSView()
        gridContent.translatesAutoresizingMaskIntoConstraints = false
        gridContent.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: gridContent.topAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: gridContent.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: gridContent.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: gridContent.bottomAnchor, constant: -4),
            scrollView.heightAnchor.constraint(equalToConstant: 140),
        ])
        gridBox.contentView = gridContent
        gridBox.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(gridBox)

        // Choose Folder button row
        let chooseButton = AquaButton(title: "Choose Folder...")
        chooseButton.target = self
        chooseButton.action = #selector(chooseWallpaper(_:))

        let buttonRow = NSStackView(views: [NSView(), chooseButton])
        buttonRow.orientation = .horizontal
        buttonRow.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(buttonRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Screen Saver Tab

    private func createScreenSaverTab() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        // --- Top split: saver list (left) + monitor preview (right) ---
        let splitView = NSView()
        splitView.translatesAutoresizingMaskIntoConstraints = false

        // Left: Screen saver table
        let saverScroll = NSScrollView()
        saverScroll.translatesAutoresizingMaskIntoConstraints = false
        saverScroll.hasVerticalScroller = true
        saverScroll.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("saverName"))
        nameCol.title = "Screen Savers"
        nameCol.width = 200
        saverTable.addTableColumn(nameCol)
        saverTable.headerView = nil
        saverTable.delegate = self
        saverTable.dataSource = self
        saverTable.tag = 10
        saverTable.rowHeight = 22
        saverTable.usesAlternatingRowBackgroundColors = true
        saverScroll.documentView = saverTable

        splitView.addSubview(saverScroll)

        // Right: Monitor frame with preview
        saverMonitorFrame.translatesAutoresizingMaskIntoConstraints = false

        saverPreviewImage.translatesAutoresizingMaskIntoConstraints = false
        saverPreviewImage.imageScaling = .scaleProportionallyUpOrDown
        saverPreviewImage.isHidden = true
        saverMonitorFrame.contentView.addSubview(saverPreviewImage)

        saverPreviewLabel.translatesAutoresizingMaskIntoConstraints = false
        saverPreviewLabel.font = SnowLeopardFonts.boldLabel(size: 12)
        saverPreviewLabel.textColor = NSColor.white
        saverPreviewLabel.alignment = .center
        saverPreviewLabel.lineBreakMode = .byWordWrapping
        saverPreviewLabel.maximumNumberOfLines = 3
        saverPreviewLabel.stringValue = "Select a Screen Saver"
        saverMonitorFrame.contentView.addSubview(saverPreviewLabel)

        NSLayoutConstraint.activate([
            saverPreviewImage.topAnchor.constraint(equalTo: saverMonitorFrame.contentView.topAnchor),
            saverPreviewImage.leadingAnchor.constraint(equalTo: saverMonitorFrame.contentView.leadingAnchor),
            saverPreviewImage.trailingAnchor.constraint(equalTo: saverMonitorFrame.contentView.trailingAnchor),
            saverPreviewImage.bottomAnchor.constraint(equalTo: saverMonitorFrame.contentView.bottomAnchor),

            saverPreviewLabel.centerXAnchor.constraint(equalTo: saverMonitorFrame.contentView.centerXAnchor),
            saverPreviewLabel.centerYAnchor.constraint(equalTo: saverMonitorFrame.contentView.centerYAnchor),
            saverPreviewLabel.widthAnchor.constraint(lessThanOrEqualTo: saverMonitorFrame.contentView.widthAnchor, constant: -8),
        ])

        splitView.addSubview(saverMonitorFrame)

        NSLayoutConstraint.activate([
            splitView.heightAnchor.constraint(equalToConstant: 200),

            saverScroll.leadingAnchor.constraint(equalTo: splitView.leadingAnchor),
            saverScroll.topAnchor.constraint(equalTo: splitView.topAnchor),
            saverScroll.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
            saverScroll.widthAnchor.constraint(equalToConstant: 220),

            saverMonitorFrame.leadingAnchor.constraint(equalTo: saverScroll.trailingAnchor, constant: 12),
            saverMonitorFrame.trailingAnchor.constraint(equalTo: splitView.trailingAnchor),
            saverMonitorFrame.topAnchor.constraint(equalTo: splitView.topAnchor),
            saverMonitorFrame.bottomAnchor.constraint(equalTo: splitView.bottomAnchor),
        ])

        stack.addArrangedSubview(splitView)
        splitView.widthAnchor.constraint(equalToConstant: 560).isActive = true

        // --- Test button ---
        let testButton = AquaButton(title: "Test")
        testButton.target = self
        testButton.action = #selector(testScreenSaver(_:))

        let testRow = NSStackView(views: [NSView(), testButton])
        testRow.orientation = .horizontal
        testRow.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(testRow)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Start after + Show clock ---
        let startLabel = SnowLeopardPaneHelper.makeLabel("Start after:", size: 11)
        startAfterPopup.items = idleLabels
        startAfterPopup.selectedIndex = 0
        startAfterPopup.target = self
        startAfterPopup.action = #selector(startAfterChanged(_:))

        let startRow = SnowLeopardPaneHelper.makeRow(
            label: startLabel,
            controls: [startAfterPopup]
        )
        stack.addArrangedSubview(startRow)

        showClockCheck.target = self
        showClockCheck.action = #selector(showClockChanged(_:))
        stack.addArrangedSubview(showClockCheck)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Hot Corners button
        let hotCornersButton = AquaButton(title: "Hot Corners...")
        hotCornersButton.target = self
        hotCornersButton.action = #selector(showHotCorners(_:))
        stack.addArrangedSubview(hotCornersButton)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Reload

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
                let images = contents.filter { fileURL in
                    let ext = fileURL.pathExtension.lowercased()
                    return ["jpg", "jpeg", "png", "heic", "tiff"].contains(ext)
                }
                wallpaperPaths.append(contentsOf: images)
            }
        }
        wallpaperGrid.reloadData()

        // Discover screen savers
        discoverScreenSavers()
        saverTable.reloadData()

        // Screen saver start-after
        let idleTime = readIdleTime()
        let timeToIndex: [Int: Int] = [0: 0, 60: 1, 120: 2, 300: 3, 600: 4, 1200: 5, 1800: 6, 3600: 7]
        startAfterPopup.selectedIndex = timeToIndex[idleTime] ?? 0

        // Show clock
        let showClock = readShowClock()
        showClockCheck.isChecked = showClock
    }

    // MARK: - Screen Saver Discovery

    private func discoverScreenSavers() {
        screenSaverNames.removeAll()
        screenSaverPaths.removeAll()

        let searchDirs = [
            "/System/Library/Screen Savers",
            "/Library/Screen Savers",
            NSHomeDirectory() + "/Library/Screen Savers",
        ]
        for dir in searchDirs {
            let url = URL(fileURLWithPath: dir)
            guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { continue }
            for item in contents where item.pathExtension == "saver" || item.pathExtension == "appex" {
                let name = item.deletingPathExtension().lastPathComponent
                if !screenSaverNames.contains(name) {
                    screenSaverNames.append(name)
                    screenSaverPaths.append(item.path)
                }
            }
        }
        screenSaverNames.sort()
        screenSaverPaths.sort()
    }

    private func updateSaverPreview(index: Int) {
        guard index >= 0, index < screenSaverPaths.count else {
            saverPreviewLabel.stringValue = "Select a Screen Saver"
            saverPreviewLabel.isHidden = false
            saverPreviewImage.isHidden = true
            return
        }

        let path = screenSaverPaths[index]
        let name = screenSaverNames[index]

        // Try to load thumbnail from the bundle
        if let bundle = Bundle(path: path) {
            for thumbName in ["thumbnail@2x.png", "thumbnail.png", "thumbnail.tiff", "Preview.png"] {
                if let thumbURL = bundle.url(forResource: thumbName.components(separatedBy: ".").first,
                                              withExtension: thumbName.components(separatedBy: ".").last),
                   let img = NSImage(contentsOf: thumbURL) {
                    saverPreviewImage.image = img
                    saverPreviewImage.isHidden = false
                    saverPreviewLabel.isHidden = true
                    return
                }
            }
        }

        // Fallback: show name
        saverPreviewLabel.stringValue = name
        saverPreviewLabel.isHidden = false
        saverPreviewImage.isHidden = true
    }

    // MARK: - Idle Time Read/Write

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

    private func writeIdleTime(_ seconds: Int) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "write", "com.apple.screensaver", "idleTime", "-int", "\(seconds)"]
        try? process.run()
        process.waitUntilExit()
    }

    private func readShowClock() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "read", "com.apple.screensaver", "showClock"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return str == "1"
        }
        return false
    }

    private func writeShowClock(_ value: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["-currentHost", "write", "com.apple.screensaver", "showClock", "-bool", value ? "YES" : "NO"]
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Actions

    @objc private func chooseWallpaper(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self = self else { return }
            if response == .OK, let url = panel.url, let screen = NSScreen.main {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
                self.wallpaperPreview.image = NSImage(contentsOf: url)
            }
        }
    }

    @objc private func startAfterChanged(_ sender: AquaPopUpButton) {
        let seconds = idleTimes[sender.selectedIndex]
        writeIdleTime(seconds)
    }

    @objc private func showClockChanged(_ sender: AquaCheckbox) {
        writeShowClock(sender.isChecked)
    }

    @objc private func testScreenSaver(_ sender: Any?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "ScreenSaverEngine"]
        try? process.run()
    }

    @objc private func showHotCorners(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Hot Corners"
        alert.informativeText = "Configure hot corners in the Expose & Spaces preference pane."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}

// MARK: - Wallpaper Collection View Item

class WallpaperItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("WallpaperItem")

    private let imagePreview: NSImageView = {
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.wantsLayer = true
        iv.layer?.cornerRadius = 3
        iv.layer?.masksToBounds = true
        iv.layer?.borderWidth = 1
        iv.layer?.borderColor = NSColor(white: 0.75, alpha: 1.0).cgColor
        return iv
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.addSubview(imagePreview)
        NSLayoutConstraint.activate([
            imagePreview.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            imagePreview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            imagePreview.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            imagePreview.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
        ])
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                view.layer?.borderWidth = 3
                view.layer?.borderColor = SnowLeopardColors.selectionBorder.cgColor
                view.layer?.cornerRadius = 4
            } else {
                view.layer?.borderWidth = 0
                view.layer?.borderColor = nil
                view.layer?.cornerRadius = 0
            }
        }
    }

    func configure(with url: URL) {
        DispatchQueue.global(qos: .utility).async {
            let img = NSImage(contentsOf: url)
            DispatchQueue.main.async { [weak self] in
                self?.imagePreview.image = img
            }
        }
    }
}

// MARK: - NSCollectionViewDataSource & Delegate

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

// MARK: - NSTableViewDataSource & Delegate (Screen Saver table)

extension DesktopScreenSaverPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return screenSaverNames.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTextField(labelWithString: screenSaverNames[row])
        cell.font = SnowLeopardFonts.label(size: 12)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView, table.tag == 10 else { return }
        updateSaverPreview(index: table.selectedRow)
    }
}
