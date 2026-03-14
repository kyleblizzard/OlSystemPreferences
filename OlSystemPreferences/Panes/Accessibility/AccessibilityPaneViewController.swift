import Cocoa

class AccessibilityPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "accessibility" }
    var paneTitle: String { "Universal Access" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "accessibility", accessibilityDescription: "Universal Access") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 480) }
    var searchKeywords: [String] { ["accessibility", "universal access", "voiceover", "zoom", "hearing", "sticky keys", "slow keys", "mouse keys", "cursor size", "flash screen"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Accessibility-Settings.extension" }

    // MARK: - Data

    private let defaults = DefaultsService.shared

    // Seeing tab
    private let voiceOverStatusLabel = NSTextField(labelWithString: "")
    private let voiceOverDot = NSView()
    private let zoomCheck = NSButton(checkboxWithTitle: "Turn on Zoom", target: nil, action: nil)
    private let cursorSizeLabel = NSTextField(labelWithString: "")
    private let cursorSizeSlider = NSSlider(value: 1, minValue: 1, maxValue: 4, target: nil, action: nil)

    // Hearing tab
    private let flashScreenCheck = NSButton(checkboxWithTitle: "Flash the screen when an alert sound occurs", target: nil, action: nil)
    private let audioMonoCheck = NSButton(checkboxWithTitle: "Play stereo audio as mono", target: nil, action: nil)

    // Keyboard tab
    private let stickyKeysCheck = NSButton(checkboxWithTitle: "Enable Sticky Keys", target: nil, action: nil)
    private let slowKeysCheck = NSButton(checkboxWithTitle: "Enable Slow Keys", target: nil, action: nil)

    // Mouse & Trackpad tab
    private let mouseKeysCheck = NSButton(checkboxWithTitle: "Enable Mouse Keys", target: nil, action: nil)
    private let mouseKeysInfo = NSTextField(labelWithString: "")

    // Tab view
    private let tabView = NSTabView()

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

        // --- Tab View ---
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder
        tabView.font = SnowLeopardFonts.label(size: 11)

        // Tab 1: Seeing
        let seeingTab = NSTabViewItem(identifier: "seeing")
        seeingTab.label = "Seeing"
        seeingTab.view = buildSeeingTab()

        // Tab 2: Hearing
        let hearingTab = NSTabViewItem(identifier: "hearing")
        hearingTab.label = "Hearing"
        hearingTab.view = buildHearingTab()

        // Tab 3: Keyboard
        let keyboardTab = NSTabViewItem(identifier: "keyboard")
        keyboardTab.label = "Keyboard"
        keyboardTab.view = buildKeyboardTab()

        // Tab 4: Mouse & Trackpad
        let mouseTab = NSTabViewItem(identifier: "mouse")
        mouseTab.label = "Mouse & Trackpad"
        mouseTab.view = buildMouseTab()

        tabView.addTabViewItem(seeingTab)
        tabView.addTabViewItem(hearingTab)
        tabView.addTabViewItem(keyboardTab)
        tabView.addTabViewItem(mouseTab)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Seeing Tab

    private func buildSeeingTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // VoiceOver section
        let voLabel = SnowLeopardPaneHelper.makeLabel("VoiceOver:", size: 11, bold: true)
        stack.addArrangedSubview(voLabel)

        // VoiceOver status row with dot
        voiceOverDot.translatesAutoresizingMaskIntoConstraints = false
        voiceOverDot.wantsLayer = true
        voiceOverDot.layer?.cornerRadius = 5
        voiceOverDot.layer?.backgroundColor = NSColor.systemGray.cgColor
        voiceOverDot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        voiceOverDot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        voiceOverStatusLabel.font = SnowLeopardFonts.label(size: 11)
        voiceOverStatusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let voStatusRow = NSStackView(views: [voiceOverDot, voiceOverStatusLabel])
        voStatusRow.orientation = .horizontal
        voStatusRow.spacing = 6
        voStatusRow.alignment = .centerY
        stack.addArrangedSubview(voStatusRow)

        let voExplain = SnowLeopardPaneHelper.makeLabel(
            "VoiceOver speaks items on the screen aloud. Press Command-F5 to turn VoiceOver on or off.",
            size: 10
        )
        voExplain.textColor = .secondaryLabelColor
        voExplain.maximumNumberOfLines = 2
        voExplain.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(voExplain)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Zoom section
        let zoomLabel = SnowLeopardPaneHelper.makeLabel("Zoom:", size: 11, bold: true)
        stack.addArrangedSubview(zoomLabel)

        zoomCheck.target = self
        zoomCheck.action = #selector(zoomToggled(_:))
        SnowLeopardPaneHelper.styleControl(zoomCheck)

        let zoomRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [zoomCheck]
        )
        stack.addArrangedSubview(zoomRow)

        let zoomExplain = SnowLeopardPaneHelper.makeLabel(
            "Use scroll gesture with modifier keys to zoom. Configure in System Settings.",
            size: 10
        )
        zoomExplain.textColor = .secondaryLabelColor
        zoomExplain.maximumNumberOfLines = 2
        zoomExplain.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(zoomExplain)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Cursor size
        let cursorLabel = SnowLeopardPaneHelper.makeLabel("Display:", size: 11, bold: true)
        stack.addArrangedSubview(cursorLabel)

        cursorSizeSlider.numberOfTickMarks = 7
        cursorSizeSlider.allowsTickMarkValuesOnly = true
        cursorSizeSlider.isContinuous = true
        cursorSizeSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        cursorSizeSlider.target = self
        cursorSizeSlider.action = #selector(cursorSizeChanged(_:))
        SnowLeopardPaneHelper.styleControl(cursorSizeSlider)

        cursorSizeLabel.font = SnowLeopardFonts.label(size: 10)
        cursorSizeLabel.textColor = .secondaryLabelColor

        let cursorRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Cursor size:"),
            controls: [
                SnowLeopardPaneHelper.makeLabel("Normal", size: 10),
                cursorSizeSlider,
                SnowLeopardPaneHelper.makeLabel("Large", size: 10),
            ],
            spacing: 4
        )
        stack.addArrangedSubview(cursorRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Hearing Tab

    private func buildHearingTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let title = SnowLeopardPaneHelper.makeLabel("Audio:", size: 11, bold: true)
        stack.addArrangedSubview(title)

        // Flash screen checkbox
        flashScreenCheck.target = self
        flashScreenCheck.action = #selector(flashScreenToggled(_:))
        SnowLeopardPaneHelper.styleControl(flashScreenCheck)

        let flashRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [flashScreenCheck]
        )
        stack.addArrangedSubview(flashRow)

        // Test flash button
        let testFlashButton = NSButton(title: "Flash Screen", target: self, action: #selector(testFlash))
        testFlashButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(testFlashButton, size: 11)

        let testRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [testFlashButton]
        )
        stack.addArrangedSubview(testRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Audio mono
        audioMonoCheck.target = self
        audioMonoCheck.action = #selector(monoAudioToggled(_:))
        SnowLeopardPaneHelper.styleControl(audioMonoCheck)

        let monoRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [audioMonoCheck]
        )
        stack.addArrangedSubview(monoRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Info text
        let info = SnowLeopardPaneHelper.makeLabel(
            "Additional hearing accessibility options including closed captions and audio descriptions can be configured in System Settings.",
            size: 10
        )
        info.textColor = .secondaryLabelColor
        info.maximumNumberOfLines = 3
        info.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(info)

        let openButton = NSButton(title: "Open in System Settings...", target: self, action: #selector(openAccessibilitySettings))
        openButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(openButton, size: 11)

        let openRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [openButton]
        )
        stack.addArrangedSubview(openRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Keyboard Tab

    private func buildKeyboardTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Sticky Keys section
        let stickyTitle = SnowLeopardPaneHelper.makeLabel("Sticky Keys:", size: 11, bold: true)
        stack.addArrangedSubview(stickyTitle)

        stickyKeysCheck.target = self
        stickyKeysCheck.action = #selector(stickyKeysToggled(_:))
        SnowLeopardPaneHelper.styleControl(stickyKeysCheck)

        let stickyRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [stickyKeysCheck]
        )
        stack.addArrangedSubview(stickyRow)

        let stickyExplain = SnowLeopardPaneHelper.makeLabel(
            "Sticky Keys allows modifier keys to be set without having to hold the key down. Press a modifier key (Shift, Command, Option, Control) to set it.",
            size: 10
        )
        stickyExplain.textColor = .secondaryLabelColor
        stickyExplain.maximumNumberOfLines = 3
        stickyExplain.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(stickyExplain)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Slow Keys section
        let slowTitle = SnowLeopardPaneHelper.makeLabel("Slow Keys:", size: 11, bold: true)
        stack.addArrangedSubview(slowTitle)

        slowKeysCheck.target = self
        slowKeysCheck.action = #selector(slowKeysToggled(_:))
        SnowLeopardPaneHelper.styleControl(slowKeysCheck)

        let slowRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [slowKeysCheck]
        )
        stack.addArrangedSubview(slowRow)

        let slowExplain = SnowLeopardPaneHelper.makeLabel(
            "Slow Keys adjusts the amount of time between when a key is pressed and when it is activated. This can help if you inadvertently press keys.",
            size: 10
        )
        slowExplain.textColor = .secondaryLabelColor
        slowExplain.maximumNumberOfLines = 3
        slowExplain.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(slowExplain)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Info
        let info = SnowLeopardPaneHelper.makeLabel(
            "Additional keyboard accessibility options can be configured in System Settings.",
            size: 10
        )
        info.textColor = .secondaryLabelColor
        info.maximumNumberOfLines = 2
        info.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(info)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Mouse & Trackpad Tab

    private func buildMouseTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Mouse Keys section
        let mouseKeysTitle = SnowLeopardPaneHelper.makeLabel("Mouse Keys:", size: 11, bold: true)
        stack.addArrangedSubview(mouseKeysTitle)

        mouseKeysCheck.target = self
        mouseKeysCheck.action = #selector(mouseKeysToggled(_:))
        SnowLeopardPaneHelper.styleControl(mouseKeysCheck)

        let mouseKeysRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [mouseKeysCheck]
        )
        stack.addArrangedSubview(mouseKeysRow)

        let mouseKeysExplain = SnowLeopardPaneHelper.makeLabel(
            "Mouse Keys allows you to use the keyboard in place of the mouse. When Mouse Keys is on, use the numeric keypad keys to move the mouse pointer.",
            size: 10
        )
        mouseKeysExplain.textColor = .secondaryLabelColor
        mouseKeysExplain.maximumNumberOfLines = 3
        mouseKeysExplain.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(mouseKeysExplain)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Mouse Keys status info
        mouseKeysInfo.font = SnowLeopardFonts.label(size: 11)
        mouseKeysInfo.textColor = NSColor(white: 0.15, alpha: 1.0)
        mouseKeysInfo.maximumNumberOfLines = 2
        mouseKeysInfo.preferredMaxLayoutWidth = 540

        let infoRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Status:"),
            controls: [mouseKeysInfo]
        )
        stack.addArrangedSubview(infoRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Info
        let info = SnowLeopardPaneHelper.makeLabel(
            "Additional pointer control and alternative input options can be configured in System Settings.",
            size: 10
        )
        info.textColor = .secondaryLabelColor
        info.maximumNumberOfLines = 2
        info.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(info)

        let openButton = NSButton(title: "Open in System Settings...", target: self, action: #selector(openAccessibilitySettings))
        openButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(openButton, size: 11)

        let openRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [openButton]
        )
        stack.addArrangedSubview(openRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        // VoiceOver status - check if VoiceOver process is running
        let voiceOverRunning = isProcessRunning("VoiceOver")
        if voiceOverRunning {
            voiceOverDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            voiceOverStatusLabel.stringValue = "VoiceOver is on"
        } else {
            voiceOverDot.layer?.backgroundColor = NSColor.systemGray.cgColor
            voiceOverStatusLabel.stringValue = "VoiceOver is off"
        }

        // Zoom
        let zoomEnabled = defaults.bool(forKey: "closeViewScrollWheelToggle", domain: "com.apple.universalaccess") ?? false
        zoomCheck.state = zoomEnabled ? .on : .off

        // Cursor size
        let cursorSize = defaults.double(forKey: "mouseDriverCursorSize", domain: "com.apple.universalaccess") ?? 1.0
        cursorSizeSlider.doubleValue = cursorSize

        // Flash screen
        let flashScreen = defaults.bool(forKey: "flashScreen", domain: "com.apple.universalaccess") ?? false
        flashScreenCheck.state = flashScreen ? .on : .off

        // Audio mono
        let monoAudio = defaults.bool(forKey: "stereoAsMono", domain: "com.apple.universalaccess") ?? false
        audioMonoCheck.state = monoAudio ? .on : .off

        // Sticky keys
        let stickyKeys = defaults.bool(forKey: "stickyKey", domain: "com.apple.universalaccess") ?? false
        stickyKeysCheck.state = stickyKeys ? .on : .off

        // Slow keys
        let slowKeys = defaults.bool(forKey: "slowKey", domain: "com.apple.universalaccess") ?? false
        slowKeysCheck.state = slowKeys ? .on : .off

        // Mouse keys
        let mouseKeys = defaults.bool(forKey: "mouseDriver", domain: "com.apple.universalaccess") ?? false
        mouseKeysCheck.state = mouseKeys ? .on : .off
        mouseKeysInfo.stringValue = mouseKeys
            ? "Mouse Keys is enabled. Use the numeric keypad to control the pointer."
            : "Mouse Keys is disabled."
    }

    // MARK: - Helpers

    private func isProcessRunning(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-x", name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Actions

    @objc private func zoomToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "closeViewScrollWheelToggle", domain: "com.apple.universalaccess")
    }

    @objc private func cursorSizeChanged(_ sender: NSSlider) {
        defaults.setDouble(sender.doubleValue, forKey: "mouseDriverCursorSize", domain: "com.apple.universalaccess")
    }

    @objc private func flashScreenToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "flashScreen", domain: "com.apple.universalaccess")
    }

    @objc private func monoAudioToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "stereoAsMono", domain: "com.apple.universalaccess")
    }

    @objc private func stickyKeysToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "stickyKey", domain: "com.apple.universalaccess")
    }

    @objc private func slowKeysToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "slowKey", domain: "com.apple.universalaccess")
    }

    @objc private func mouseKeysToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "mouseDriver", domain: "com.apple.universalaccess")
        mouseKeysInfo.stringValue = enabled
            ? "Mouse Keys is enabled. Use the numeric keypad to control the pointer."
            : "Mouse Keys is disabled."
    }

    @objc private func testFlash() {
        // Flash the screen briefly to demonstrate the feature
        guard let screen = NSScreen.main else { return }
        let flashView = NSView(frame: screen.frame)
        flashView.wantsLayer = true
        flashView.layer?.backgroundColor = NSColor.white.cgColor

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.backgroundColor = .white
        window.alphaValue = 0.7
        window.contentView = flashView
        window.orderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            window.orderOut(nil)
        }
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:\(settingsURL)") else { return }
        NSWorkspace.shared.open(url)
    }
}
