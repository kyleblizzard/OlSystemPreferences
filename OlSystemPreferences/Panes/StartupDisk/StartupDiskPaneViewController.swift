import Cocoa

class StartupDiskPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "startupdisk" }
    var paneTitle: String { "Startup Disk" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "internaldrive.fill", accessibilityDescription: "Startup Disk") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 400) }
    var searchKeywords: [String] { ["startup", "disk", "boot", "volume", "restart", "startup disk"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Startup-Disk-Settings.extension" }

    // MARK: - Data

    private struct VolumeInfo {
        let name: String
        let path: String
        let icon: NSImage
        let isCurrent: Bool
        let isBootable: Bool
    }

    private var volumes: [VolumeInfo] = []

    // MARK: - UI

    private let volumeCollectionView: NSCollectionView = {
        let cv = NSCollectionView()
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    private let volumeScrollView = NSScrollView()
    private let infoLabel = NSTextField(labelWithString: "")
    private let restartButton = NSButton()

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Separator ---
        let headerSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        outerStack.addArrangedSubview(headerSep)

        // Instruction label
        let instructionLabel = SnowLeopardPaneHelper.makeLabel(
            "Select the system you want to use to start up your computer:",
            size: 11,
            bold: true
        )
        outerStack.addArrangedSubview(instructionLabel)

        // Volume collection view
        let flowLayout = NSCollectionViewFlowLayout()
        flowLayout.itemSize = NSSize(width: 120, height: 100)
        flowLayout.minimumInteritemSpacing = 16
        flowLayout.minimumLineSpacing = 16
        flowLayout.sectionInset = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        volumeCollectionView.collectionViewLayout = flowLayout
        volumeCollectionView.isSelectable = true
        volumeCollectionView.allowsMultipleSelection = false
        volumeCollectionView.delegate = self
        volumeCollectionView.dataSource = self
        volumeCollectionView.register(StartupVolumeItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("VolumeItem"))
        volumeCollectionView.backgroundColors = [NSColor(white: 0.95, alpha: 1.0)]

        volumeScrollView.translatesAutoresizingMaskIntoConstraints = false
        volumeScrollView.documentView = volumeCollectionView
        volumeScrollView.hasVerticalScroller = true
        volumeScrollView.borderType = .bezelBorder

        outerStack.addArrangedSubview(volumeScrollView)
        volumeScrollView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        volumeScrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        // Info label (shows current startup disk)
        infoLabel.font = SnowLeopardFonts.label(size: 10)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.maximumNumberOfLines = 2
        outerStack.addArrangedSubview(infoLabel)

        // Bottom row: lock icon note + restart button
        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 8
        bottomRow.alignment = .centerY

        let lockNote = SnowLeopardPaneHelper.makeLabel(
            "Changing the startup disk requires administrator authentication.",
            size: 10
        )
        lockNote.textColor = .secondaryLabelColor
        lockNote.maximumNumberOfLines = 2
        lockNote.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bottomRow.addArrangedSubview(lockNote)

        restartButton.title = "Restart..."
        restartButton.bezelStyle = .rounded
        restartButton.font = SnowLeopardFonts.label(size: 11)
        restartButton.target = self
        restartButton.action = #selector(restartClicked(_:))
        restartButton.isEnabled = false // Requires admin
        bottomRow.addArrangedSubview(restartButton)

        outerStack.addArrangedSubview(bottomRow)
        bottomRow.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        volumes.removeAll()

        // Current boot volume
        let currentBootVolume = getCurrentBootVolume()

        // Get mounted volumes
        let fileManager = FileManager.default
        guard let volumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeIsLocalKey, .volumeIsReadOnlyKey],
            options: [.skipHiddenVolumes]
        ) else {
            volumes.append(VolumeInfo(
                name: "Macintosh HD",
                path: "/",
                icon: NSWorkspace.shared.icon(forFile: "/"),
                isCurrent: true,
                isBootable: true
            ))
            volumeCollectionView.reloadData()
            return
        }

        for url in volumeURLs {
            let path = url.path
            let values = try? url.resourceValues(forKeys: [.volumeNameKey, .volumeIsLocalKey])
            let name = values?.volumeName ?? url.lastPathComponent
            let isLocal = values?.volumeIsLocal ?? false

            // Skip network volumes and virtual filesystems
            guard isLocal else { continue }

            // Skip preboot, recovery, VM, and other system volumes
            let lowered = path.lowercased()
            if lowered.contains("preboot") || lowered.contains("recovery") || lowered.contains("vm") {
                continue
            }

            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 64, height: 64)

            let isCurrent = (path == "/" || path == currentBootVolume)
            let isBootable = checkVolumeBootable(path: path)

            volumes.append(VolumeInfo(
                name: name,
                path: path,
                icon: icon,
                isCurrent: isCurrent,
                isBootable: isBootable || isCurrent
            ))
        }

        // Ensure at least the boot volume is present
        if volumes.isEmpty {
            volumes.append(VolumeInfo(
                name: "Macintosh HD",
                path: "/",
                icon: NSWorkspace.shared.icon(forFile: "/"),
                isCurrent: true,
                isBootable: true
            ))
        }

        volumeCollectionView.reloadData()

        // Select current startup disk
        if let currentIndex = volumes.firstIndex(where: { $0.isCurrent }) {
            volumeCollectionView.selectItems(at: [IndexPath(item: currentIndex, section: 0)], scrollPosition: .centeredVertically)
        }

        // Info text
        if let current = volumes.first(where: { $0.isCurrent }) {
            infoLabel.stringValue = "You have selected \"\(current.name)\" as the startup disk."
        } else {
            infoLabel.stringValue = "Select a startup disk from the volumes above."
        }
    }

    // MARK: - Helpers

    private func getCurrentBootVolume() -> String {
        guard let output = runCommand("/usr/sbin/bless", arguments: ["--info", "--getBoot"]) else {
            return "/"
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func checkVolumeBootable(path: String) -> Bool {
        let systemPath = path + "/System/Library/CoreServices/SystemVersion.plist"
        return FileManager.default.fileExists(atPath: systemPath)
    }

    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Actions

    @objc private func restartClicked(_ sender: NSButton) {
        // Open Startup Disk in System Settings instead
        if let url = URL(string: "x-apple.systempreferences:\(settingsURL)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - NSCollectionView DataSource & Delegate

extension StartupDiskPaneViewController: NSCollectionViewDataSource, NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return volumes.count
    }

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("VolumeItem"), for: indexPath)
        guard let volumeItem = item as? StartupVolumeItem else { return item }

        let volume = volumes[indexPath.item]
        volumeItem.configure(name: volume.name, icon: volume.icon, isCurrent: volume.isCurrent)
        return volumeItem
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first else { return }
        let volume = volumes[indexPath.item]
        infoLabel.stringValue = "You have selected \"\(volume.name)\" as the startup disk."
    }
}

