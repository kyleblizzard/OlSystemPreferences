import Cocoa

class UsersPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "accounts" }
    var paneTitle: String { "Accounts" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: "Users & Groups") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 560) }
    var searchKeywords: [String] { ["users", "groups", "account", "login", "password", "admin", "user"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Users-Groups-Settings.extension" }

    // MARK: - Data

    private struct UserAccount {
        let fullName: String
        let shortName: String
        let homeDirectory: String
        let isAdmin: Bool
        let isCurrent: Bool
        var image: NSImage?
        var diskUsage: String = ""
    }

    private var users: [UserAccount] = []
    private var selectedIndex: Int = 0

    // MARK: - Login Items

    private struct LoginItem {
        let name: String
        let hidden: Bool
    }

    private var loginItems: [LoginItem] = []

    // MARK: - UI

    private let userTable = NSTableView()
    private let userScrollView = NSScrollView()

    private let userImageView = NSImageView()
    private let fullNameLabel = NSTextField(labelWithString: "")
    private let accountTypeLabel = NSTextField(labelWithString: "")
    private let shortNameValueLabel = NSTextField(labelWithString: "")
    private let homeDirValueLabel = NSTextField(labelWithString: "")
    private let changePasswordButton = NSButton()
    private let diskUsageValueLabel = NSTextField(labelWithString: "")
    private let loginItemsTable = NSTableView()

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

        // --- Split: left user list + right details ---
        let splitContainer = NSView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false

        // Left: User list
        userScrollView.translatesAutoresizingMaskIntoConstraints = false
        userScrollView.hasVerticalScroller = true
        userScrollView.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("user"))
        nameCol.title = "User"
        nameCol.width = 180
        userTable.addTableColumn(nameCol)
        userTable.headerView = nil
        userTable.delegate = self
        userTable.dataSource = self
        userTable.rowHeight = 40
        userTable.usesAlternatingRowBackgroundColors = true
        userScrollView.documentView = userTable

        splitContainer.addSubview(userScrollView)

        // Right: Detail panel
        let detailBox = SnowLeopardPaneHelper.makeSectionBox()
        let detailStack = NSStackView()
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 12
        detailStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // User image + name header
        userImageView.translatesAutoresizingMaskIntoConstraints = false
        userImageView.imageScaling = .scaleProportionallyUpOrDown
        userImageView.wantsLayer = true
        userImageView.layer?.cornerRadius = 4
        userImageView.layer?.masksToBounds = true
        userImageView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        userImageView.heightAnchor.constraint(equalToConstant: 64).isActive = true

        fullNameLabel.font = SnowLeopardFonts.boldLabel(size: 14)
        fullNameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        accountTypeLabel.font = SnowLeopardFonts.label(size: 11)
        accountTypeLabel.textColor = .secondaryLabelColor

        let nameColumn = NSStackView(views: [fullNameLabel, accountTypeLabel])
        nameColumn.orientation = .vertical
        nameColumn.alignment = .leading
        nameColumn.spacing = 2

        let headerRow = NSStackView(views: [userImageView, nameColumn])
        headerRow.orientation = .horizontal
        headerRow.alignment = .centerY
        headerRow.spacing = 12
        detailStack.addArrangedSubview(headerRow)

        detailStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 340))

        // Account name
        shortNameValueLabel.font = SnowLeopardFonts.label(size: 11)
        shortNameValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        let shortRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Account name:"),
            controls: [shortNameValueLabel]
        )
        detailStack.addArrangedSubview(shortRow)

        // Home directory
        homeDirValueLabel.font = SnowLeopardFonts.label(size: 11)
        homeDirValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        homeDirValueLabel.maximumNumberOfLines = 1
        homeDirValueLabel.lineBreakMode = .byTruncatingMiddle
        let homeRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Home directory:"),
            controls: [homeDirValueLabel]
        )
        detailStack.addArrangedSubview(homeRow)

        // Disk usage
        diskUsageValueLabel.font = SnowLeopardFonts.label(size: 11)
        diskUsageValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        let diskRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Disk Usage:"),
            controls: [diskUsageValueLabel]
        )
        detailStack.addArrangedSubview(diskRow)

        detailStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 340))

        // Change Password button
        changePasswordButton.title = "Change Password..."
        changePasswordButton.bezelStyle = .rounded
        changePasswordButton.font = SnowLeopardFonts.label(size: 11)
        changePasswordButton.target = self
        changePasswordButton.action = #selector(changePasswordClicked(_:))
        let passwordRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [changePasswordButton]
        )
        detailStack.addArrangedSubview(passwordRow)

        // Login Items section
        let loginLabel = SnowLeopardPaneHelper.makeLabel("Login Items:", size: 11, bold: true)
        detailStack.addArrangedSubview(loginLabel)

        let loginScroll = NSScrollView()
        loginScroll.translatesAutoresizingMaskIntoConstraints = false
        loginScroll.hasVerticalScroller = true
        loginScroll.borderType = .bezelBorder

        let loginNameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("loginName"))
        loginNameCol.title = "Name"
        loginNameCol.width = 220
        loginItemsTable.addTableColumn(loginNameCol)

        let loginHiddenCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("loginHidden"))
        loginHiddenCol.title = "Hide"
        loginHiddenCol.width = 50
        loginItemsTable.addTableColumn(loginHiddenCol)

        loginItemsTable.delegate = self
        loginItemsTable.dataSource = self
        loginItemsTable.tag = 20
        loginItemsTable.rowHeight = 20
        loginItemsTable.usesAlternatingRowBackgroundColors = true

        loginScroll.documentView = loginItemsTable
        loginScroll.widthAnchor.constraint(equalToConstant: 340).isActive = true
        loginScroll.heightAnchor.constraint(equalToConstant: 100).isActive = true
        detailStack.addArrangedSubview(loginScroll)

        // Add/Remove buttons (disabled — informational only)
        let addButton = NSButton(title: "+", target: nil, action: nil)
        addButton.bezelStyle = .rounded
        addButton.isEnabled = false
        addButton.toolTip = "Use System Settings to manage login items"
        addButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let removeButton = NSButton(title: "−", target: nil, action: nil)
        removeButton.bezelStyle = .rounded
        removeButton.isEnabled = false
        removeButton.toolTip = "Use System Settings to manage login items"
        removeButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let loginButtonRow = NSStackView(views: [addButton, removeButton, NSView()])
        loginButtonRow.orientation = .horizontal
        loginButtonRow.spacing = 2
        detailStack.addArrangedSubview(loginButtonRow)

        detailBox.contentView = detailStack
        detailBox.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(detailBox)

        // Layout the split
        NSLayoutConstraint.activate([
            userScrollView.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor),
            userScrollView.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            userScrollView.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
            userScrollView.widthAnchor.constraint(equalToConstant: 200),

            detailBox.leadingAnchor.constraint(equalTo: userScrollView.trailingAnchor, constant: 12),
            detailBox.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor),
            detailBox.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            detailBox.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
        ])

        outerStack.addArrangedSubview(splitContainer)
        splitContainer.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        splitContainer.heightAnchor.constraint(equalToConstant: 440).isActive = true

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
        users.removeAll()

        // Current user
        let currentShortName = NSUserName()
        let currentFullName = NSFullUserName()
        let currentHome = NSHomeDirectory()

        // Check if current user is admin
        let isAdmin = checkUserIsAdmin(currentShortName)

        // Try to get user picture
        let userImage = loadUserPicture(home: currentHome) ?? NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: "User") ?? NSImage()

        users.append(UserAccount(
            fullName: currentFullName,
            shortName: currentShortName,
            homeDirectory: currentHome,
            isAdmin: isAdmin,
            isCurrent: true,
            image: userImage
        ))

        // Try to find other users
        let otherUsers = discoverOtherUsers(currentShortName: currentShortName)
        users.append(contentsOf: otherUsers)

        // Discover login items
        discoverLoginItems()

        userTable.reloadData()
        loginItemsTable.reloadData()
        if !users.isEmpty {
            userTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateDetailView(index: 0)
        }
    }

    // MARK: - Login Items Discovery

    private func discoverLoginItems() {
        loginItems.removeAll()
        // Use osascript to get login items via System Events
        let source = """
        tell application "System Events"
            set itemList to ""
            repeat with li in every login item
                set itemList to itemList & name of li & "|" & (hidden of li as string) & "\\n"
            end repeat
            return itemList
        end tell
        """
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil, let output = result.stringValue {
                let lines = output.components(separatedBy: "\n")
                for line in lines {
                    let parts = line.components(separatedBy: "|")
                    guard parts.count >= 2 else { continue }
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let hidden = parts[1].trimmingCharacters(in: .whitespaces).lowercased() == "true"
                    if !name.isEmpty {
                        loginItems.append(LoginItem(name: name, hidden: hidden))
                    }
                }
            }
        }
    }

    // MARK: - User Discovery

    private func discoverOtherUsers(currentShortName: String) -> [UserAccount] {
        var others: [UserAccount] = []
        guard let output = runCommand("/usr/bin/dscl", arguments: [".", "-list", "/Users"]) else {
            return others
        }
        let allUsers = output.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("_") && $0 != "daemon" && $0 != "nobody" && $0 != "root" && $0 != currentShortName }

        for username in allUsers {
            // Check if this is a real user account (has a home folder >= 500 UID)
            guard let uidStr = runCommand("/usr/bin/dscl", arguments: [".", "-read", "/Users/\(username)", "UniqueID"]),
                  let uid = extractDSCLValue(uidStr, key: "UniqueID").flatMap({ Int($0) }),
                  uid >= 500 else { continue }

            let fullName = extractDSCLValue(
                runCommand("/usr/bin/dscl", arguments: [".", "-read", "/Users/\(username)", "RealName"]) ?? "",
                key: "RealName"
            ) ?? username

            let homeDir = extractDSCLValue(
                runCommand("/usr/bin/dscl", arguments: [".", "-read", "/Users/\(username)", "NFSHomeDirectory"]) ?? "",
                key: "NFSHomeDirectory"
            ) ?? "/Users/\(username)"

            let isAdmin = checkUserIsAdmin(username)
            let image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "User") ?? NSImage()

            others.append(UserAccount(
                fullName: fullName,
                shortName: username,
                homeDirectory: homeDir,
                isAdmin: isAdmin,
                isCurrent: false,
                image: image
            ))
        }
        return others
    }

    private func extractDSCLValue(_ output: String, key: String) -> String? {
        let lines = output.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            if line.hasPrefix("\(key):") {
                let value = line.replacingOccurrences(of: "\(key):", with: "").trimmingCharacters(in: .whitespaces)
                if !value.isEmpty {
                    return value
                }
                // Value might be on the next line (common for RealName)
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    if !nextLine.isEmpty {
                        return nextLine
                    }
                }
            }
        }
        return nil
    }

    private func checkUserIsAdmin(_ username: String) -> Bool {
        guard let output = runCommand("/usr/bin/dsmemberutil", arguments: ["checkmembership", "-U", username, "-G", "admin"]) else {
            return false
        }
        return output.contains("is a member")
    }

    private func loadUserPicture(home: String) -> NSImage? {
        // Try .face file first
        let facePath = home + "/.face"
        if FileManager.default.fileExists(atPath: facePath),
           let img = NSImage(contentsOfFile: facePath) {
            return img
        }
        // Try JPEG photo from dscl
        if let photoData = runCommandData("/usr/bin/dscl", arguments: [".", "-read", "/Users/\(NSUserName())", "JPEGPhoto"]) {
            // The data includes a header line, try to extract raw JPEG
            if let jpegStart = photoData.range(of: Data([0xFF, 0xD8])) {
                let jpegData = photoData.subdata(in: jpegStart.lowerBound..<photoData.endIndex)
                if let img = NSImage(data: jpegData) {
                    return img
                }
            }
        }
        return nil
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

    private func runCommandData(_ path: String, arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return pipe.fileHandleForReading.readDataToEndOfFile()
        } catch {
            return nil
        }
    }

    // MARK: - Detail Update

    private func updateDetailView(index: Int) {
        guard index >= 0, index < users.count else { return }
        let user = users[index]

        userImageView.image = user.image
        fullNameLabel.stringValue = user.fullName
        accountTypeLabel.stringValue = user.isAdmin ? "Admin" : "Standard"
        shortNameValueLabel.stringValue = user.shortName
        homeDirValueLabel.stringValue = user.homeDirectory
        diskUsageValueLabel.stringValue = user.diskUsage.isEmpty ? "Calculating..." : user.diskUsage
        changePasswordButton.isEnabled = user.isCurrent

        // Calculate disk usage in background if not yet done
        if user.diskUsage.isEmpty {
            let homeDir = user.homeDirectory
            let userIndex = index
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let usage = self?.calculateDiskUsage(path: homeDir) ?? "Unknown"
                DispatchQueue.main.async {
                    guard let self = self, userIndex < self.users.count else { return }
                    self.users[userIndex].diskUsage = usage
                    if self.selectedIndex == userIndex {
                        self.diskUsageValueLabel.stringValue = usage
                    }
                }
            }
        }
    }

    /// Calculate disk usage for a user's home directory
    private func calculateDiskUsage(path: String) -> String {
        guard let output = runCommand("/usr/bin/du", arguments: ["-sh", path]) else { return "Unknown" }
        let parts = output.components(separatedBy: "\t")
        if let size = parts.first?.trimmingCharacters(in: .whitespaces), !size.isEmpty {
            return size
        }
        return "Unknown"
    }

    // MARK: - Actions

    @objc private func changePasswordClicked(_ sender: NSButton) {
        // Open Users & Groups in System Settings
        if let url = URL(string: "x-apple.systempreferences:\(settingsURL)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension UsersPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 20 {
            return loginItems.count
        }
        return users.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView.tag == 20 {
            // Login items table
            let item = loginItems[row]
            let colID = tableColumn?.identifier.rawValue ?? ""
            if colID == "loginHidden" {
                let cell = NSTextField(labelWithString: item.hidden ? "Yes" : "No")
                cell.font = SnowLeopardFonts.label(size: 11)
                cell.textColor = .secondaryLabelColor
                return cell
            } else {
                let cell = NSTextField(labelWithString: item.name)
                cell.font = SnowLeopardFonts.label(size: 11)
                return cell
            }
        }

        let user = users[row]

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // User icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = user.image
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 3
        iconView.layer?.masksToBounds = true
        container.addSubview(iconView)

        // Name + type
        let nameLabel = NSTextField(labelWithString: user.fullName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = SnowLeopardFonts.label(size: 12)
        nameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        nameLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(nameLabel)

        let typeLabel = NSTextField(labelWithString: user.isAdmin ? "Admin" : "Standard")
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.font = SnowLeopardFonts.label(size: 9)
        typeLabel.textColor = .secondaryLabelColor
        container.addSubview(typeLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),

            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
        ])

        return container
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        if table.tag == 20 { return } // Login items — no action needed
        let row = table.selectedRow
        guard row >= 0 else { return }
        selectedIndex = row
        updateDetailView(index: row)
    }
}
