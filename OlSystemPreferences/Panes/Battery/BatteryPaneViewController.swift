import Cocoa

class BatteryPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "battery" }
    var paneTitle: String { "Energy Saver" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "battery.100percent", accessibilityDescription: "Energy Saver") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 460) }
    var searchKeywords: [String] { ["battery", "energy", "power", "sleep", "display sleep", "hard disk", "dim", "charging"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Battery-Settings.extension" }

    // MARK: - Data

    private struct BatteryInfo {
        var percentage: Int = -1
        var isCharging: Bool = false
        var powerSource: String = "Unknown"
        var timeRemaining: String = ""
    }

    private struct SleepSettings {
        var displaySleep: Int = 10 // minutes
        var computerSleep: Int = 0 // 0 = never
        var diskSleep: Bool = true
        var dimOnBattery: Bool = true
    }

    private var batteryInfo = BatteryInfo()
    private var sleepSettings = SleepSettings()

    // MARK: - UI

    private let batteryPercentLabel = NSTextField(labelWithString: "")
    private let chargingStatusLabel = NSTextField(labelWithString: "")
    private let powerSourceLabel = NSTextField(labelWithString: "")
    private let batteryLevelIndicator = NSLevelIndicator()

    private let displaySleepSlider = NSSlider(value: 10, minValue: 1, maxValue: 180, target: nil, action: nil)
    private let displaySleepValueLabel = NSTextField(labelWithString: "10 min")
    private let computerSleepSlider = NSSlider(value: 0, minValue: 0, maxValue: 180, target: nil, action: nil)
    private let computerSleepValueLabel = NSTextField(labelWithString: "Never")

    private let diskSleepCheck = NSButton(checkboxWithTitle: "Put hard disks to sleep when possible", target: nil, action: nil)
    private let dimDisplayCheck = NSButton(checkboxWithTitle: "Slightly dim the display while on battery power", target: nil, action: nil)
    private let preventSleepCheck = NSButton(checkboxWithTitle: "Prevent computer from sleeping automatically when the display is off", target: nil, action: nil)

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

        // ===== Section: Battery Status =====
        let statusBox = SnowLeopardPaneHelper.makeSectionBox(title: "Battery Status")
        let statusStack = NSStackView()
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8
        statusStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Battery level indicator
        batteryLevelIndicator.levelIndicatorStyle = .continuousCapacity
        batteryLevelIndicator.minValue = 0
        batteryLevelIndicator.maxValue = 100
        batteryLevelIndicator.warningValue = 20
        batteryLevelIndicator.criticalValue = 10
        batteryLevelIndicator.widthAnchor.constraint(equalToConstant: 200).isActive = true

        batteryPercentLabel.font = SnowLeopardFonts.boldLabel(size: 12)
        batteryPercentLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let batteryRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Battery Level:"),
            controls: [batteryLevelIndicator, batteryPercentLabel]
        )
        statusStack.addArrangedSubview(batteryRow)

        // Charging status
        chargingStatusLabel.font = SnowLeopardFonts.label(size: 11)
        chargingStatusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let chargingRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Status:"),
            controls: [chargingStatusLabel]
        )
        statusStack.addArrangedSubview(chargingRow)

        // Power source
        powerSourceLabel.font = SnowLeopardFonts.label(size: 11)
        powerSourceLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let sourceRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Power Source:"),
            controls: [powerSourceLabel]
        )
        statusStack.addArrangedSubview(sourceRow)

        statusBox.contentView = statusStack
        outerStack.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Energy Settings =====
        let energyBox = SnowLeopardPaneHelper.makeSectionBox(title: "Energy Settings")
        let energyStack = NSStackView()
        energyStack.translatesAutoresizingMaskIntoConstraints = false
        energyStack.orientation = .vertical
        energyStack.alignment = .leading
        energyStack.spacing = 10
        energyStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

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
        energyStack.addArrangedSubview(dSleepRow)

        // Computer sleep slider
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
        energyStack.addArrangedSubview(cSleepRow)

        energyStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Checkboxes
        let allChecks = [diskSleepCheck, dimDisplayCheck, preventSleepCheck]
        for check in allChecks {
            check.target = self
            check.action = #selector(energyOptionChanged(_:))
            SnowLeopardPaneHelper.styleControl(check)

            let row = SnowLeopardPaneHelper.makeRow(
                label: SnowLeopardPaneHelper.makeLabel(""),
                controls: [check]
            )
            energyStack.addArrangedSubview(row)
        }

        energyBox.contentView = energyStack
        outerStack.addArrangedSubview(energyBox)
        energyBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

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
        // Battery info via pmset
        parseBatteryInfo()
        parseSleepSettings()

        // Update battery UI
        if batteryInfo.percentage >= 0 {
            batteryLevelIndicator.doubleValue = Double(batteryInfo.percentage)
            batteryPercentLabel.stringValue = "\(batteryInfo.percentage)%"
        } else {
            batteryLevelIndicator.doubleValue = 0
            batteryPercentLabel.stringValue = "N/A (Desktop Mac)"
        }

        if batteryInfo.isCharging {
            chargingStatusLabel.stringValue = "Charging"
        } else if batteryInfo.percentage >= 0 {
            chargingStatusLabel.stringValue = batteryInfo.timeRemaining.isEmpty ? "On Battery" : "On Battery — \(batteryInfo.timeRemaining)"
        } else {
            chargingStatusLabel.stringValue = "Power Adapter"
        }

        powerSourceLabel.stringValue = batteryInfo.powerSource

        // Sleep settings UI
        displaySleepSlider.integerValue = sleepSettings.displaySleep
        updateSleepLabel(displaySleepValueLabel, minutes: sleepSettings.displaySleep)

        computerSleepSlider.integerValue = sleepSettings.computerSleep
        updateSleepLabel(computerSleepValueLabel, minutes: sleepSettings.computerSleep)

        diskSleepCheck.state = sleepSettings.diskSleep ? .on : .off
        dimDisplayCheck.state = sleepSettings.dimOnBattery ? .on : .off
        preventSleepCheck.state = .off
    }

    // MARK: - Parsing

    private func parseBatteryInfo() {
        guard let output = runCommand("/usr/bin/pmset", arguments: ["-g", "batt"]) else { return }
        let lines = output.components(separatedBy: "\n")

        // First line: power source
        if let firstLine = lines.first {
            if firstLine.contains("AC Power") {
                batteryInfo.powerSource = "AC Power"
            } else if firstLine.contains("Battery Power") {
                batteryInfo.powerSource = "Battery Power"
            } else {
                batteryInfo.powerSource = "AC Power"
            }
        }

        // Second line typically has battery percentage
        for line in lines {
            if line.contains("InternalBattery") || line.contains("Battery") {
                // Extract percentage
                if let range = line.range(of: #"\d+%"#, options: .regularExpression) {
                    let percentStr = String(line[range]).replacingOccurrences(of: "%", with: "")
                    batteryInfo.percentage = Int(percentStr) ?? -1
                }
                batteryInfo.isCharging = line.contains("charging") && !line.contains("not charging")
                // Extract time remaining
                if let timeRange = line.range(of: #"\d+:\d+"#, options: .regularExpression) {
                    batteryInfo.timeRemaining = String(line[timeRange]) + " remaining"
                }
            }
        }
    }

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

    @objc private func displaySleepChanged(_ sender: NSSlider) {
        let minutes = sender.integerValue
        updateSleepLabel(displaySleepValueLabel, minutes: minutes)
        // pmset requires sudo, so just update display — actual changes need System Settings
    }

    @objc private func computerSleepChanged(_ sender: NSSlider) {
        let minutes = sender.integerValue
        updateSleepLabel(computerSleepValueLabel, minutes: minutes)
    }

    @objc private func energyOptionChanged(_ sender: NSButton) {
        // Energy settings changes require admin privileges
        // Just update UI state; actual changes need System Settings
    }
}
