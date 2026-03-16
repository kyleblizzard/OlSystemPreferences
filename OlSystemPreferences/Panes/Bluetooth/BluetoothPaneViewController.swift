import Cocoa

class BluetoothPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "bluetooth" }
    var paneTitle: String { "Bluetooth" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "wave.3.right", accessibilityDescription: "Bluetooth") ?? NSImage()
    }
    var paneCategory: PaneCategory { .internetWireless }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 440) }
    var searchKeywords: [String] { ["bluetooth", "wireless", "pair", "connect", "devices", "discoverable"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.BluetoothSettings" }

    // MARK: - Data Model

    private struct BluetoothDevice {
        let name: String
        let type: String
        let connected: Bool
        let batteryLevel: Int? // -1 = unknown, 0-100 = percentage
    }

    private var devices: [BluetoothDevice] = []
    private var bluetoothPowered: Bool = false

    // MARK: - UI

    private let statusDotView = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let discoverableLabel = NSTextField(labelWithString: "")
    private let deviceTable = NSTableView()
    private let deviceScrollView = NSScrollView()
    private let menuBarCheck = NSButton(checkboxWithTitle: "Show Bluetooth in menu bar", target: nil, action: nil)

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

        // ===== Section: Bluetooth Status =====
        let statusBox = SnowLeopardPaneHelper.makeSectionBox(title: "Bluetooth Status")
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

        // Discoverable status
        discoverableLabel.font = SnowLeopardFonts.label(size: 11)
        discoverableLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let discoverRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Discoverable:"),
            controls: [discoverableLabel]
        )
        statusStack.addArrangedSubview(discoverRow)

        statusStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Turn On/Off button — opens System Settings
        let toggleButton = NSButton(title: "Turn Bluetooth On/Off...", target: self, action: #selector(openBluetoothSettings))
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

        // ===== Section: Devices =====
        let devicesBox = SnowLeopardPaneHelper.makeSectionBox(title: "Devices")
        let devicesStack = NSStackView()
        devicesStack.translatesAutoresizingMaskIntoConstraints = false
        devicesStack.orientation = .vertical
        devicesStack.alignment = .leading
        devicesStack.spacing = 8
        devicesStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let devicesInfo = SnowLeopardPaneHelper.makeLabel(
            "Paired Bluetooth devices are listed below.",
            size: 10
        )
        devicesInfo.textColor = .secondaryLabelColor
        devicesStack.addArrangedSubview(devicesInfo)

        // Device table
        deviceScrollView.translatesAutoresizingMaskIntoConstraints = false
        deviceScrollView.hasVerticalScroller = true
        deviceScrollView.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 260
        deviceTable.addTableColumn(nameCol)

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        typeCol.width = 140
        deviceTable.addTableColumn(typeCol)

        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("connected"))
        statusCol.title = "Status"
        statusCol.width = 80
        deviceTable.addTableColumn(statusCol)

        let batteryCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("battery"))
        batteryCol.title = "Battery"
        batteryCol.width = 60
        deviceTable.addTableColumn(batteryCol)

        deviceTable.delegate = self
        deviceTable.dataSource = self
        deviceTable.rowHeight = 22
        deviceTable.usesAlternatingRowBackgroundColors = true

        deviceScrollView.documentView = deviceTable
        deviceScrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        deviceScrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        devicesStack.addArrangedSubview(deviceScrollView)

        devicesBox.contentView = devicesStack
        outerStack.addArrangedSubview(devicesBox)
        devicesBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

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
        // Read Bluetooth power state
        bluetoothPowered = readBluetoothPowerState()

        if bluetoothPowered {
            statusDotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "Bluetooth: On"
            discoverableLabel.stringValue = "Yes, when Bluetooth preferences are open"
        } else {
            statusDotView.layer?.backgroundColor = NSColor.systemRed.cgColor
            statusLabel.stringValue = "Bluetooth: Off"
            discoverableLabel.stringValue = "No"
        }

        // Read paired devices
        devices = parsePairedDevices()
        deviceTable.reloadData()

        // Menu bar visibility
        let showInMenuBar = DefaultsService.shared.bool(forKey: "NSStatusItem Visible com.apple.menuextra.bluetooth", domain: "com.apple.controlcenter")
        menuBarCheck.state = (showInMenuBar ?? true) ? .on : .off
    }

    // MARK: - Shell Commands

    private func readBluetoothPowerState() -> Bool {
        guard let output = runCommand("/usr/bin/defaults", arguments: ["read", "/Library/Preferences/com.apple.Bluetooth", "ControllerPowerState"]) else {
            return false
        }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "1"
    }

    private func parsePairedDevices() -> [BluetoothDevice] {
        guard let output = runCommand("/usr/sbin/system_profiler", arguments: ["SPBluetoothDataType"]) else {
            return []
        }

        var parsed: [BluetoothDevice] = []
        let lines = output.components(separatedBy: "\n")

        var currentName: String?
        var currentType = "Device"
        var currentConnected = false
        var currentBattery: Int? = nil
        var inDevicesSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect the devices section (Connected / Not Connected / Paired)
            if trimmed.contains("Devices (Paired)") || trimmed.contains("Connected:") || trimmed.contains("Not Connected:") || trimmed.contains("Paired:") {
                inDevicesSection = true
                continue
            }

            guard inDevicesSection else { continue }

            // A device name line ends with a colon and has no other colon
            if trimmed.hasSuffix(":") && !trimmed.contains("  ") {
                // Save previous device
                if let name = currentName, !name.isEmpty {
                    parsed.append(BluetoothDevice(name: name, type: currentType, connected: currentConnected, batteryLevel: currentBattery))
                }
                currentName = String(trimmed.dropLast()) // remove trailing colon
                currentType = "Device"
                currentConnected = false
                currentBattery = nil
            } else if trimmed.hasPrefix("Minor Type:") {
                currentType = trimmed.replacingOccurrences(of: "Minor Type:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Connected:") {
                let val = trimmed.replacingOccurrences(of: "Connected:", with: "").trimmingCharacters(in: .whitespaces)
                currentConnected = val.lowercased() == "yes"
            } else if trimmed.hasPrefix("Battery Level:") {
                // Parse battery percentage (e.g. "Battery Level: 85%")
                let val = trimmed.replacingOccurrences(of: "Battery Level:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: "%", with: "")
                currentBattery = Int(val)
            }
        }

        // Capture last device
        if let name = currentName, !name.isEmpty {
            parsed.append(BluetoothDevice(name: name, type: currentType, connected: currentConnected, batteryLevel: currentBattery))
        }

        return parsed
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

    @objc private func openBluetoothSettings() {
        guard let url = URL(string: "x-apple.systempreferences:\(settingsURL)") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func menuBarCheckChanged(_ sender: NSButton) {
        // Changing Control Center menu bar items requires System Settings
        openBluetoothSettings()
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension BluetoothPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return devices.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < devices.count else { return nil }
        let device = devices[row]
        let colID = tableColumn?.identifier.rawValue ?? ""

        switch colID {
        case "name":
            let label = NSTextField(labelWithString: device.name)
            label.font = SnowLeopardFonts.label(size: 12)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
            return label

        case "type":
            let label = NSTextField(labelWithString: device.type)
            label.font = SnowLeopardFonts.label(size: 12)
            label.textColor = .secondaryLabelColor
            return label

        case "connected":
            let container = NSView()
            let dot = NSView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = device.connected ? NSColor.systemGreen.cgColor : NSColor.systemGray.cgColor
            container.addSubview(dot)

            let statusText = NSTextField(labelWithString: device.connected ? "Connected" : "Not Connected")
            statusText.translatesAutoresizingMaskIntoConstraints = false
            statusText.font = SnowLeopardFonts.label(size: 11)
            statusText.textColor = device.connected ? NSColor.systemGreen : .secondaryLabelColor
            container.addSubview(statusText)

            NSLayoutConstraint.activate([
                dot.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                dot.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
                statusText.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
                statusText.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container

        case "battery":
            // Show battery percentage if available for connected devices
            if let level = device.batteryLevel {
                let label = NSTextField(labelWithString: "\(level)%")
                label.font = SnowLeopardFonts.label(size: 11)
                label.textColor = level <= 20 ? .systemRed : .secondaryLabelColor
                return label
            } else {
                let label = NSTextField(labelWithString: device.connected ? "—" : "")
                label.font = SnowLeopardFonts.label(size: 11)
                label.textColor = .secondaryLabelColor
                return label
            }

        default:
            return nil
        }
    }
}
