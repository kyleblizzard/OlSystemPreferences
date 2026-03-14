import Cocoa

class NotificationsPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "notifications" }
    var paneTitle: String { "Notifications" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: "Notifications") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 440) }
    var searchKeywords: [String] { ["notifications", "alerts", "banners", "badges", "do not disturb", "focus", "notification center"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Notifications-Settings.extension" }

    // MARK: - Data Model

    private struct NotificationApp {
        let name: String
        let bundleID: String
        var alertStyle: String  // None, Banners, Alerts
    }

    private var notificationApps: [NotificationApp] = []
    private var dndEnabled: Bool = false

    // MARK: - UI

    private let dndStatusLabel = NSTextField(labelWithString: "")
    private let dndDotView = NSView()
    private let appTable = NSTableView()
    private let appScrollView = NSScrollView()

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

        // ===== Section: Do Not Disturb =====
        let dndBox = SnowLeopardPaneHelper.makeSectionBox(title: "Do Not Disturb")
        let dndStack = NSStackView()
        dndStack.translatesAutoresizingMaskIntoConstraints = false
        dndStack.orientation = .vertical
        dndStack.alignment = .leading
        dndStack.spacing = 8
        dndStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // DND status row with dot
        dndDotView.translatesAutoresizingMaskIntoConstraints = false
        dndDotView.wantsLayer = true
        dndDotView.layer?.cornerRadius = 5
        dndDotView.layer?.backgroundColor = NSColor.systemGray.cgColor
        dndDotView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dndDotView.heightAnchor.constraint(equalToConstant: 10).isActive = true

        dndStatusLabel.font = SnowLeopardFonts.boldLabel(size: 11)
        dndStatusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let dndStatusRow = NSStackView(views: [dndDotView, dndStatusLabel])
        dndStatusRow.orientation = .horizontal
        dndStatusRow.spacing = 6
        dndStatusRow.alignment = .centerY
        dndStack.addArrangedSubview(dndStatusRow)

        // DND explanation
        let dndExplain = SnowLeopardPaneHelper.makeLabel(
            "When Do Not Disturb is enabled, notifications will be silenced. Use Focus settings in System Settings to configure schedules and allowed apps.",
            size: 10
        )
        dndExplain.textColor = .secondaryLabelColor
        dndExplain.maximumNumberOfLines = 3
        dndExplain.preferredMaxLayoutWidth = 540
        dndStack.addArrangedSubview(dndExplain)

        dndStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Configure Focus button
        let focusButton = NSButton(title: "Configure Focus & Do Not Disturb...", target: self, action: #selector(openFocusSettings))
        focusButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(focusButton, size: 11)

        let focusRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [focusButton]
        )
        dndStack.addArrangedSubview(focusRow)

        dndBox.contentView = dndStack
        outerStack.addArrangedSubview(dndBox)
        dndBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Application Notifications =====
        let appsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Application Notifications")
        let appsStack = NSStackView()
        appsStack.translatesAutoresizingMaskIntoConstraints = false
        appsStack.orientation = .vertical
        appsStack.alignment = .leading
        appsStack.spacing = 8
        appsStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let appsInfo = SnowLeopardPaneHelper.makeLabel(
            "The following applications have registered for notifications. Use System Settings to change notification styles and permissions.",
            size: 10
        )
        appsInfo.textColor = .secondaryLabelColor
        appsInfo.maximumNumberOfLines = 3
        appsInfo.preferredMaxLayoutWidth = 540
        appsStack.addArrangedSubview(appsInfo)

        // App notifications table
        appScrollView.translatesAutoresizingMaskIntoConstraints = false
        appScrollView.hasVerticalScroller = true
        appScrollView.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Application"
        nameCol.width = 340
        appTable.addTableColumn(nameCol)

        let styleCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("style"))
        styleCol.title = "Alert Style"
        styleCol.width = 180
        appTable.addTableColumn(styleCol)

        appTable.delegate = self
        appTable.dataSource = self
        appTable.rowHeight = 22
        appTable.usesAlternatingRowBackgroundColors = true

        appScrollView.documentView = appTable
        appScrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        appScrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        appsStack.addArrangedSubview(appScrollView)

        appsStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Open in System Settings button (prominent)
        let openButton = NSButton(title: "Open Notification Settings...", target: self, action: #selector(openNotificationSettings))
        openButton.bezelStyle = .rounded
        openButton.keyEquivalent = "\r"
        SnowLeopardPaneHelper.styleControl(openButton, size: 11)

        let openRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [openButton]
        )
        appsStack.addArrangedSubview(openRow)

        appsBox.contentView = appsStack
        outerStack.addArrangedSubview(appsBox)
        appsBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

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
        // Check DND / Focus status
        dndEnabled = checkDNDStatus()

        if dndEnabled {
            dndDotView.layer?.backgroundColor = NSColor.systemPurple.cgColor
            dndStatusLabel.stringValue = "Do Not Disturb is enabled"
        } else {
            dndDotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            dndStatusLabel.stringValue = "Notifications are active"
        }

        // Parse notification apps from ncprefs
        notificationApps = parseNotificationApps()
        appTable.reloadData()
    }

    // MARK: - Shell Commands

    private func checkDNDStatus() -> Bool {
        // Try reading Focus mode status from defaults
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.controlcenter", "NSStatusItem Visible FocusModes"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == "1"
        }
        return false
    }

    private func parseNotificationApps() -> [NotificationApp] {
        // Read from com.apple.ncprefs to discover apps with notification registrations
        guard let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.ncprefs"]) else {
            return defaultNotificationApps()
        }

        // Parse bundle IDs from the output
        var apps: [NotificationApp] = []
        let lines = output.components(separatedBy: "\n")
        var seenBundleIDs = Set<String>()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Look for "bundle-id" = "com.something.app"
            if trimmed.contains("bundle-id") {
                if let range = trimmed.range(of: #""[a-zA-Z0-9._-]+(\.)[a-zA-Z0-9._-]+""#, options: .regularExpression) {
                    let bundleID = String(trimmed[range]).replacingOccurrences(of: "\"", with: "")
                    guard !seenBundleIDs.contains(bundleID) else { continue }
                    seenBundleIDs.insert(bundleID)

                    // Derive a display name from the bundle ID
                    let name = displayName(from: bundleID)
                    apps.append(NotificationApp(name: name, bundleID: bundleID, alertStyle: "Banners"))
                }
            }
        }

        // If parsing yielded nothing, return defaults
        if apps.isEmpty {
            return defaultNotificationApps()
        }

        // Sort by name and limit to reasonable count
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        if apps.count > 30 {
            apps = Array(apps.prefix(30))
        }
        return apps
    }

    private func defaultNotificationApps() -> [NotificationApp] {
        // Common apps that typically have notifications
        return [
            NotificationApp(name: "Calendar", bundleID: "com.apple.iCal", alertStyle: "Alerts"),
            NotificationApp(name: "FaceTime", bundleID: "com.apple.FaceTime", alertStyle: "Banners"),
            NotificationApp(name: "Finder", bundleID: "com.apple.finder", alertStyle: "Banners"),
            NotificationApp(name: "Mail", bundleID: "com.apple.mail", alertStyle: "Banners"),
            NotificationApp(name: "Messages", bundleID: "com.apple.MobileSMS", alertStyle: "Alerts"),
            NotificationApp(name: "Reminders", bundleID: "com.apple.reminders", alertStyle: "Alerts"),
            NotificationApp(name: "Safari", bundleID: "com.apple.Safari", alertStyle: "Banners"),
        ]
    }

    private func displayName(from bundleID: String) -> String {
        // Try to get the actual app name from the bundle ID
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = appURL.deletingPathExtension().lastPathComponent
            if !name.isEmpty { return name }
        }

        // Fallback: derive from bundle ID
        let components = bundleID.components(separatedBy: ".")
        if let last = components.last, !last.isEmpty {
            // Convert camelCase or hyphenated to readable
            return last.replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
        }
        return bundleID
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

    @objc private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:\(settingsURL)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func openFocusSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Focus-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension NotificationsPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return notificationApps.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < notificationApps.count else { return nil }
        let app = notificationApps[row]
        let colID = tableColumn?.identifier.rawValue ?? ""

        switch colID {
        case "name":
            let label = NSTextField(labelWithString: app.name)
            label.font = SnowLeopardFonts.label(size: 12)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
            return label

        case "style":
            let label = NSTextField(labelWithString: app.alertStyle)
            label.font = SnowLeopardFonts.label(size: 12)
            label.textColor = .secondaryLabelColor
            return label

        default:
            return nil
        }
    }
}
