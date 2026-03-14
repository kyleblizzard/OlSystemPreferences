import Cocoa

class WiFiPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "wifi" }
    var paneTitle: String { "AirPort" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "wifi", accessibilityDescription: "AirPort") ?? NSImage()
    }
    var paneCategory: PaneCategory { .internetWireless }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 440) }
    var searchKeywords: [String] { ["wifi", "wi-fi", "airport", "wireless", "network", "ssid", "signal"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.wifi-settings-extension" }

    // MARK: - Data Model

    private struct WiFiInfo {
        var powered: Bool = false
        var currentNetwork: String = ""
        var signalStrength: Int = 0  // RSSI value
        var ipAddress: String = ""
        var subnetMask: String = ""
        var router: String = ""
        var macAddress: String = ""
    }

    private var wifiInfo = WiFiInfo()

    // MARK: - UI

    private let statusDotView = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let networkNameLabel = NSTextField(labelWithString: "")
    private let signalIndicator = NSLevelIndicator()
    private let ipAddressLabel = NSTextField(labelWithString: "")
    private let subnetMaskLabel = NSTextField(labelWithString: "")
    private let routerLabel = NSTextField(labelWithString: "")
    private let macAddressLabel = NSTextField(labelWithString: "")
    private let menuBarCheck = NSButton(checkboxWithTitle: "Show Wi-Fi status in menu bar", target: nil, action: nil)

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

        // ===== Section: AirPort Status =====
        let statusBox = SnowLeopardPaneHelper.makeSectionBox(title: "AirPort Status")
        let statusStack = NSStackView()
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8
        statusStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Status row with dot
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
        statusStack.addArrangedSubview(statusRow)

        statusStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Current network
        networkNameLabel.font = SnowLeopardFonts.boldLabel(size: 12)
        networkNameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let networkRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Network Name:"),
            controls: [networkNameLabel]
        )
        statusStack.addArrangedSubview(networkRow)

        // Signal strength
        signalIndicator.levelIndicatorStyle = .continuousCapacity
        signalIndicator.minValue = 0
        signalIndicator.maxValue = 5
        signalIndicator.warningValue = 2
        signalIndicator.criticalValue = 1
        signalIndicator.widthAnchor.constraint(equalToConstant: 120).isActive = true

        let signalRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Signal Strength:"),
            controls: [signalIndicator]
        )
        statusStack.addArrangedSubview(signalRow)

        statusStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Turn On/Off button
        let toggleButton = NSButton(title: "Turn AirPort On/Off...", target: self, action: #selector(openWiFiSettings))
        toggleButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(toggleButton, size: 11)

        let toggleRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [toggleButton]
        )
        statusStack.addArrangedSubview(toggleRow)

        statusBox.contentView = statusStack
        outerStack.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Network Info =====
        let infoBox = SnowLeopardPaneHelper.makeSectionBox(title: "TCP/IP")
        let infoStack = NSStackView()
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 8
        infoStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // IP Address
        ipAddressLabel.font = SnowLeopardFonts.label(size: 11)
        ipAddressLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let ipRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("IP Address:"),
            controls: [ipAddressLabel]
        )
        infoStack.addArrangedSubview(ipRow)

        // Subnet Mask
        subnetMaskLabel.font = SnowLeopardFonts.label(size: 11)
        subnetMaskLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let subnetRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Subnet Mask:"),
            controls: [subnetMaskLabel]
        )
        infoStack.addArrangedSubview(subnetRow)

        // Router
        routerLabel.font = SnowLeopardFonts.label(size: 11)
        routerLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let routerRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Router:"),
            controls: [routerLabel]
        )
        infoStack.addArrangedSubview(routerRow)

        infoStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // MAC Address
        macAddressLabel.font = SnowLeopardFonts.label(size: 11)
        macAddressLabel.textColor = .secondaryLabelColor

        let macRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("AirPort ID:"),
            controls: [macAddressLabel]
        )
        infoStack.addArrangedSubview(macRow)

        infoBox.contentView = infoStack
        outerStack.addArrangedSubview(infoBox)
        infoBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Menu Bar Checkbox =====
        menuBarCheck.target = self
        menuBarCheck.action = #selector(menuBarCheckChanged(_:))
        SnowLeopardPaneHelper.styleControl(menuBarCheck)

        let menuBarRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [menuBarCheck]
        )
        outerStack.addArrangedSubview(menuBarRow)

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
        wifiInfo = WiFiInfo()

        // Get current Wi-Fi network name
        parseCurrentNetwork()

        // Get network info (IP, subnet, router)
        parseNetworkInfo()

        // Get MAC address
        parseMACAddress()

        // Update UI
        if wifiInfo.powered && !wifiInfo.currentNetwork.isEmpty {
            statusDotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "AirPort is on and connected to \(wifiInfo.currentNetwork)"
        } else if wifiInfo.powered {
            statusDotView.layer?.backgroundColor = NSColor.systemYellow.cgColor
            statusLabel.stringValue = "AirPort is on but not connected to a network"
        } else {
            statusDotView.layer?.backgroundColor = NSColor.systemRed.cgColor
            statusLabel.stringValue = "AirPort is off"
        }

        networkNameLabel.stringValue = wifiInfo.currentNetwork.isEmpty ? "N/A" : wifiInfo.currentNetwork

        // Signal strength: convert RSSI to 0-5 scale
        let signalBars = rssiToBars(wifiInfo.signalStrength)
        signalIndicator.doubleValue = Double(signalBars)

        ipAddressLabel.stringValue = wifiInfo.ipAddress.isEmpty ? "N/A" : wifiInfo.ipAddress
        subnetMaskLabel.stringValue = wifiInfo.subnetMask.isEmpty ? "N/A" : wifiInfo.subnetMask
        routerLabel.stringValue = wifiInfo.router.isEmpty ? "N/A" : wifiInfo.router
        macAddressLabel.stringValue = wifiInfo.macAddress.isEmpty ? "N/A" : wifiInfo.macAddress

        // Menu bar visibility
        let showInMenuBar = DefaultsService.shared.bool(forKey: "NSStatusItem Visible com.apple.menuextra.wifi", domain: "com.apple.controlcenter")
        menuBarCheck.state = (showInMenuBar ?? true) ? .on : .off
    }

    // MARK: - Shell Commands

    private func parseCurrentNetwork() {
        // Try networksetup first
        if let output = runCommand("/usr/sbin/networksetup", arguments: ["-getairportnetwork", "en0"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("Current Wi-Fi Network:") {
                wifiInfo.currentNetwork = trimmed
                    .replacingOccurrences(of: "Current Wi-Fi Network:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                wifiInfo.powered = true
            } else if trimmed.contains("Wi-Fi is not associated") || trimmed.contains("not associated") {
                wifiInfo.powered = true
                wifiInfo.currentNetwork = ""
            } else if trimmed.contains("Wi-Fi power is currently off") {
                wifiInfo.powered = false
            } else {
                wifiInfo.powered = true
            }
        }

        // Try to get RSSI via airport utility
        if let output = runCommand("/System/Library/PrivateFrameworks/Apple80211.framework/Resources/airport", arguments: ["-I"]) {
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("agrCtlRSSI:") {
                    let value = trimmed.replacingOccurrences(of: "agrCtlRSSI:", with: "").trimmingCharacters(in: .whitespaces)
                    wifiInfo.signalStrength = Int(value) ?? 0
                }
            }
        }
    }

    private func parseNetworkInfo() {
        guard let output = runCommand("/usr/sbin/networksetup", arguments: ["-getinfo", "Wi-Fi"]) else { return }
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("IP address:") {
                wifiInfo.ipAddress = line.replacingOccurrences(of: "IP address:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Subnet mask:") {
                wifiInfo.subnetMask = line.replacingOccurrences(of: "Subnet mask:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("Router:") {
                wifiInfo.router = line.replacingOccurrences(of: "Router:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
    }

    private func parseMACAddress() {
        if let output = runCommand("/usr/sbin/networksetup", arguments: ["-getmacaddress", "Wi-Fi"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            // Output: "Ethernet Address: XX:XX:XX:XX:XX:XX (Hardware Port: Wi-Fi)"
            if let range = trimmed.range(of: #"([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}"#, options: .regularExpression) {
                wifiInfo.macAddress = String(trimmed[range])
            }
        }
    }

    private func rssiToBars(_ rssi: Int) -> Int {
        // RSSI is typically negative: -30 excellent, -67 good, -70 fair, -80 weak, -90 none
        if rssi == 0 { return 0 }
        let absRSSI = abs(rssi)
        if absRSSI <= 40 { return 5 }
        if absRSSI <= 55 { return 4 }
        if absRSSI <= 67 { return 3 }
        if absRSSI <= 75 { return 2 }
        if absRSSI <= 85 { return 1 }
        return 0
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

    @objc private func openWiFiSettings() {
        guard let url = URL(string: "x-apple.systempreferences:\(settingsURL)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func menuBarCheckChanged(_ sender: NSButton) {
        // Changing menu bar items requires System Settings
        openWiFiSettings()
    }
}
