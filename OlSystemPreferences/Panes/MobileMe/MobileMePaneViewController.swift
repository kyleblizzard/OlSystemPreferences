// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

/// MobileMe was Apple's cloud service before iCloud (2008-2012). In Snow Leopard, this pane
/// let users manage their MobileMe account, iDisk, sync, and mail settings. Since MobileMe
/// no longer exists, this pane shows the user's iCloud account information instead — acting
/// as a nostalgic wrapper around modern iCloud data. It reads account info and storage details
/// from the system using shell commands, and provides buttons to jump into System Settings
/// for anything that requires authentication or changes.
class MobileMePaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol Properties

    /// Unique identifier used by PaneRegistry to look up this pane.
    var paneIdentifier: String { "mobileme" }

    /// The title shown in the toolbar and pane header.
    var paneTitle: String { "MobileMe" }

    /// The pane icon — a filled cloud symbol representing cloud services.
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "MobileMe") ?? NSImage()
    }

    /// MobileMe belongs in the Internet & Wireless category, same as Network and Sharing.
    var paneCategory: PaneCategory { .internetWireless }

    /// The preferred size for this pane's content area.
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 480) }

    /// The corresponding System Settings extension URL for "Internet Accounts."
    var settingsURL: String { "com.apple.Internet-Accounts-Settings.extension" }

    /// Keywords that let the search bar find this pane when the user types related terms.
    var searchKeywords: [String] {
        ["mobileme", "icloud", "sync", "idisk", "mail", "account", "apple id"]
    }

    /// PaneProtocol requires a reference back to the view controller — that's just `self`.
    var viewController: NSViewController { self }

    // MARK: - Data Model

    /// Holds the iCloud account information we read from the system.
    private struct AccountInfo {
        var appleID: String = ""          // The user's Apple ID email
        var accountName: String = ""      // The user's display name
    }

    /// Holds parsed iCloud storage information from system_profiler.
    private struct StorageInfo {
        var totalGB: Double = 0.0         // Total iCloud storage in GB
        var usedGB: Double = 0.0          // Used iCloud storage in GB
        var availableGB: Double = 0.0     // Available iCloud storage in GB
    }

    /// Represents a single iCloud service and whether it's enabled.
    private struct CloudService {
        let name: String                  // Display name (e.g., "iCloud Drive")
        var status: ServiceStatus         // Whether the service is on, off, or unknown

        enum ServiceStatus {
            case on, off, unknown
        }
    }

    private var accountInfo = AccountInfo()
    private var storageInfo = StorageInfo()
    private var cloudServices: [CloudService] = []

    // MARK: - UI Elements

    /// Labels for the account section
    private let appleIDValueLabel = NSTextField(labelWithString: "")
    private let accountNameValueLabel = NSTextField(labelWithString: "")

    /// Storage section labels and progress bar
    private let totalStorageLabel = NSTextField(labelWithString: "")
    private let usedStorageLabel = NSTextField(labelWithString: "")
    private let availableStorageLabel = NSTextField(labelWithString: "")
    private let storageProgressBar = NSProgressIndicator()

    /// The table view that displays iCloud services and their on/off status
    private let servicesTable = NSTableView()

    // MARK: - Load View

    /// Builds the entire pane UI programmatically. This is called once when the view controller
    /// first needs to display its view. We construct a vertical stack of sections: header,
    /// info note, account details, storage, services table, and bottom buttons.
    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // The outer stack holds all sections vertically with Snow Leopard-standard margins.
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header: icon, title, and "Open in System Settings" button ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Separator below the header ---
        let headerSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        outerStack.addArrangedSubview(headerSep)

        // --- Info note explaining that MobileMe has been replaced by iCloud ---
        // This is a small explanatory label so the user understands the context.
        let infoNote = SnowLeopardPaneHelper.makeLabel(
            "MobileMe has been replaced by iCloud. Showing your iCloud account information.",
            size: 10
        )
        infoNote.textColor = .secondaryLabelColor
        infoNote.maximumNumberOfLines = 2
        infoNote.preferredMaxLayoutWidth = 580
        outerStack.addArrangedSubview(infoNote)

        // ===== Section: Account =====
        let accountBox = SnowLeopardPaneHelper.makeSectionBox(title: "Account")
        let accountStack = NSStackView()
        accountStack.translatesAutoresizingMaskIntoConstraints = false
        accountStack.orientation = .horizontal
        accountStack.alignment = .top
        accountStack.spacing = 16
        accountStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // iCloud icon — a large blue cloud symbol on the left side of the account section.
        let cloudIconView = NSImageView()
        cloudIconView.translatesAutoresizingMaskIntoConstraints = false
        if let cloudImage = NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "iCloud") {
            cloudIconView.image = cloudImage
            cloudIconView.contentTintColor = NSColor.systemBlue
        }
        cloudIconView.imageScaling = .scaleProportionallyUpOrDown
        cloudIconView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        cloudIconView.heightAnchor.constraint(equalToConstant: 48).isActive = true
        accountStack.addArrangedSubview(cloudIconView)

        // Right side of account section: Apple ID, account name, and button
        let accountDetailStack = NSStackView()
        accountDetailStack.orientation = .vertical
        accountDetailStack.alignment = .leading
        accountDetailStack.spacing = 6

        // Apple ID row
        appleIDValueLabel.font = SnowLeopardFonts.label(size: 11)
        appleIDValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        appleIDValueLabel.lineBreakMode = .byTruncatingTail

        let appleIDRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Apple ID:"),
            controls: [appleIDValueLabel]
        )
        accountDetailStack.addArrangedSubview(appleIDRow)

        // Account name row
        accountNameValueLabel.font = SnowLeopardFonts.label(size: 11)
        accountNameValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let nameRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Account Name:"),
            controls: [accountNameValueLabel]
        )
        accountDetailStack.addArrangedSubview(nameRow)

        // "Account Details..." button — opens System Settings to manage the account
        let accountDetailsButton = NSButton(
            title: "Account Details...",
            target: self,
            action: #selector(openAccountDetails(_:))
        )
        accountDetailsButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(accountDetailsButton, size: 11)
        accountDetailStack.addArrangedSubview(accountDetailsButton)

        accountStack.addArrangedSubview(accountDetailStack)

        accountBox.contentView = accountStack
        outerStack.addArrangedSubview(accountBox)
        accountBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: iCloud Storage =====
        let storageBox = SnowLeopardPaneHelper.makeSectionBox(title: "iCloud Storage")
        let storageStack = NSStackView()
        storageStack.translatesAutoresizingMaskIntoConstraints = false
        storageStack.orientation = .vertical
        storageStack.alignment = .leading
        storageStack.spacing = 8
        storageStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Storage progress bar — shows how full iCloud storage is as a horizontal bar.
        // NSProgressIndicator in "bar" style is a simple way to visualize usage.
        storageProgressBar.translatesAutoresizingMaskIntoConstraints = false
        storageProgressBar.style = .bar
        storageProgressBar.isIndeterminate = false
        storageProgressBar.minValue = 0
        storageProgressBar.maxValue = 100
        storageProgressBar.doubleValue = 0
        storageProgressBar.widthAnchor.constraint(equalToConstant: 560).isActive = true
        storageProgressBar.heightAnchor.constraint(equalToConstant: 16).isActive = true
        storageStack.addArrangedSubview(storageProgressBar)

        // Storage detail labels — total, used, and available
        totalStorageLabel.font = SnowLeopardFonts.label(size: 11)
        totalStorageLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        usedStorageLabel.font = SnowLeopardFonts.label(size: 11)
        usedStorageLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        availableStorageLabel.font = SnowLeopardFonts.label(size: 11)
        availableStorageLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        // Lay out the three storage labels in a horizontal row
        let storageLabelsRow = NSStackView(views: [totalStorageLabel, usedStorageLabel, availableStorageLabel])
        storageLabelsRow.orientation = .horizontal
        storageLabelsRow.distribution = .equalSpacing
        storageLabelsRow.spacing = 12
        storageLabelsRow.translatesAutoresizingMaskIntoConstraints = false
        storageLabelsRow.widthAnchor.constraint(equalToConstant: 560).isActive = true
        storageStack.addArrangedSubview(storageLabelsRow)

        storageBox.contentView = storageStack
        outerStack.addArrangedSubview(storageBox)
        storageBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: iCloud Services =====
        let servicesBox = SnowLeopardPaneHelper.makeSectionBox(title: "iCloud Services")
        let servicesStack = NSStackView()
        servicesStack.translatesAutoresizingMaskIntoConstraints = false
        servicesStack.orientation = .vertical
        servicesStack.alignment = .leading
        servicesStack.spacing = 6
        servicesStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Services table — two columns: service name and status indicator dot
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // "Service" column — displays the name of each iCloud service
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("service"))
        nameCol.title = "Service"
        nameCol.width = 460
        servicesTable.addTableColumn(nameCol)

        // "Status" column — displays a colored dot (green = on, gray = off, orange = unknown)
        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        statusCol.title = "Status"
        statusCol.width = 80
        servicesTable.addTableColumn(statusCol)

        servicesTable.delegate = self
        servicesTable.dataSource = self
        servicesTable.rowHeight = 22
        servicesTable.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = servicesTable
        scrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        servicesStack.addArrangedSubview(scrollView)

        servicesBox.contentView = servicesStack
        outerStack.addArrangedSubview(servicesBox)
        servicesBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Bottom Buttons: Sign Out + Manage Storage =====
        // These buttons don't actually sign out or manage storage directly — they open
        // System Settings where the user can perform those actions with proper authentication.
        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 12
        bottomRow.alignment = .centerY

        let signOutButton = NSButton(
            title: "Sign Out...",
            target: self,
            action: #selector(signOutClicked(_:))
        )
        signOutButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(signOutButton, size: 11)
        bottomRow.addArrangedSubview(signOutButton)

        let manageStorageButton = NSButton(
            title: "Manage Storage...",
            target: self,
            action: #selector(manageStorageClicked(_:))
        )
        manageStorageButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(manageStorageButton, size: 11)
        bottomRow.addArrangedSubview(manageStorageButton)

        outerStack.addArrangedSubview(bottomRow)

        // Pin the outer stack to the root view's edges
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

    /// Reads account info, storage details, and service statuses from the system.
    /// Called on initial load and whenever the pane needs to refresh its data.
    func reloadFromSystem() {
        loadAccountInfo()
        loadStorageInfo()
        loadCloudServices()
        updateUI()
    }

    // MARK: - Data Loading

    /// Attempts to read the user's Apple ID from MobileMe account defaults or other
    /// system sources. Falls back to showing a "Sign in via System Settings" message
    /// if no account can be found (common on newer macOS where these defaults don't exist).
    private func loadAccountInfo() {
        accountInfo = AccountInfo()

        // Try MobileMeAccounts first — this was the original Snow Leopard source.
        // On modern macOS it may still contain iCloud account info.
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "MobileMeAccounts"]) {
            // Look for the AccountID key (the Apple ID email)
            let accountID = parseDefaultsValue(output, key: "AccountID")
            if !accountID.isEmpty {
                accountInfo.appleID = accountID
            }

            // Look for the display name
            let displayName = parseDefaultsValue(output, key: "DisplayName")
            if !displayName.isEmpty {
                accountInfo.accountName = displayName
            }
        }

        // If MobileMeAccounts didn't have what we need, try the full name from the system
        if accountInfo.accountName.isEmpty {
            accountInfo.accountName = NSFullUserName()
        }

        // If we still don't have an Apple ID, try reading from system_profiler
        if accountInfo.appleID.isEmpty {
            if let output = runCommand("/usr/sbin/system_profiler", arguments: ["SPConfigurationProfileDataType"]) {
                // Look for Apple ID references in configuration profiles
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains("@") && (trimmed.contains("apple") || trimmed.contains("icloud")) {
                        // Extract what looks like an email address
                        let words = trimmed.components(separatedBy: .whitespaces)
                        for word in words {
                            let cleaned = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted.subtracting(CharacterSet(charactersIn: "@._-")))
                            if cleaned.contains("@") && cleaned.contains(".") {
                                accountInfo.appleID = cleaned
                                break
                            }
                        }
                        if !accountInfo.appleID.isEmpty { break }
                    }
                }
            }
        }
    }

    /// Runs `system_profiler SPCloudDataType` to get iCloud storage information.
    /// The output contains lines like "Total Storage: 5 GB" that we parse into our model.
    /// If the command fails or returns no useful data, we show placeholder text.
    private func loadStorageInfo() {
        storageInfo = StorageInfo()

        guard let output = runCommand("/usr/sbin/system_profiler", arguments: ["SPCloudDataType"]) else {
            return
        }

        // Parse storage lines from system_profiler output.
        // The format varies by macOS version but typically includes lines like:
        //   iCloud Storage: 5 GB (2.1 GB Available)
        //   Total Storage: 5 GB
        //   Available Storage: 3.2 GB
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowered = trimmed.lowercased()

            if lowered.contains("total") && lowered.contains("storage") {
                storageInfo.totalGB = parseStorageValue(trimmed)
            } else if lowered.contains("available") && lowered.contains("storage") {
                storageInfo.availableGB = parseStorageValue(trimmed)
            } else if lowered.contains("used") && lowered.contains("storage") {
                storageInfo.usedGB = parseStorageValue(trimmed)
            }
        }

        // If we got total and available but not used, calculate it
        if storageInfo.totalGB > 0 && storageInfo.usedGB == 0 && storageInfo.availableGB > 0 {
            storageInfo.usedGB = storageInfo.totalGB - storageInfo.availableGB
        }

        // If we got total and used but not available, calculate it
        if storageInfo.totalGB > 0 && storageInfo.availableGB == 0 && storageInfo.usedGB > 0 {
            storageInfo.availableGB = storageInfo.totalGB - storageInfo.usedGB
        }
    }

    /// Builds the list of iCloud services. We check what we can from system_profiler output
    /// and default the rest to "unknown" (meaning the user should check System Settings).
    private func loadCloudServices() {
        // Start with the standard list of iCloud services
        cloudServices = [
            CloudService(name: "iCloud Drive", status: .unknown),
            CloudService(name: "Photos", status: .unknown),
            CloudService(name: "Mail", status: .unknown),
            CloudService(name: "Contacts", status: .unknown),
            CloudService(name: "Calendars", status: .unknown),
            CloudService(name: "Reminders", status: .unknown),
            CloudService(name: "Notes", status: .unknown),
            CloudService(name: "Safari", status: .unknown),
            CloudService(name: "Keychain", status: .unknown),
            CloudService(name: "Find My Mac", status: .unknown),
        ]

        // Try to detect which services are active from system_profiler
        if let output = runCommand("/usr/sbin/system_profiler", arguments: ["SPCloudDataType"]) {
            let lowered = output.lowercased()

            // Update service statuses based on what system_profiler reports.
            // system_profiler SPCloudDataType lists enabled iCloud services.
            for i in 0..<cloudServices.count {
                let serviceNameLower = cloudServices[i].name.lowercased()
                if lowered.contains(serviceNameLower) {
                    cloudServices[i].status = .on
                }
            }

            // Special case: "Find My Mac" might appear as "Find My"
            if lowered.contains("find my") {
                if let idx = cloudServices.firstIndex(where: { $0.name == "Find My Mac" }) {
                    cloudServices[idx].status = .on
                }
            }
        }

        // Check iCloud Drive specifically — if ~/Library/Mobile Documents/ exists and has
        // content, iCloud Drive is likely enabled
        let iCloudDrivePath = NSHomeDirectory() + "/Library/Mobile Documents"
        if FileManager.default.fileExists(atPath: iCloudDrivePath) {
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: iCloudDrivePath),
               !contents.isEmpty {
                if let idx = cloudServices.firstIndex(where: { $0.name == "iCloud Drive" }) {
                    cloudServices[idx].status = .on
                }
            }
        }
    }

    // MARK: - UI Update

    /// Pushes all loaded data into the UI labels, progress bar, and table view.
    private func updateUI() {
        // Account section
        if accountInfo.appleID.isEmpty {
            appleIDValueLabel.stringValue = "Sign in via System Settings"
            appleIDValueLabel.textColor = .secondaryLabelColor
        } else {
            appleIDValueLabel.stringValue = accountInfo.appleID
            appleIDValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        }

        if accountInfo.accountName.isEmpty {
            accountNameValueLabel.stringValue = "Unknown"
        } else {
            accountNameValueLabel.stringValue = accountInfo.accountName
        }

        // Storage section
        if storageInfo.totalGB > 0 {
            totalStorageLabel.stringValue = String(format: "Total: %.1f GB", storageInfo.totalGB)
            usedStorageLabel.stringValue = String(format: "Used: %.1f GB", storageInfo.usedGB)
            availableStorageLabel.stringValue = String(format: "Available: %.1f GB", storageInfo.availableGB)

            // Calculate the usage percentage for the progress bar
            let usagePercent = (storageInfo.usedGB / storageInfo.totalGB) * 100.0
            storageProgressBar.doubleValue = min(usagePercent, 100.0)
        } else {
            // No storage data available — show placeholder text
            totalStorageLabel.stringValue = "Total: Check System Settings"
            usedStorageLabel.stringValue = "Used: —"
            availableStorageLabel.stringValue = "Available: —"
            storageProgressBar.doubleValue = 0
        }

        // Refresh the services table
        servicesTable.reloadData()
    }

    // MARK: - Parsing Helpers

    /// Extracts a value for a given key from `defaults read` output.
    /// The output format looks like: `KeyName = "value";` or `KeyName = value;`
    /// We search for the key and grab whatever comes after the `=` sign.
    private func parseDefaultsValue(_ output: String, key: String) -> String {
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match lines like:  AccountID = "user@icloud.com";
            if trimmed.contains(key) && trimmed.contains("=") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    var value = parts[1].trimmingCharacters(in: .whitespaces)
                    // Remove trailing semicolon and surrounding quotes
                    value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\";"))
                    value = value.trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty && value != "(null)" {
                        return value
                    }
                }
            }
        }
        return ""
    }

    /// Parses a storage value from a system_profiler line like "Total Storage: 5 GB"
    /// or "Available Storage: 3.21 GB". Returns the numeric value in GB.
    private func parseStorageValue(_ line: String) -> Double {
        // Look for a number followed by GB, TB, or MB
        let components = line.components(separatedBy: .whitespaces)
        for (index, component) in components.enumerated() {
            let cleaned = component.trimmingCharacters(in: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted)
            if let value = Double(cleaned), index + 1 < components.count {
                let unit = components[index + 1].lowercased().trimmingCharacters(in: .punctuationCharacters)
                switch unit {
                case "tb":
                    return value * 1024.0  // Convert TB to GB
                case "gb":
                    return value
                case "mb":
                    return value / 1024.0  // Convert MB to GB
                default:
                    continue
                }
            }
        }

        // Fallback: try to find any number in the line and assume GB
        let components2 = line.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted)
        for part in components2 {
            if let value = Double(part), value > 0 {
                return value
            }
        }

        return 0.0
    }

    // MARK: - Shell Commands

    /// Runs a shell command synchronously and returns its stdout as a string.
    /// This is used to call `defaults`, `system_profiler`, and other system tools.
    /// Returns nil if the command fails to launch or produces no output.
    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        // Capture stderr separately so it doesn't pollute our output
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

    /// Opens System Settings to the Internet Accounts pane so the user can view
    /// or modify their Apple ID / iCloud account details.
    @objc private func openAccountDetails(_ sender: NSButton) {
        SystemSettingsLauncher.open(url: settingsURL)
    }

    /// Shows an informational alert explaining that signing out must be done through
    /// System Settings, then offers to open it for the user.
    @objc private func signOutClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Sign Out"
        alert.informativeText = "Signing out of iCloud must be done through System Settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SystemSettingsLauncher.open(url: "com.apple.settings.AppleID")
        }
    }

    /// Opens System Settings to the iCloud storage management screen where the user
    /// can see a detailed breakdown and manage their storage plan.
    @objc private func manageStorageClicked(_ sender: NSButton) {
        SystemSettingsLauncher.open(url: "com.apple.settings.Storage")
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

/// The table view shows each iCloud service with a status indicator dot.
/// Green = on, gray = off, orange = unknown (check System Settings).
extension MobileMePaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    /// Returns the total number of iCloud services we're tracking.
    func numberOfRows(in tableView: NSTableView) -> Int {
        return cloudServices.count
    }

    /// Builds the cell view for each column. The "service" column shows the name,
    /// and the "status" column shows a colored dot indicating the service state.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < cloudServices.count else { return nil }
        let service = cloudServices[row]
        let colID = tableColumn?.identifier.rawValue ?? ""

        if colID == "service" {
            // Service name label
            let label = NSTextField(labelWithString: service.name)
            label.font = SnowLeopardFonts.label(size: 12)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
            return label

        } else if colID == "status" {
            // Status dot — colored circle indicating on/off/unknown
            let container = NSView()
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4

            // Pick the dot color based on the service's status
            switch service.status {
            case .on:
                dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            case .off:
                dot.layer?.backgroundColor = NSColor.systemGray.cgColor
            case .unknown:
                dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            }

            container.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            return container
        }

        return nil
    }
}
