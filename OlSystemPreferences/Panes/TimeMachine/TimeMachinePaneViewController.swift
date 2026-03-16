// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

/// TimeMachinePaneViewController recreates the Snow Leopard Time Machine preference pane.
///
/// The layout mirrors the original:
/// 1. A large ON/OFF toggle at the top (using an Aqua segmented control)
/// 2. A "Backup Information" section showing disk name, last/oldest backup, and next backup
/// 3. An "Options" section with a menu bar checkbox and an exclusion paths table
///
/// Data is read from the system using `tmutil` commands and `defaults read` on the
/// `com.apple.TimeMachine` domain. Changes that require admin privileges redirect
/// the user to System Settings.
class TimeMachinePaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    /// Unique identifier used by PaneRegistry to look up this pane.
    var paneIdentifier: String { "timemachine" }

    /// Display title shown in the pane header and toolbar.
    var paneTitle: String { "Time Machine" }

    /// SF Symbol icon displayed next to the pane title and in the grid.
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: "Time Machine") ?? NSImage()
    }

    /// Which category section this pane appears in on the grid.
    var paneCategory: PaneCategory { .system }

    /// Preferred window size when this pane is shown.
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 460) }

    /// Search keywords that let users find this pane via the toolbar search field.
    var searchKeywords: [String] { ["backup", "time machine", "restore", "disk", "exclude"] }

    /// Returns `self` since this view controller *is* the pane view controller.
    var viewController: NSViewController { self }

    /// The System Settings extension URL used by the "Open in System Settings..." button.
    var settingsURL: String { "com.apple.Time-Machine-Settings.extension" }

    // MARK: - Services

    /// Shared defaults service for reading preference domains via CFPreferences.
    private let defaults = DefaultsService.shared

    // MARK: - Data Model

    /// Holds parsed backup information from tmutil commands so the UI can display it.
    private struct BackupInfo {
        var isEnabled: Bool = false
        var destinationName: String = "None"
        var destinationSize: String = ""
        var destinationFreeSpace: String = ""
        var lastBackupDate: String = "N/A"
        var oldestBackupDate: String = "N/A"
        var nextBackupEstimate: String = "Automatic"
    }

    /// Current backup info loaded from the system.
    private var backupInfo = BackupInfo()

    /// List of paths excluded from Time Machine backups.
    private var excludedPaths: [String] = []

    // MARK: - UI Elements

    /// Aqua-styled ON/OFF segmented control — the big visual toggle at the top of the pane.
    private var onOffSegmented: AquaSegmentedControl!

    /// Status label next to the toggle showing "ON" or "OFF" description text.
    private let statusLabel = NSTextField(labelWithString: "")

    // Backup info labels — each one displays a parsed value from tmutil output.
    private let diskNameLabel = NSTextField(labelWithString: "None")
    private let diskSizeLabel = NSTextField(labelWithString: "")
    private let diskFreeLabel = NSTextField(labelWithString: "")
    private let lastBackupLabel = NSTextField(labelWithString: "N/A")
    private let oldestBackupLabel = NSTextField(labelWithString: "N/A")
    private let nextBackupLabel = NSTextField(labelWithString: "Automatic")

    /// Checkbox for "Show Time Machine in menu bar" option.
    private var menuBarCheckbox: AquaCheckbox!

    /// Table view that lists the exclusion paths read from com.apple.TimeMachine ExcludeByPath.
    private let exclusionTable = NSTableView()

    // MARK: - Load View

    /// Builds the entire view hierarchy programmatically (no XIBs or storyboards).
    /// This is the AppKit equivalent of SwiftUI's `body` — it runs once when the view
    /// controller's view is first accessed.
    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // The outerStack is the main vertical container for the entire pane.
        // All sections (header, toggle, backup info, options) are stacked vertically inside it.
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        // Standard pane header with icon, title, and "Open in System Settings..." button.
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Separator line below the header ---
        let headerSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        outerStack.addArrangedSubview(headerSep)

        // ===== ON/OFF Toggle Area =====
        // In Snow Leopard, Time Machine had a prominent ON/OFF switch. We recreate this
        // with an Aqua segmented control that has two segments: "OFF" and "ON".
        let toggleBox = SnowLeopardPaneHelper.makeSectionBox()
        let toggleStack = NSStackView()
        toggleStack.translatesAutoresizingMaskIntoConstraints = false
        toggleStack.orientation = .horizontal
        toggleStack.alignment = .centerY
        toggleStack.spacing = 16
        toggleStack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        // Time Machine icon displayed large in the toggle area to match the original look.
        let tmIconView = NSImageView()
        tmIconView.translatesAutoresizingMaskIntoConstraints = false
        tmIconView.image = paneIcon
        tmIconView.imageScaling = .scaleProportionallyUpOrDown
        tmIconView.contentTintColor = NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.20, alpha: 1.0)
        tmIconView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        tmIconView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        toggleStack.addArrangedSubview(tmIconView)

        // Vertical column holding the segmented control and the status description label.
        let toggleColumn = NSStackView()
        toggleColumn.orientation = .vertical
        toggleColumn.alignment = .leading
        toggleColumn.spacing = 6

        // The segmented control: "OFF" is index 0, "ON" is index 1.
        onOffSegmented = SnowLeopardPaneHelper.makeAquaSegmented(
            segments: ["OFF", "ON"],
            selected: 0,
            target: self,
            action: #selector(toggleChanged(_:))
        )
        onOffSegmented.widthAnchor.constraint(equalToConstant: 140).isActive = true
        toggleColumn.addArrangedSubview(onOffSegmented)

        // Status description — tells the user the current Time Machine state in plain English.
        statusLabel.font = SnowLeopardFonts.label(size: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Time Machine is OFF"
        statusLabel.maximumNumberOfLines = 2
        statusLabel.preferredMaxLayoutWidth = 420
        toggleColumn.addArrangedSubview(statusLabel)

        toggleStack.addArrangedSubview(toggleColumn)

        toggleBox.contentView = toggleStack
        outerStack.addArrangedSubview(toggleBox)
        toggleBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Backup Information Section =====
        // Displays details about the current backup destination, last/oldest backups, etc.
        let infoBox = SnowLeopardPaneHelper.makeSectionBox(title: "Backup Information")
        let infoStack = NSStackView()
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 8
        infoStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Configure all info labels to use the standard Snow Leopard label style.
        let infoLabels = [diskNameLabel, diskSizeLabel, diskFreeLabel,
                          lastBackupLabel, oldestBackupLabel, nextBackupLabel]
        for label in infoLabels {
            label.font = SnowLeopardFonts.label(size: 11)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
        }

        // Backup Disk row — shows the name of the configured Time Machine destination.
        let diskRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Backup Disk:"),
            controls: [diskNameLabel]
        )
        infoStack.addArrangedSubview(diskRow)

        // Disk Size row — total capacity of the backup disk.
        let sizeRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Disk Size:"),
            controls: [diskSizeLabel]
        )
        infoStack.addArrangedSubview(sizeRow)

        // Available Space row — free space remaining on the backup disk.
        let freeRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Available:"),
            controls: [diskFreeLabel]
        )
        infoStack.addArrangedSubview(freeRow)

        // Separator between disk info and backup date info.
        infoStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Latest Backup row — parsed from `tmutil latestbackup`.
        let lastRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Latest Backup:"),
            controls: [lastBackupLabel]
        )
        infoStack.addArrangedSubview(lastRow)

        // Oldest Backup row — parsed from `tmutil listbackups` (first line).
        let oldestRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Oldest Backup:"),
            controls: [oldestBackupLabel]
        )
        infoStack.addArrangedSubview(oldestRow)

        // Next Backup row — estimated time for the next automatic backup.
        let nextRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Next Backup:"),
            controls: [nextBackupLabel]
        )
        infoStack.addArrangedSubview(nextRow)

        // Separator before the "Select Backup Disk" button.
        infoStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // "Select Backup Disk..." button — since changing the disk requires elevated privileges,
        // this sends the user to System Settings.
        let selectDiskButton = SnowLeopardPaneHelper.makeAquaButton(
            title: "Select Backup Disk...",
            target: self,
            action: #selector(selectDiskClicked(_:))
        )
        let selectDiskRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [selectDiskButton]
        )
        infoStack.addArrangedSubview(selectDiskRow)

        infoBox.contentView = infoStack
        outerStack.addArrangedSubview(infoBox)
        infoBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Options Section =====
        // Contains the menu bar checkbox and the exclusion paths table.
        let optionsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Options")
        let optionsStack = NSStackView()
        optionsStack.translatesAutoresizingMaskIntoConstraints = false
        optionsStack.orientation = .vertical
        optionsStack.alignment = .leading
        optionsStack.spacing = 8
        optionsStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // "Show Time Machine in menu bar" checkbox — reads from com.apple.systemuiserver.
        menuBarCheckbox = SnowLeopardPaneHelper.makeAquaCheckbox(
            title: "Show Time Machine in menu bar",
            isChecked: false,
            target: self,
            action: #selector(menuBarCheckChanged(_:))
        )
        let menuBarRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [menuBarCheckbox]
        )
        optionsStack.addArrangedSubview(menuBarRow)

        // Separator between the checkbox and the exclusion list.
        optionsStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Exclusion paths label — explains what the table below shows.
        let excludeLabel = SnowLeopardPaneHelper.makeLabel("Excluded from backups:", size: 11, bold: true)
        optionsStack.addArrangedSubview(excludeLabel)

        // Exclusion paths table — a small scrollable table listing directories excluded
        // from Time Machine backups. Read-only; changes require System Settings.
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // Single column to display the path string.
        let pathCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathCol.title = "Path"
        pathCol.width = 540
        exclusionTable.addTableColumn(pathCol)

        exclusionTable.headerView = nil
        exclusionTable.delegate = self
        exclusionTable.dataSource = self
        exclusionTable.rowHeight = 20
        exclusionTable.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = exclusionTable
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        optionsStack.addArrangedSubview(scrollView)

        optionsBox.contentView = optionsStack
        outerStack.addArrangedSubview(optionsBox)
        optionsBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Lock Icon Row =====
        // Standard Snow Leopard lock icon + text at the bottom of system panes.
        let lockRow = NSStackView()
        lockRow.orientation = .horizontal
        lockRow.alignment = .centerY
        lockRow.spacing = 6

        let lockIcon = NSImageView()
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        if let lockImage = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Lock") {
            lockIcon.image = lockImage
            lockIcon.contentTintColor = NSColor(white: 0.45, alpha: 1.0)
        }
        lockIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        lockIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let lockLabel = SnowLeopardPaneHelper.makeLabel("Click the lock to prevent further changes.", size: 10)
        lockLabel.textColor = NSColor(white: 0.45, alpha: 1.0)

        lockRow.addArrangedSubview(lockIcon)
        lockRow.addArrangedSubview(lockLabel)
        outerStack.addArrangedSubview(lockRow)

        // Pin the outer stack to the root view edges so it fills the pane.
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

    /// Reads all Time Machine configuration from the system and updates the UI.
    /// Called on initial load and whenever the pane becomes visible again.
    func reloadFromSystem() {
        loadBackupEnabled()
        loadDestinationInfo()
        loadLatestBackup()
        loadOldestBackup()
        loadNextBackupEstimate()
        loadMenuBarStatus()
        loadExcludedPaths()
        updateUI()
    }

    // MARK: - Data Loading

    /// Checks whether Time Machine automatic backups are enabled.
    /// Reads the `AutoBackup` key from the `com.apple.TimeMachine` domain.
    private func loadBackupEnabled() {
        // Try reading via DefaultsService first (uses CFPreferences).
        if let autoBackup = defaults.bool(forKey: "AutoBackup", domain: "com.apple.TimeMachine") {
            backupInfo.isEnabled = autoBackup
            return
        }

        // Fallback: use `defaults read` shell command in case CFPreferences can't access it
        // (some system domains require the shell approach).
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.TimeMachine", "AutoBackup"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            backupInfo.isEnabled = (trimmed == "1")
        }
    }

    /// Parses `tmutil destinationinfo` to get the backup disk name, size, and free space.
    ///
    /// Example tmutil output:
    /// ```
    /// ====================================================
    /// Name          : My Backup Disk
    /// Kind          : Local
    /// Mount Point   : /Volumes/MyBackup
    /// ID            : XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    /// ```
    ///
    /// We extract the Name and then query disk space for the mount point.
    private func loadDestinationInfo() {
        guard let output = runCommand("/usr/bin/tmutil", arguments: ["destinationinfo"]) else {
            backupInfo.destinationName = "No Backup Disk"
            backupInfo.destinationSize = ""
            backupInfo.destinationFreeSpace = ""
            return
        }

        let lines = output.components(separatedBy: "\n")
        var name = ""
        var mountPoint = ""

        // Parse each line of the tmutil output to extract key-value pairs.
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Name") {
                // Extract everything after the colon.
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    name = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                }
            } else if trimmed.hasPrefix("Mount Point") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count >= 2 {
                    mountPoint = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                }
            }
        }

        backupInfo.destinationName = name.isEmpty ? "No Backup Disk" : name

        // If we found a mount point, query the filesystem for disk capacity and free space.
        if !mountPoint.isEmpty {
            let url = URL(fileURLWithPath: mountPoint)
            do {
                let resourceValues = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
                if let totalBytes = resourceValues.volumeTotalCapacity {
                    backupInfo.destinationSize = formatBytes(Int64(totalBytes))
                }
                if let freeBytes = resourceValues.volumeAvailableCapacity {
                    backupInfo.destinationFreeSpace = formatBytes(Int64(freeBytes))
                }
            } catch {
                backupInfo.destinationSize = "Unknown"
                backupInfo.destinationFreeSpace = "Unknown"
            }
        } else {
            backupInfo.destinationSize = ""
            backupInfo.destinationFreeSpace = ""
        }
    }

    /// Parses `tmutil latestbackup` to find the most recent backup date.
    ///
    /// The output is a full path like:
    /// `/Volumes/MyBackup/Backups.backupdb/MacName/2026-03-15-143022`
    /// We extract the date portion from the last path component and format it nicely.
    private func loadLatestBackup() {
        guard let output = runCommand("/usr/bin/tmutil", arguments: ["latestbackup"]) else {
            backupInfo.lastBackupDate = "N/A"
            return
        }

        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.lowercased().contains("no backups") {
            backupInfo.lastBackupDate = "N/A"
            return
        }

        // The last path component looks like "2026-03-15-143022".
        // Parse it into a human-readable date string.
        backupInfo.lastBackupDate = parseDateFromBackupPath(trimmed)
    }

    /// Finds the oldest backup by parsing the first line from `tmutil listbackups`.
    /// The oldest backup is the first entry in chronological order.
    private func loadOldestBackup() {
        guard let output = runCommand("/usr/bin/tmutil", arguments: ["listbackups"]) else {
            backupInfo.oldestBackupDate = "N/A"
            return
        }

        let lines = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // The first non-empty line is the oldest backup path.
        if let firstLine = lines.first {
            backupInfo.oldestBackupDate = parseDateFromBackupPath(firstLine)
        } else {
            backupInfo.oldestBackupDate = "N/A"
        }
    }

    /// Estimates the next backup time.
    /// If backups are enabled, Time Machine runs approximately every hour.
    /// We check the latest backup time and add one hour to estimate the next run.
    private func loadNextBackupEstimate() {
        if !backupInfo.isEnabled {
            backupInfo.nextBackupEstimate = "Automatic backups off"
            return
        }

        // If we have a latest backup path, try to compute next = latest + 1 hour.
        if let output = runCommand("/usr/bin/tmutil", arguments: ["latestbackup"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if let date = dateFromBackupPath(trimmed) {
                let nextDate = date.addingTimeInterval(3600) // 1 hour from last backup
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                if nextDate < Date() {
                    // If the estimated time has already passed, Time Machine should run soon.
                    backupInfo.nextBackupEstimate = "Soon"
                } else {
                    backupInfo.nextBackupEstimate = formatter.string(from: nextDate)
                }
                return
            }
        }

        backupInfo.nextBackupEstimate = "Automatic"
    }

    /// Checks whether the Time Machine menu bar icon is shown.
    /// Snow Leopard stored menu extras in the `com.apple.systemuiserver` domain
    /// under the `menuExtras` key as an array of paths. We check if the TimeMachine
    /// menu extra is present in that array.
    private func loadMenuBarStatus() {
        // Read the menuExtras array from com.apple.systemuiserver.
        let value = defaults.any(forKey: "menuExtras", domain: "com.apple.systemuiserver")
        if let extras = value as? [String] {
            // Look for the TimeMachine menu extra path in the array.
            let hasTM = extras.contains { $0.lowercased().contains("timemachine") }
            menuBarCheckbox.isChecked = hasTM
        } else {
            // On modern macOS, the TimeMachine menu extra may be controlled differently.
            // Default to unchecked if we can't determine.
            menuBarCheckbox.isChecked = false
        }
    }

    /// Reads the list of paths excluded from Time Machine backups.
    /// Stored in `com.apple.TimeMachine` under the `ExcludeByPath` key as an array.
    private func loadExcludedPaths() {
        excludedPaths.removeAll()

        // Try CFPreferences first.
        let value = defaults.any(forKey: "ExcludeByPath", domain: "com.apple.TimeMachine")
        if let paths = value as? [String] {
            excludedPaths = paths
            exclusionTable.reloadData()
            return
        }

        // Fallback: use `defaults read` shell command and parse the plist output.
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.TimeMachine", "ExcludeByPath"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            // The output is a plist-style array like:
            // (
            //     "/path/one",
            //     "/path/two"
            // )
            // We parse out the quoted strings.
            let lines = trimmed.components(separatedBy: "\n")
            for line in lines {
                let cleaned = line.trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "()\","))
                    .trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty && cleaned.hasPrefix("/") {
                    excludedPaths.append(cleaned)
                }
            }
        }

        exclusionTable.reloadData()
    }

    // MARK: - UI Update

    /// Pushes all loaded data into the UI controls.
    /// Called after `reloadFromSystem()` finishes gathering data.
    private func updateUI() {
        // Update the ON/OFF segmented control: index 0 = OFF, index 1 = ON.
        onOffSegmented.selectedSegment = backupInfo.isEnabled ? 1 : 0

        // Update the status description text.
        if backupInfo.isEnabled {
            statusLabel.stringValue = "Time Machine is ON — backups are running automatically."
        } else {
            statusLabel.stringValue = "Time Machine is OFF — no automatic backups."
        }

        // Update backup information labels.
        diskNameLabel.stringValue = backupInfo.destinationName
        diskSizeLabel.stringValue = backupInfo.destinationSize.isEmpty ? "N/A" : backupInfo.destinationSize
        diskFreeLabel.stringValue = backupInfo.destinationFreeSpace.isEmpty ? "N/A" : backupInfo.destinationFreeSpace
        lastBackupLabel.stringValue = backupInfo.lastBackupDate
        oldestBackupLabel.stringValue = backupInfo.oldestBackupDate
        nextBackupLabel.stringValue = backupInfo.nextBackupEstimate
    }

    // MARK: - Date Parsing Helpers

    /// Extracts a human-readable date string from a Time Machine backup path.
    ///
    /// Backup paths end with a folder named like `2026-03-15-143022`.
    /// This method parses that component into a formatted date string.
    ///
    /// - Parameter path: Full path to a backup (e.g., `/Volumes/.../2026-03-15-143022`)
    /// - Returns: A formatted date string, or "N/A" if parsing fails.
    private func parseDateFromBackupPath(_ path: String) -> String {
        if let date = dateFromBackupPath(path) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "N/A"
    }

    /// Attempts to extract an actual Date object from a backup path.
    ///
    /// - Parameter path: Full path to a backup snapshot.
    /// - Returns: A Date if the path's last component can be parsed, nil otherwise.
    private func dateFromBackupPath(_ path: String) -> Date? {
        // Get the last path component (e.g., "2026-03-15-143022").
        let lastComponent = (path as NSString).lastPathComponent

        // Try the standard Time Machine date format: yyyy-MM-dd-HHmmss
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = formatter.date(from: lastComponent) {
            return date
        }

        // Some backups may use a slightly different format — try with just yyyy-MM-dd.
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: lastComponent)
    }

    // MARK: - Byte Formatting

    /// Converts a byte count into a human-readable string (e.g., "1.5 TB", "256 GB").
    ///
    /// Uses the standard ByteCountFormatter which picks the best unit automatically.
    /// - Parameter bytes: Raw byte count.
    /// - Returns: Formatted string like "500 GB" or "1.2 TB".
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Shell Command Runner

    /// Runs a command-line tool and captures its standard output as a string.
    ///
    /// This is the same pattern used across all panes (Battery, Network, Sharing, etc.)
    /// to call system utilities like `tmutil`, `defaults`, `pmset`, etc.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the executable (e.g., "/usr/bin/tmutil").
    ///   - arguments: Command-line arguments to pass to the executable.
    /// - Returns: The captured stdout as a String, or nil if the command failed.
    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        // Capture stdout in a pipe so we can read the output.
        let pipe = Pipe()
        process.standardOutput = pipe

        // Suppress stderr to avoid cluttering the console with non-critical warnings.
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

    /// Called when the user taps the ON/OFF segmented control.
    /// Time Machine enable/disable requires admin privileges, so we show an alert
    /// and offer to open System Settings where the user can make the change.
    @objc private func toggleChanged(_ sender: AquaSegmentedControl) {
        let wantsOn = sender.selectedSegment == 1

        let alert = NSAlert()
        alert.messageText = wantsOn ? "Enable Time Machine?" : "Disable Time Machine?"
        alert.informativeText = "Changing Time Machine settings requires administrator privileges. Would you like to open System Settings?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Send the user to System Settings where they can toggle Time Machine properly.
            SystemSettingsLauncher.open(url: settingsURL)
        } else {
            // User cancelled — revert the segmented control to its previous state.
            sender.selectedSegment = backupInfo.isEnabled ? 1 : 0
        }
    }

    /// Called when "Select Backup Disk..." is clicked.
    /// Selecting a backup disk requires System Settings, so redirect there.
    @objc private func selectDiskClicked(_ sender: Any) {
        SystemSettingsLauncher.open(url: settingsURL)
    }

    /// Called when the "Show Time Machine in menu bar" checkbox is toggled.
    /// On modern macOS this may require System Settings to change, so we note that
    /// and still attempt to write the preference.
    @objc private func menuBarCheckChanged(_ sender: AquaCheckbox) {
        // On modern macOS, menu extras are managed by Control Center settings.
        // We attempt to open System Settings for the user.
        let alert = NSAlert()
        alert.messageText = "Menu Bar Configuration"
        alert.informativeText = "The Time Machine menu bar icon is configured through System Settings on modern macOS."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Open the Control Center settings where menu bar items are managed.
            if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }

        // Revert checkbox to the actual system state since we can't change it directly.
        loadMenuBarStatus()
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

/// The exclusion paths table uses a simple data source: one row per excluded path.
/// This follows the same table pattern used in NetworkPaneViewController and
/// SharingPaneViewController.
extension TimeMachinePaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    /// Returns the total number of excluded paths to display in the table.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return excludedPaths.count
    }

    /// Creates a label view for each row showing the excluded path string.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < excludedPaths.count else { return nil }
        let path = excludedPaths[row]

        // Create a simple text label for the path, styled with Lucida Grande to match
        // the Snow Leopard aesthetic.
        let label = NSTextField(labelWithString: path)
        label.font = SnowLeopardFonts.label(size: 11)
        label.textColor = NSColor(white: 0.15, alpha: 1.0)
        label.lineBreakMode = .byTruncatingMiddle

        return label
    }
}