// MARK: - Collection View Item

class StartupVolumeItem: NSCollectionViewItem {

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let selectionBox = NSView()

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 120, height: 100))
        view = root

        selectionBox.translatesAutoresizingMaskIntoConstraints = false
        selectionBox.wantsLayer = true
        selectionBox.layer?.cornerRadius = 6
        selectionBox.layer?.borderWidth = 0
        root.addSubview(selectionBox)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        root.addSubview(iconView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = SnowLeopardFonts.label(size: 10)
        nameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        nameLabel.alignment = .center
        nameLabel.maximumNumberOfLines = 2
        nameLabel.lineBreakMode = .byTruncatingTail
        root.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            selectionBox.topAnchor.constraint(equalTo: root.topAnchor, constant: 2),
            selectionBox.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 2),
            selectionBox.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -2),
            selectionBox.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -2),

            iconView.topAnchor.constraint(equalTo: root.topAnchor, constant: 8),
            iconView.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),

            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -4),
        ])
    }

    func configure(name: String, icon: NSImage, isCurrent: Bool) {
        iconView.image = icon
        nameLabel.stringValue = name

        if isCurrent {
            nameLabel.font = SnowLeopardFonts.boldLabel(size: 10)
        } else {
            nameLabel.font = SnowLeopardFonts.label(size: 10)
        }
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                selectionBox.layer?.backgroundColor = SnowLeopardColors.selectionTop.withAlphaComponent(0.3).cgColor
                selectionBox.layer?.borderWidth = 2
                selectionBox.layer?.borderColor = SnowLeopardColors.selectionBorder.cgColor
                nameLabel.textColor = NSColor(white: 0.05, alpha: 1.0)
            } else {
                selectionBox.layer?.backgroundColor = NSColor.clear.cgColor
                selectionBox.layer?.borderWidth = 0
                nameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
            }
        }
    }
}
