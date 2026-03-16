import Cocoa

class SharingPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "sharing" }
    var paneTitle: String { "Sharing" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "folder.badge.person.crop", accessibilityDescription: "Sharing") ?? NSImage()
    }
    var paneCategory: PaneCategory { .internetWireless }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 460) }
    var searchKeywords: [String] { ["sharing", "computer name", "file sharing", "screen sharing", "remote login", "hostname", "local"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Sharing-Settings.extension" }

    // MARK: - Data

    private struct SharingService {
        let name: String
        var isOn: Bool
    }

    private var services: [SharingService] = []

    // MARK: - UI

    private let computerNameField = NSTextField()
    private let localHostnameLabel = NSTextField(labelWithString: "")
    private let ipAddressLabel = NSTextField(labelWithString: "")
    private let serviceTable = NSTableView()

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

        // ===== Section: Computer Name =====
        let nameBox = SnowLeopardPaneHelper.makeSectionBox(title: "Computer Name")
        let nameStack = NSStackView()
        nameStack.translatesAutoresizingMaskIntoConstraints = false
        nameStack.orientation = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 10
        nameStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Computer name field
        computerNameField.translatesAutoresizingMaskIntoConstraints = false
        computerNameField.font = SnowLeopardFonts.label(size: 12)
        computerNameField.isEditable = false
        computerNameField.isSelectable = true
        computerNameField.widthAnchor.constraint(equalToConstant: 350).isActive = true

        let nameRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Computer Name:"),
            controls: [computerNameField]
        )
        nameStack.addArrangedSubview(nameRow)

        // Explanation text
        let nameExplain = SnowLeopardPaneHelper.makeLabel(
            "The name is used for identifying your computer on the network.",
            size: 10
        )
        nameExplain.textColor = .secondaryLabelColor
        nameExplain.maximumNumberOfLines = 2
        let explainRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [nameExplain]
        )
        nameStack.addArrangedSubview(explainRow)

        nameStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Local hostname
        localHostnameLabel.font = SnowLeopardFonts.label(size: 11)
        localHostnameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let hostnameRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Local Hostname:"),
            controls: [localHostnameLabel]
        )
        nameStack.addArrangedSubview(hostnameRow)

        // IP Address
        ipAddressLabel.font = SnowLeopardFonts.label(size: 11)
        ipAddressLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let ipRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("IP Address:"),
            controls: [ipAddressLabel]
        )
        nameStack.addArrangedSubview(ipRow)

        nameBox.contentView = nameStack
        outerStack.addArrangedSubview(nameBox)
        nameBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Services =====
        let servicesBox = SnowLeopardPaneHelper.makeSectionBox(title: "Services")
        let servicesStack = NSStackView()
        servicesStack.translatesAutoresizingMaskIntoConstraints = false
        servicesStack.orientation = .vertical
        servicesStack.alignment = .leading
        servicesStack.spacing = 8
        servicesStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let servicesLabel = SnowLeopardPaneHelper.makeLabel(
            "Select a service to change its settings. Changes require Open in System Settings.",
            size: 10
        )
        servicesLabel.textColor = .secondaryLabelColor
        servicesLabel.maximumNumberOfLines = 2
        servicesStack.addArrangedSubview(servicesLabel)

        // Services table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let onCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
        onCol.title = "On"
        onCol.width = 40
        serviceTable.addTableColumn(onCol)

        let svcCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("service"))
        svcCol.title = "Service"
        svcCol.width = 500
        serviceTable.addTableColumn(svcCol)

        serviceTable.delegate = self
        serviceTable.dataSource = self
        serviceTable.rowHeight = 22
        serviceTable.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = serviceTable
        scrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 160).isActive = true
        servicesStack.addArrangedSubview(scrollView)

        servicesBox.contentView = servicesStack
        outerStack.addArrangedSubview(servicesBox)
        servicesBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

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
        // Computer name
        let computerName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        computerNameField.stringValue = computerName

        // Local hostname
        let hostname = getLocalHostname()
        localHostnameLabel.stringValue = hostname

        // IP address
        ipAddressLabel.stringValue = getIPAddress()

        // Sharing services — detect active services
        services = [
            SharingService(name: "Screen Sharing", isOn: checkServiceRunning("com.apple.screensharing")),
            SharingService(name: "File Sharing", isOn: checkServiceRunning("com.apple.smbd")),
            SharingService(name: "Remote Login (SSH)", isOn: checkServiceRunning("com.openssh.sshd")),
            SharingService(name: "Remote Management", isOn: checkServiceRunning("com.apple.RemoteDesktop")),
            SharingService(name: "Remote Apple Events", isOn: checkServiceRunning("eppc")),
            SharingService(name: "Internet Sharing", isOn: false),
            SharingService(name: "Bluetooth Sharing", isOn: false),
            SharingService(name: "Printer Sharing", isOn: false),
            SharingService(name: "Content Caching", isOn: checkServiceRunning("com.apple.AssetCacheLocatorService")),
        ]

        serviceTable.reloadData()
    }

    // MARK: - Helpers

    /// Get the primary IP address for display alongside the computer name
    private func getIPAddress() -> String {
        // Try to get the IP from the primary network interface
        if let output = runCommand("/usr/sbin/networksetup", arguments: ["-getinfo", "Wi-Fi"]) {
            for line in output.components(separatedBy: "\n") {
                if line.hasPrefix("IP address:") {
                    let ip = line.replacingOccurrences(of: "IP address:", with: "").trimmingCharacters(in: .whitespaces)
                    if !ip.isEmpty && ip != "none" { return ip }
                }
            }
        }
        // Fallback: try Ethernet
        if let output = runCommand("/usr/sbin/networksetup", arguments: ["-getinfo", "Ethernet"]) {
            for line in output.components(separatedBy: "\n") {
                if line.hasPrefix("IP address:") {
                    let ip = line.replacingOccurrences(of: "IP address:", with: "").trimmingCharacters(in: .whitespaces)
                    if !ip.isEmpty && ip != "none" { return ip }
                }
            }
        }
        return "N/A"
    }

    private func getLocalHostname() -> String {
        if let output = runCommand("/usr/sbin/scutil", arguments: ["--get", "LocalHostName"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return "\(trimmed).local"
            }
        }
        return ProcessInfo.processInfo.hostName
    }

    private func checkServiceRunning(_ label: String) -> Bool {
        // Check SSH specifically
        if label == "com.openssh.sshd" {
            if let output = runCommand("/usr/sbin/systemsetup", arguments: ["-getremotelogin"]) {
                return output.lowercased().contains("on")
            }
        }
        // General launchctl check
        if let output = runCommand("/bin/launchctl", arguments: ["list"]) {
            return output.contains(label)
        }
        return false
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
}

// MARK: - NSTableViewDataSource & Delegate

extension SharingPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return services.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let service = services[row]
        let colID = tableColumn?.identifier.rawValue ?? ""

        if colID == "status" {
            // Status dot indicator
            let container = NSView()
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = service.isOn ? NSColor.systemGreen.cgColor : NSColor.systemGray.cgColor
            container.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            return container
        } else {
            let label = NSTextField(labelWithString: service.name)
            label.font = SnowLeopardFonts.label(size: 12)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
            return label
        }
    }
}
