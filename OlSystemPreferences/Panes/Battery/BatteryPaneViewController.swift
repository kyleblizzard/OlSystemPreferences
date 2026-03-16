import Cocoa

class BatteryPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "energysaver" }
    var paneTitle: String { "Energy Saver" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "battery.100percent", accessibilityDescription: "Energy Saver") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 460) }
    var searchKeywords: [String] { ["battery", "energy", "power", "sleep", "display sleep", "hard disk", "dim", "schedule", "wake"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Battery-Settings.extension" }

    // MARK: - Data

    private struct SleepSettings {
        var computerSleep: Int = 0 // 0 = never
        var displaySleep: Int = 10 // minutes
        var diskSleep: Bool = true
        var wakeForNetwork: Bool = true
        var dimOnBattery: Bool = true
    }

    private var sleepSettings = SleepSettings()

    // MARK: - UI

    private let computerSleepSlider = NSSlider(value: 0, minValue: 1, maxValue: 180, target: nil, action: nil)
    private let computerSleepValueLabel = NSTextField(labelWithString: "Never")
    private let displaySleepSlider = NSSlider(value: 10, minValue: 1, maxValue: 180, target: nil, action: nil)
    private let displaySleepValueLabel = NSTextField(labelWithString: "10 min")

    private let diskSleepCheck = NSButton(checkboxWithTitle: "Put the hard disk(s) to sleep when possible", target: nil, action: nil)
    private let wakeForNetworkCheck = NSButton(checkboxWithTitle: "Wake for network access", target: nil, action: nil)
    private let dimDisplayCheck = NSButton(checkboxWithTitle: "Automatically reduce brightness before display goes to sleep", target: nil, action: nil)

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

        // ===== Section: Settings =====
        let settingsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Settings")
        let settingsStack = NSStackView()
        settingsStack.translatesAutoresizingMaskIntoConstraints = false
        settingsStack.orientation = .vertical
        settingsStack.alignment = .leading
        settingsStack.spacing = 10
        settingsStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Computer sleep slider (Snow Leopard order: computer first)
        computerSleepSlider.target = self
        computerSleepSlider.action = #selector(computerSleepChanged(_:))
        computerSleepSlider.isContinuous = true
        computerSleepSlider.widthAnchor.constraint(equalToConstant: 240).isActive = true
        SnowLeopardPaneHelper.styleControl(computerSleepSlider)

        computerSleepValueLabel.font = SnowLeopardFonts.label(size: 10)
        computerSleepValueLabel.textColor = .secondaryLabelColor
        computerSleepValueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let cSleepRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Computer sleep:"),
            controls: [
                SnowLeopardPaneHelper.makeLabel("1 min", size: 10),
                computerSleepSlider,
                SnowLeopardPaneHelper.makeLabel("Never", size: 10),
                computerSleepValueLabel,
            ],
            spacing: 4
        )
        settingsStack.addArrangedSubview(cSleepRow)

        // Display sleep slider
        displaySleepSlider.target = self
        displaySleepSlider.action = #selector(displaySleepChanged(_:))
        displaySleepSlider.isContinuous = true
        displaySleepSlider.widthAnchor.constraint(equalToConstant: 240).isActive = true
        SnowLeopardPaneHelper.styleControl(displaySleepSlider)

        displaySleepValueLabel.font = SnowLeopardFonts.label(size: 10)
        displaySleepValueLabel.textColor = .secondaryLabelColor
        displaySleepValueLabel.widthAnchor.constraint(equalToConstant: 60).isActive = true

        let dSleepRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Display sleep:"),
            controls: [
                SnowLeopardPaneHelper.makeLabel("1 min", size: 10),
                displaySleepSlider,
                SnowLeopardPaneHelper.makeLabel("Never", size: 10),
                displaySleepValueLabel,
            ],
            spacing: 4
        )
        settingsStack.addArrangedSubview(dSleepRow)

        // Separator between sliders and checkboxes
        settingsStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Checkboxes
        let allChecks = [diskSleepCheck, wakeForNetworkCheck, dimDisplayCheck]
        for check in allChecks {
            check.target = self
            check.action = #selector(energyOptionChanged(_:))
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

        // ===== Schedule Button =====
        let scheduleRow = NSStackView()
        scheduleRow.orientation = .horizontal
        scheduleRow.alignment = .centerY
        scheduleRow.spacing = 0

        let scheduleSpacer = NSView()
        scheduleSpacer.translatesAutoresizingMaskIntoConstraints = false
        scheduleSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let scheduleButton = NSButton(title: "Schedule...", target: self, action: #selector(scheduleClicked(_:)))
        scheduleButton.bezelStyle = .rounded
        scheduleButton.font = SnowLeopardFonts.label(size: 11)

        scheduleRow.addArrangedSubview(scheduleSpacer)
        scheduleRow.addArrangedSubview(scheduleButton)

        outerStack.addArrangedSubview(scheduleRow)
        scheduleRow.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Lock Icon Row =====
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
        parseSleepSettings()

        // Computer sleep
        computerSleepSlider.integerValue = sleepSettings.computerSleep
        updateSleepLabel(computerSleepValueLabel, minutes: sleepSettings.computerSleep)

        // Display sleep
        displaySleepSlider.integerValue = sleepSettings.displaySleep
        updateSleepLabel(displaySleepValueLabel, minutes: sleepSettings.displaySleep)

        // Checkboxes
        diskSleepCheck.state = sleepSettings.diskSleep ? .on : .off
        wakeForNetworkCheck.state = sleepSettings.wakeForNetwork ? .on : .off
        dimDisplayCheck.state = sleepSettings.dimOnBattery ? .on : .off
    }

    // MARK: - Parsing

    private func parseSleepSettings() {
        guard let output = runCommand("/usr/bin/pmset", arguments: ["-g", "custom"]) else { return }
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("displaysleep") {
                let value = trimmed.replacingOccurrences(of: "displaysleep", with: "").trimmingCharacters(in: .whitespaces)
                sleepSettings.displaySleep = Int(value) ?? 10
            } else if trimmed.hasPrefix("sleep ") && !trimmed.contains("display") && !trimmed.contains("disk") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    sleepSettings.computerSleep = Int(parts[1]) ?? 0
                }
            } else if trimmed.hasPrefix("disksleep") {
                let value = trimmed.replacingOccurrences(of: "disksleep", with: "").trimmingCharacters(in: .whitespaces)
                sleepSettings.diskSleep = (Int(value) ?? 10) > 0
            } else if trimmed.hasPrefix("lessbright") {
                let value = trimmed.replacingOccurrences(of: "lessbright", with: "").trimmingCharacters(in: .whitespaces)
                sleepSettings.dimOnBattery = value == "1"
            } else if trimmed.hasPrefix("womp") {
                let value = trimmed.replacingOccurrences(of: "womp", with: "").trimmingCharacters(in: .whitespaces)
                sleepSettings.wakeForNetwork = value == "1"
            }
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

    // MARK: - Helpers

    private func updateSleepLabel(_ label: NSTextField, minutes: Int) {
        if minutes == 0 || minutes >= 180 {
            label.stringValue = "Never"
        } else if minutes == 1 {
            label.stringValue = "1 min"
        } else if minutes < 60 {
            label.stringValue = "\(minutes) min"
        } else {
            let hrs = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                label.stringValue = "\(hrs) hr"
            } else {
                label.stringValue = "\(hrs)h \(mins)m"
            }
        }
    }

    // MARK: - Actions

    @objc private func computerSleepChanged(_ sender: NSSlider) {
        let minutes = sender.integerValue
        updateSleepLabel(computerSleepValueLabel, minutes: minutes)
    }

    @objc private func displaySleepChanged(_ sender: NSSlider) {
        let minutes = sender.integerValue
        updateSleepLabel(displaySleepValueLabel, minutes: minutes)
        // pmset requires sudo, so just update display — actual changes need System Settings
    }

    @objc private func energyOptionChanged(_ sender: NSButton) {
        // Energy settings changes require admin privileges
        // Just update UI state; actual changes need System Settings
    }

    @objc private func scheduleClicked(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Schedule"
        alert.informativeText = "Schedule configuration requires System Settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SystemSettingsLauncher.open(url: settingsURL)
        }
    }
}
