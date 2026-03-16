import Cocoa

class SoftwareUpdatePaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "softwareupdate" }
    var paneTitle: String { "Software Update" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "gear.badge", accessibilityDescription: "Software Update") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 400) }
    var searchKeywords: [String] { ["software", "update", "macos", "version", "check", "automatic", "download", "install"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Software-Update-Settings.extension" }

    // MARK: - Services

    private let defaults = DefaultsService.shared

    // MARK: - UI

    private let macIconView = NSImageView()
    private let macModelLabel = NSTextField(labelWithString: "")
    private let macOSVersionLabel = NSTextField(labelWithString: "")
    private let macOSBuildLabel = NSTextField(labelWithString: "")

    // "About This Mac" mini section
    private let processorLabel = NSTextField(labelWithString: "")
    private let memoryLabel = NSTextField(labelWithString: "")
    private let serialLabel = NSTextField(labelWithString: "")
    private let diskLabel = NSTextField(labelWithString: "")

    private let autoCheckBox = NSButton(checkboxWithTitle: "Check for updates automatically", target: nil, action: nil)
    private let autoDownloadBox = NSButton(checkboxWithTitle: "Download newly available updates in background", target: nil, action: nil)
    private let autoInstallBox = NSButton(checkboxWithTitle: "Install macOS updates", target: nil, action: nil)
    private let autoAppUpdateBox = NSButton(checkboxWithTitle: "Install app updates from the App Store", target: nil, action: nil)
    private let installSecurityBox = NSButton(checkboxWithTitle: "Install system data files and security updates", target: nil, action: nil)

    private let checkNowButton = NSButton()
    private let lastCheckLabel = NSTextField(labelWithString: "")

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

        // ===== Section: System Info =====
        let infoBox = SnowLeopardPaneHelper.makeSectionBox()
        let infoStack = NSStackView()
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.orientation = .horizontal
        infoStack.alignment = .top
        infoStack.spacing = 16
        infoStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Mac icon
        macIconView.translatesAutoresizingMaskIntoConstraints = false
        macIconView.imageScaling = .scaleProportionallyUpOrDown
        macIconView.image = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "Mac")
        macIconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        macIconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        infoStack.addArrangedSubview(macIconView)

        // Version info column
        let versionColumn = NSStackView()
        versionColumn.orientation = .vertical
        versionColumn.alignment = .leading
        versionColumn.spacing = 4

        macModelLabel.font = SnowLeopardFonts.boldLabel(size: 12)
        macModelLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        versionColumn.addArrangedSubview(macModelLabel)

        macOSVersionLabel.font = SnowLeopardFonts.label(size: 11)
        macOSVersionLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        versionColumn.addArrangedSubview(macOSVersionLabel)

        macOSBuildLabel.font = SnowLeopardFonts.label(size: 10)
        macOSBuildLabel.textColor = .secondaryLabelColor
        versionColumn.addArrangedSubview(macOSBuildLabel)

        // Hardware info labels (mini "About This Mac")
        let hwLabels = [processorLabel, memoryLabel, serialLabel, diskLabel]
        for label in hwLabels {
            label.font = SnowLeopardFonts.label(size: 10)
            label.textColor = .secondaryLabelColor
            versionColumn.addArrangedSubview(label)
        }

        infoStack.addArrangedSubview(versionColumn)

        infoBox.contentView = infoStack
        outerStack.addArrangedSubview(infoBox)
        infoBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Update Settings =====
        let settingsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Automatic Updates")
        let settingsStack = NSStackView()
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        settingsStack.orientation = .vertical
        settingsStack.alignment = .leading
        settingsStack.spacing = 6
        settingsStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let allChecks = [autoCheckBox, autoDownloadBox, autoInstallBox, autoAppUpdateBox, installSecurityBox]
        for check in allChecks {
            check.target = self
            check.action = #selector(updateSettingChanged(_:))
            SnowLeopardPaneHelper.styleControl(check)

            let row = SnowLeopardPaneHelper.makeRow(
                label: SnowLeopardPaneHelper.makeLabel(""),
                controls: [check]
            )
            settingsStack.addArrangedSubview(row)
        }

        settingsBox.contentView = settingsStack
        outerStack.addArrangedSubview(settingsBox)
        settingsBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Bottom: Check Now + Last Check =====
        let bottomRow = NSStackView()
        bottomRow.orientation = .horizontal
        bottomRow.spacing = 12
        bottomRow.alignment = .centerY

        checkNowButton.title = "Check Now"
        checkNowButton.bezelStyle = .rounded
        checkNowButton.font = SnowLeopardFonts.label(size: 11)
        checkNowButton.target = self
        checkNowButton.action = #selector(checkNowClicked(_:))
        bottomRow.addArrangedSubview(checkNowButton)

        lastCheckLabel.font = SnowLeopardFonts.label(size: 10)
        lastCheckLabel.textColor = .secondaryLabelColor
        bottomRow.addArrangedSubview(lastCheckLabel)

        outerStack.addArrangedSubview(bottomRow)

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
        // macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let versionString = "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        macOSVersionLabel.stringValue = versionString

        // Build number
        macOSBuildLabel.stringValue = "Build: \(ProcessInfo.processInfo.operatingSystemVersionString)"

        // Mac model
        macModelLabel.stringValue = getMacModel()

        // Processor
        processorLabel.stringValue = "Processor: \(getProcessorName())"

        // Memory
        let ramGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)
        memoryLabel.stringValue = "Memory: \(ramGB) GB"

        // Serial number
        serialLabel.stringValue = "Serial: \(getSerialNumber())"

        // Disk space
        diskLabel.stringValue = "Disk: \(getDiskInfo())"

        // Update settings from com.apple.SoftwareUpdate domain
        let suDomain = "com.apple.SoftwareUpdate"

        let autoCheck = defaults.bool(forKey: "AutomaticCheckEnabled", domain: suDomain) ?? true
        autoCheckBox.state = autoCheck ? .on : .off

        let autoDownload = defaults.bool(forKey: "AutomaticDownload", domain: suDomain) ?? true
        autoDownloadBox.state = autoDownload ? .on : .off

        let autoInstall = defaults.bool(forKey: "AutomaticallyInstallMacOSUpdates", domain: suDomain) ?? false
        autoInstallBox.state = autoInstall ? .on : .off

        // App Store auto updates
        let autoAppDomain = "com.apple.commerce"
        let autoApp = defaults.bool(forKey: "AutoUpdate", domain: autoAppDomain) ?? true
        autoAppUpdateBox.state = autoApp ? .on : .off

        // Security updates
        let configDomain = "com.apple.SoftwareUpdate"
        let configData = defaults.bool(forKey: "CriticalUpdateInstall", domain: configDomain) ?? true
        installSecurityBox.state = configData ? .on : .off

        // Last check date
        let lastCheck = defaults.any(forKey: "LastSuccessfulDate", domain: suDomain)
        if let date = lastCheck as? Date {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            lastCheckLabel.stringValue = "Last checked: \(fmt.string(from: date))"
        } else {
            lastCheckLabel.stringValue = "Last checked: Unknown"
        }

        // Enable/disable sub-options based on auto check
        autoDownloadBox.isEnabled = autoCheck
        autoInstallBox.isEnabled = autoCheck
        autoAppUpdateBox.isEnabled = autoCheck
        installSecurityBox.isEnabled = autoCheck
    }

    // MARK: - Helpers

    private func getMacModel() -> String {
        return runCommand("/usr/sbin/sysctl", arguments: ["-n", "hw.model"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Mac"
    }

    /// Read the CPU brand string (e.g. "Apple M1 Pro" or "Intel Core i9-9900K")
    private func getProcessorName() -> String {
        return runCommand("/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }

    /// Read the Mac serial number from IOKit
    private func getSerialNumber() -> String {
        guard let output = runCommand("/usr/sbin/ioreg", arguments: ["-l", "-d", "2"]) else { return "Unknown" }
        for line in output.components(separatedBy: "\n") {
            if line.contains("IOPlatformSerialNumber") {
                let parts = line.components(separatedBy: "\"")
                if parts.count >= 4 { return parts[3] }
            }
        }
        return "Unknown"
    }

    /// Read total and free disk space for the boot volume
    private func getDiskInfo() -> String {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let total = (attrs[.systemSize] as? Int64) ?? 0
            let free = (attrs[.systemFreeSize] as? Int64) ?? 0
            let totalGB = Double(total) / 1_000_000_000
            let freeGB = Double(free) / 1_000_000_000
            return String(format: "%.0f GB total, %.0f GB available", totalGB, freeGB)
        } catch {
            return "Unknown"
        }
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

    @objc private func updateSettingChanged(_ sender: NSButton) {
        let on = sender.state == .on
        let suDomain = "com.apple.SoftwareUpdate"

        switch sender {
        case autoCheckBox:
            defaults.setBool(on, forKey: "AutomaticCheckEnabled", domain: suDomain)
            // Enable/disable sub-options
            autoDownloadBox.isEnabled = on
            autoInstallBox.isEnabled = on
            autoAppUpdateBox.isEnabled = on
            installSecurityBox.isEnabled = on
        case autoDownloadBox:
            defaults.setBool(on, forKey: "AutomaticDownload", domain: suDomain)
        case autoInstallBox:
            defaults.setBool(on, forKey: "AutomaticallyInstallMacOSUpdates", domain: suDomain)
        case autoAppUpdateBox:
            defaults.setBool(on, forKey: "AutoUpdate", domain: "com.apple.commerce")
        case installSecurityBox:
            defaults.setBool(on, forKey: "CriticalUpdateInstall", domain: suDomain)
        default:
            break
        }
    }

    @objc private func checkNowClicked(_ sender: NSButton) {
        // Open Software Update in System Settings
        if let url = URL(string: "x-apple.systempreferences:\(settingsURL)") {
            NSWorkspace.shared.open(url)
        }
    }
}
