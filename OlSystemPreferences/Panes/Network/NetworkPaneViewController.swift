import Cocoa

class NetworkPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "network" }
    var paneTitle: String { "Network" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "network", accessibilityDescription: "Network") ?? NSImage()
    }
    var paneCategory: PaneCategory { .internetWireless }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 540) }
    var searchKeywords: [String] { ["network", "wifi", "wi-fi", "ethernet", "ip", "dns", "tcp", "internet", "airport"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Network-Settings.extension" }

    // MARK: - Data Model

    private struct NetworkInterface {
        let name: String
        var ipAddress: String = ""
        var subnetMask: String = ""
        var router: String = ""
        var ipv6Address: String = ""
        var macAddress: String = ""
        var searchDomains: String = ""
        var status: Status = .off

        enum Status {
            case connected, inactive, off
        }
    }

    private var interfaces: [NetworkInterface] = []
    private var selectedIndex: Int = 0

    // MARK: - UI

    private let serviceTable = NSTableView()
    private let serviceScrollView = NSScrollView()

    private let statusDotView = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let ipLabel = NSTextField(labelWithString: "")
    private let subnetLabel = NSTextField(labelWithString: "")
    private let routerLabel = NSTextField(labelWithString: "")
    private let dnsLabel = NSTextField(labelWithString: "")
    private let ipv6Label = NSTextField(labelWithString: "")
    private let macLabel = NSTextField(labelWithString: "")
    private let searchDomainsLabel = NSTextField(labelWithString: "")
    private let renewStatusLabel = NSTextField(labelWithString: "")

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

        // --- Split: left list + right details ---
        let splitContainer = NSView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false

        // Left: Service list
        serviceScrollView.translatesAutoresizingMaskIntoConstraints = false
        serviceScrollView.hasVerticalScroller = true
        serviceScrollView.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("service"))
        nameCol.title = "Service"
        nameCol.width = 180
        serviceTable.addTableColumn(nameCol)
        serviceTable.headerView = nil
        serviceTable.delegate = self
        serviceTable.dataSource = self
        serviceTable.rowHeight = 28
        serviceTable.usesAlternatingRowBackgroundColors = true
        serviceScrollView.documentView = serviceTable

        splitContainer.addSubview(serviceScrollView)

        // Right: Details panel
        let detailBox = SnowLeopardPaneHelper.makeSectionBox()
        let detailStack = NSStackView()
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 10
        detailStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Status row
        statusDotView.translatesAutoresizingMaskIntoConstraints = false
        statusDotView.wantsLayer = true
        statusDotView.layer?.cornerRadius = 5
        statusDotView.layer?.backgroundColor = NSColor.systemGray.cgColor
        statusDotView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        statusDotView.heightAnchor.constraint(equalToConstant: 10).isActive = true

        statusLabel.font = SnowLeopardFonts.boldLabel(size: 11)
        statusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let statusRow = NSStackView(views: [statusDotView, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .centerY
        detailStack.addArrangedSubview(statusRow)

        detailStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 360))

        // IP Address row
        let ipRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("IP Address:"),
            controls: [ipLabel]
        )
        ipLabel.font = SnowLeopardFonts.label(size: 11)
        ipLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(ipRow)

        // Subnet Mask row
        let subnetRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Subnet Mask:"),
            controls: [subnetLabel]
        )
        subnetLabel.font = SnowLeopardFonts.label(size: 11)
        subnetLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(subnetRow)

        // Router row
        let routerRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Router:"),
            controls: [routerLabel]
        )
        routerLabel.font = SnowLeopardFonts.label(size: 11)
        routerLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(routerRow)

        // DNS row
        let dnsRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("DNS Server:"),
            controls: [dnsLabel]
        )
        dnsLabel.font = SnowLeopardFonts.label(size: 11)
        dnsLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(dnsRow)

        // Search Domains row
        let searchRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Search Domains:"),
            controls: [searchDomainsLabel]
        )
        searchDomainsLabel.font = SnowLeopardFonts.label(size: 11)
        searchDomainsLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(searchRow)

        // IPv6 Address row
        let ipv6Row = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("IPv6 Address:"),
            controls: [ipv6Label]
        )
        ipv6Label.font = SnowLeopardFonts.label(size: 11)
        ipv6Label.textColor = NSColor(white: 0.15, alpha: 1.0)
        ipv6Label.lineBreakMode = .byTruncatingTail
        detailStack.addArrangedSubview(ipv6Row)

        // MAC Address row
        let macRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Hardware (MAC):"),
            controls: [macLabel]
        )
        macLabel.font = SnowLeopardFonts.label(size: 11)
        macLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(macRow)

        detailStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 360))

        // Renew DHCP + Advanced buttons
        let renewButton = NSButton(title: "Renew DHCP Lease", target: self, action: #selector(renewDHCP(_:)))
        renewButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(renewButton, size: 11)

        let advancedButton = NSButton(title: "Advanced...", target: self, action: #selector(openAdvanced(_:)))
        advancedButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(advancedButton, size: 11)

        renewStatusLabel.font = SnowLeopardFonts.label(size: 10)
        renewStatusLabel.textColor = .secondaryLabelColor

        let buttonRow = NSStackView(views: [renewButton, advancedButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        detailStack.addArrangedSubview(buttonRow)
        detailStack.addArrangedSubview(renewStatusLabel)

        detailBox.contentView = detailStack
        detailBox.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(detailBox)

        // Layout the split
        NSLayoutConstraint.activate([
            serviceScrollView.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor),
            serviceScrollView.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            serviceScrollView.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
            serviceScrollView.widthAnchor.constraint(equalToConstant: 200),

            detailBox.leadingAnchor.constraint(equalTo: serviceScrollView.trailingAnchor, constant: 12),
            detailBox.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor),
            detailBox.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            detailBox.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
        ])

        outerStack.addArrangedSubview(splitContainer)
        splitContainer.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        splitContainer.heightAnchor.constraint(equalToConstant: 340).isActive = true

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
        interfaces.removeAll()
        let services = listNetworkServices()
        for service in services {
            var iface = NetworkInterface(name: service)
            let info = getNetworkInfo(service: service)
            iface.ipAddress = info.ip
            iface.subnetMask = info.subnet
            iface.router = info.router
            iface.searchDomains = getSearchDomains(service: service)
            iface.ipv6Address = getIPv6Address(service: service)
            iface.macAddress = getMACAddress(service: service)
            if !info.ip.isEmpty && info.ip != "none" {
                iface.status = .connected
            } else if info.ip == "none" {
                iface.status = .inactive
            } else {
                iface.status = .off
            }
            interfaces.append(iface)
        }

        // Fallback if no services found
        if interfaces.isEmpty {
            interfaces.append(NetworkInterface(name: "Wi-Fi", status: .off))
            interfaces.append(NetworkInterface(name: "Ethernet", status: .off))
        }

        serviceTable.reloadData()
        if !interfaces.isEmpty {
            serviceTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateDetailView(index: 0)
        }
    }

    // MARK: - Shell Commands

    private func listNetworkServices() -> [String] {
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-listallnetworkservices"]) else {
            return []
        }
        let lines = output.components(separatedBy: "\n")
        var services: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("An asterisk") { continue }
            // Remove leading asterisk for disabled services
            let cleaned = trimmed.hasPrefix("*") ? String(trimmed.dropFirst()) : trimmed
            services.append(cleaned)
        }
        return services
    }

    private func getNetworkInfo(service: String) -> (ip: String, subnet: String, router: String) {
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-getinfo", service]) else {
            return ("", "", "")
        }
        var ip = ""
        var subnet = ""
        var router = ""
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("IP address:") {
                ip = line.replacingOccurrences(of: "IP address:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Subnet mask:") {
                subnet = line.replacingOccurrences(of: "Subnet mask:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Router:") {
                router = line.replacingOccurrences(of: "Router:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return (ip, subnet, router)
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

    // MARK: - Detail Update

    private func updateDetailView(index: Int) {
        guard index >= 0, index < interfaces.count else { return }
        let iface = interfaces[index]

        switch iface.status {
        case .connected:
            statusDotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "\(iface.name) is connected"
        case .inactive:
            statusDotView.layer?.backgroundColor = NSColor.systemYellow.cgColor
            statusLabel.stringValue = "\(iface.name) is inactive"
        case .off:
            statusDotView.layer?.backgroundColor = NSColor.systemRed.cgColor
            statusLabel.stringValue = "\(iface.name) is not connected"
        }

        ipLabel.stringValue = iface.ipAddress.isEmpty ? "N/A" : iface.ipAddress
        subnetLabel.stringValue = iface.subnetMask.isEmpty ? "N/A" : iface.subnetMask
        routerLabel.stringValue = iface.router.isEmpty ? "N/A" : iface.router
        dnsLabel.stringValue = getDNS(service: iface.name)
        searchDomainsLabel.stringValue = iface.searchDomains.isEmpty ? "N/A" : iface.searchDomains
        ipv6Label.stringValue = iface.ipv6Address.isEmpty ? "N/A" : iface.ipv6Address
        macLabel.stringValue = iface.macAddress.isEmpty ? "N/A" : iface.macAddress
        renewStatusLabel.stringValue = ""
    }

    private func getDNS(service: String) -> String {
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-getdnsservers", service]) else {
            return "N/A"
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("aren't any") {
            return "Automatic"
        }
        let servers = trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return servers.joined(separator: ", ")
    }

    private func getSearchDomains(service: String) -> String {
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-getsearchdomains", service]) else {
            return ""
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("aren't any") {
            return "None"
        }
        return trimmed.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func getIPv6Address(service: String) -> String {
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-getinfo", service]) else {
            return ""
        }
        for line in output.components(separatedBy: "\n") {
            if line.hasPrefix("IPv6 IP address:") {
                let addr = line.replacingOccurrences(of: "IPv6 IP address:", with: "").trimmingCharacters(in: .whitespaces)
                if addr != "none" { return addr }
            }
        }
        return ""
    }

    private func getMACAddress(service: String) -> String {
        // Map service name to device (en0, en1, etc.)
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-listallhardwareports"]) else {
            return ""
        }
        let lines = output.components(separatedBy: "\n")
        var foundService = false
        for line in lines {
            if line.contains("Hardware Port: \(service)") {
                foundService = true
            } else if foundService && line.hasPrefix("Ethernet Address:") {
                return line.replacingOccurrences(of: "Ethernet Address:", with: "").trimmingCharacters(in: .whitespaces)
            } else if foundService && line.hasPrefix("Hardware Port:") {
                break
            }
        }
        return ""
    }

    // MARK: - Actions

    @objc private func renewDHCP(_ sender: NSButton) {
        guard selectedIndex >= 0, selectedIndex < interfaces.count else { return }
        let service = interfaces[selectedIndex].name
        renewStatusLabel.stringValue = "Renewing DHCP lease..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            process.arguments = ["-setdhcp", service]
            process.standardError = Pipe()
            process.standardOutput = Pipe()
            try? process.run()
            process.waitUntilExit()
            DispatchQueue.main.async {
                self?.renewStatusLabel.stringValue = process.terminationStatus == 0 ? "DHCP lease renewed." : "Renewal may require admin privileges."
                // Refresh network info after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self?.reloadFromSystem()
                }
            }
        }
    }

    @objc private func openAdvanced(_ sender: NSButton) {
        SystemSettingsLauncher.open(url: settingsURL)
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension NetworkPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return interfaces.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let iface = interfaces[row]

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Status dot
        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        switch iface.status {
        case .connected: dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
        case .inactive: dot.layer?.backgroundColor = NSColor.systemYellow.cgColor
        case .off: dot.layer?.backgroundColor = NSColor.systemRed.cgColor
        }
        container.addSubview(dot)

        // Service name
        let label = NSTextField(labelWithString: iface.name)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = SnowLeopardFonts.label(size: 12)
        label.textColor = NSColor(white: 0.15, alpha: 1.0)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
        ])

        return container
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }
        selectedIndex = row
        updateDetailView(index: row)
    }
}
