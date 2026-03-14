import Cocoa

class DisplaysPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "displays" }
    var paneTitle: String { "Displays" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "display", accessibilityDescription: "Displays") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 540) }
    var searchKeywords: [String] { ["display", "monitor", "resolution", "screen", "brightness", "refresh rate", "scaled"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Displays-Settings.extension" }

    // MARK: - Controls

    private let brightnessSlider = AquaSlider(minValue: 0, maxValue: 1, value: 0.5)
    private let autoBrightnessCheck = AquaCheckbox(title: "Automatically adjust brightness", isChecked: false)
    private let defaultRadio = AquaRadioButton(title: "Default for display", isSelected: true)
    private let scaledRadio = AquaRadioButton(title: "Scaled", isSelected: false)
    private let resolutionTable = NSTableView()
    private let resolutionScrollView = NSScrollView()
    private let currentResLabel = NSTextField(labelWithString: "")
    private let displayPreviewBox = NSBox()

    // Data
    private var displayModes: [(width: Int, height: Int, refreshRate: Double)] = []

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Outer stack
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 16
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Display Preview
        // =====================================================================
        displayPreviewBox.boxType = .custom
        displayPreviewBox.fillColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.20, alpha: 1.0)
        displayPreviewBox.borderColor = NSColor(white: 0.3, alpha: 1.0)
        displayPreviewBox.borderWidth = 3
        displayPreviewBox.cornerRadius = 4
        displayPreviewBox.translatesAutoresizingMaskIntoConstraints = false
        displayPreviewBox.widthAnchor.constraint(equalToConstant: 180).isActive = true
        displayPreviewBox.heightAnchor.constraint(equalToConstant: 110).isActive = true

        // Stand below monitor
        let standView = NSView()
        standView.translatesAutoresizingMaskIntoConstraints = false
        standView.wantsLayer = true
        standView.layer?.backgroundColor = NSColor(white: 0.6, alpha: 1.0).cgColor
        standView.widthAnchor.constraint(equalToConstant: 60).isActive = true
        standView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let previewColumn = NSStackView()
        previewColumn.orientation = .vertical
        previewColumn.alignment = .centerX
        previewColumn.spacing = 0
        previewColumn.addArrangedSubview(displayPreviewBox)
        previewColumn.addArrangedSubview(standView)

        // Add monitor name label
        let monitorName = SnowLeopardPaneHelper.makeLabel("Built-in Display", size: 10)
        monitorName.textColor = .secondaryLabelColor
        monitorName.alignment = .center
        previewColumn.addArrangedSubview(monitorName)
        previewColumn.setCustomSpacing(4, after: standView)

        // Center the preview
        let previewWrapper = NSStackView(views: [previewColumn])
        previewWrapper.alignment = .centerX
        outerStack.addArrangedSubview(previewWrapper)
        previewWrapper.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Section: Brightness
        // =====================================================================
        let brightBox = SnowLeopardPaneHelper.makeSectionBox(title: "Brightness")
        let brightStack = NSStackView()
        brightStack.translatesAutoresizingMaskIntoConstraints = false
        brightStack.orientation = .vertical
        brightStack.alignment = .leading
        brightStack.spacing = 8
        brightStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        brightnessSlider.target = self
        brightnessSlider.action = #selector(brightnessChanged(_:))
        brightnessSlider.isContinuous = true
        brightnessSlider.showsFillColor = true
        brightnessSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let dimLabel = SnowLeopardPaneHelper.makeLabel("Dim", size: 10)
        let brightLabel = SnowLeopardPaneHelper.makeLabel("Bright", size: 10)

        let brightnessRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Brightness:"),
            controls: [dimLabel, brightnessSlider, brightLabel],
            spacing: 6
        )
        brightStack.addArrangedSubview(brightnessRow)

        autoBrightnessCheck.target = self
        autoBrightnessCheck.action = #selector(autoBrightnessChanged(_:))
        let autoRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [autoBrightnessCheck]
        )
        brightStack.addArrangedSubview(autoRow)

        brightBox.contentView = brightStack
        outerStack.addArrangedSubview(brightBox)
        brightBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Section: Resolution
        // =====================================================================
        let resBox = SnowLeopardPaneHelper.makeSectionBox(title: "Resolution")
        let resStack = NSStackView()
        resStack.translatesAutoresizingMaskIntoConstraints = false
        resStack.orientation = .vertical
        resStack.alignment = .leading
        resStack.spacing = 10
        resStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Resolution mode radios
        defaultRadio.target = self
        defaultRadio.action = #selector(resolutionModeChanged(_:))
        scaledRadio.target = self
        scaledRadio.action = #selector(resolutionModeChanged(_:))

        let radioRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Resolution:"),
            controls: [defaultRadio, scaledRadio]
        )
        resStack.addArrangedSubview(radioRow)

        // Resolution table
        resolutionScrollView.translatesAutoresizingMaskIntoConstraints = false
        resolutionScrollView.hasVerticalScroller = true
        resolutionScrollView.borderType = .bezelBorder

        let resCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("resolution"))
        resCol.title = "Resolution"
        resCol.width = 300
        resolutionTable.addTableColumn(resCol)

        let rateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rate"))
        rateCol.title = "Refresh Rate"
        rateCol.width = 200
        resolutionTable.addTableColumn(rateCol)

        resolutionTable.delegate = self
        resolutionTable.dataSource = self
        resolutionTable.rowHeight = 22
        resolutionTable.usesAlternatingRowBackgroundColors = true

        resolutionScrollView.documentView = resolutionTable
        resolutionScrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        resolutionScrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true

        // Start hidden (Default radio selected)
        resolutionScrollView.isHidden = true
        resStack.addArrangedSubview(resolutionScrollView)

        resBox.contentView = resStack
        outerStack.addArrangedSubview(resBox)
        resBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Current resolution info
        // =====================================================================
        currentResLabel.font = SnowLeopardFonts.label(size: 10)
        currentResLabel.textColor = .secondaryLabelColor
        outerStack.addArrangedSubview(currentResLabel)

        // Default radio selected initially
        defaultRadio.isSelected = true
        scaledRadio.isSelected = false

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
        // Brightness
        let currentBrightness = readBrightness()
        brightnessSlider.doubleValue = Double(currentBrightness)
        if currentBrightness < 0 {
            brightnessSlider.isEnabled = false
            autoBrightnessCheck.isEnabled = false
        }

        let mainDisplay = CGMainDisplayID()

        // Current mode
        if let currentMode = CGDisplayCopyDisplayMode(mainDisplay) {
            let w = currentMode.pixelWidth
            let h = currentMode.pixelHeight
            let lw = currentMode.width
            let lh = currentMode.height
            let rate = currentMode.refreshRate
            currentResLabel.stringValue = "Current: \(lw) x \(lh) (\(w) x \(h) pixels) @ \(Int(rate)) Hz"
        }

        // Available modes
        displayModes.removeAll()
        if let modes = CGDisplayCopyAllDisplayModes(mainDisplay, nil) as? [CGDisplayMode] {
            var seen = Set<String>()
            for mode in modes {
                let key = "\(mode.width)x\(mode.height)"
                if seen.insert(key).inserted {
                    displayModes.append((width: mode.width, height: mode.height, refreshRate: mode.refreshRate))
                }
            }
            displayModes.sort { ($0.width * $0.height) > ($1.width * $1.height) }
        }
        resolutionTable.reloadData()
    }

    // MARK: - Actions

    @objc private func brightnessChanged(_ sender: AquaSlider) {
        setBrightness(Float(sender.doubleValue))
    }

    @objc private func autoBrightnessChanged(_ sender: AquaCheckbox) {
        // Auto-brightness is a private API; just store the preference
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.BezelServices", "dAuto", "-bool", sender.isChecked ? "YES" : "NO"]
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    private func readBrightness() -> Float {
        // Use ioreg to read brightness
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-c", "AppleBacklightDisplay", "-r", "-d", "1"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8),
           let range = output.range(of: "\"brightness\"\\s*=\\s*\\{[^}]*\"value\"\\s*=\\s*(\\d+)", options: .regularExpression) {
            let match = String(output[range])
            if let numRange = match.range(of: "\\d+$", options: .regularExpression) {
                let numStr = String(match[numRange])
                if let val = Float(numStr) {
                    return val / 1024.0
                }
            }
        }
        // Fallback: try CoreGraphics private function via process
        return 0.5
    }

    private func setBrightness(_ value: Float) {
        // Use AppleScript for brightness (works on built-in displays)
        let percent = Int(value * 100)
        let source = """
        tell application "System Events"
            tell appearance preferences
                -- no-op fallback
            end tell
        end tell
        do shell script "brightness \(String(format: "%.2f", value))"
        """
        // More reliable: use the brightness command if installed, else try IOKit
        // Simple approach: write via private CoreDisplay function
        typealias CDSFunc = @convention(c) (UInt32, Float) -> Void
        if let handle = dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY),
           let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") {
            let fn = unsafeBitCast(sym, to: CDSFunc.self)
            fn(CGMainDisplayID(), value)
            dlclose(handle)
            return
        }
        // Fallback: try via osascript
        let _ = source // suppress unused warning
        let _ = percent // suppress unused warning
    }

    @objc private func resolutionModeChanged(_ sender: AquaRadioButton) {
        if sender === defaultRadio {
            scaledRadio.isSelected = false
            resolutionScrollView.isHidden = true
        } else {
            defaultRadio.isSelected = false
            resolutionScrollView.isHidden = false
        }
    }
}

// MARK: - Table Data Source & Delegate

extension DisplaysPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayModes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let mode = displayModes[row]
        if tableColumn?.identifier.rawValue == "resolution" {
            let cell = NSTextField(labelWithString: "\(mode.width) x \(mode.height)")
            cell.font = SnowLeopardFonts.label(size: 12)
            return cell
        } else {
            let cell = NSTextField(labelWithString: "\(Int(mode.refreshRate)) Hz")
            cell.font = SnowLeopardFonts.label(size: 12)
            cell.textColor = .secondaryLabelColor
            return cell
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }

        let mode = displayModes[row]
        let mainDisplay = CGMainDisplayID()

        // Find matching CGDisplayMode and apply
        if let modes = CGDisplayCopyAllDisplayModes(mainDisplay, nil) as? [CGDisplayMode] {
            if let matching = modes.first(where: { $0.width == mode.width && $0.height == mode.height }) {
                var config: CGDisplayConfigRef?
                CGBeginDisplayConfiguration(&config)
                CGConfigureDisplayWithDisplayMode(config, mainDisplay, matching, nil)
                CGCompleteDisplayConfiguration(config, .forSession)
            }
        }
    }
}
