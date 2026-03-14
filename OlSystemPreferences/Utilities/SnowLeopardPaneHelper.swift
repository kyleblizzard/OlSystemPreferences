import Cocoa

enum SnowLeopardPaneHelper {

    /// Creates the standard pane container with icon, title, and Jump to Settings button
    static func makePaneHeader(icon: NSImage, title: String, settingsURL: String) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Icon (32x32)
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = SnowLeopardFonts.boldLabel(size: 13)
        titleLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        container.addSubview(titleLabel)

        // Jump to Settings button
        let jumpButton = SnowLeopardJumpButton(settingsURL: settingsURL)
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(jumpButton)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 40),

            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            jumpButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            jumpButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }

    /// Snow Leopard style section box (grouped appearance)
    static func makeSectionBox(title: String? = nil) -> NSBox {
        let box = NSBox()
        box.boxType = .primary
        box.titlePosition = title != nil ? .atTop : .noTitle
        if let title = title {
            box.title = title
            box.titleFont = SnowLeopardFonts.boldLabel(size: 11)
        }
        box.contentViewMargins = NSSize(width: 12, height: 10)
        box.translatesAutoresizingMaskIntoConstraints = false
        return box
    }

    /// Standard separator
    static func makeSeparator(width: CGFloat = 580) -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.widthAnchor.constraint(equalToConstant: width).isActive = true
        return sep
    }

    /// Standard label with Lucida Grande
    static func makeLabel(_ text: String, size: CGFloat = 11, bold: Bool = false) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = bold ? SnowLeopardFonts.boldLabel(size: size) : SnowLeopardFonts.label(size: size)
        label.textColor = NSColor(white: 0.15, alpha: 1.0)
        return label
    }

    /// Standard label-control row
    static func makeRow(label: NSTextField, controls: [NSView], spacing: CGFloat = 12) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = spacing
        row.alignment = .firstBaseline
        label.font = SnowLeopardFonts.label(size: 11)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.alignment = .right
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        row.addArrangedSubview(label)
        for control in controls {
            row.addArrangedSubview(control)
        }
        return row
    }

    /// Apply Lucida Grande font to standard controls
    static func styleControl(_ control: NSControl, size: CGFloat = 11) {
        control.font = SnowLeopardFonts.label(size: size)
    }

    static func styleControls(_ controls: [NSControl], size: CGFloat = 11) {
        controls.forEach { styleControl($0, size: size) }
    }

    // MARK: - Aqua Control Factory Methods

    static func makeAquaCheckbox(title: String, isChecked: Bool = false, target: AnyObject? = nil, action: Selector? = nil) -> AquaCheckbox {
        let cb = AquaCheckbox(title: title, isChecked: isChecked)
        cb.target = target
        cb.action = action
        return cb
    }

    static func makeAquaRadio(title: String, isSelected: Bool = false, groupTag: Int = 0, target: AnyObject? = nil, action: Selector? = nil) -> AquaRadioButton {
        let radio = AquaRadioButton(title: title, isSelected: isSelected)
        radio.groupTag = groupTag
        radio.target = target
        radio.action = action
        return radio
    }

    static func makeAquaSlider(min: Double = 0, max: Double = 1, value: Double = 0.5, target: AnyObject? = nil, action: Selector? = nil) -> AquaSlider {
        let slider = AquaSlider(minValue: min, maxValue: max, value: value)
        slider.target = target
        slider.action = action
        return slider
    }

    static func makeAquaPopup(items: [String], selected: Int = 0, target: AnyObject? = nil, action: Selector? = nil) -> AquaPopUpButton {
        let popup = AquaPopUpButton(items: items, selectedIndex: selected)
        popup.target = target
        popup.action = action
        return popup
    }

    static func makeAquaButton(title: String, isDefault: Bool = false, target: AnyObject? = nil, action: Selector? = nil) -> AquaButton {
        let btn = AquaButton(title: title, isDefault: isDefault)
        btn.target = target
        btn.action = action
        return btn
    }

    static func makeAquaSegmented(segments: [String], selected: Int = 0, target: AnyObject? = nil, action: Selector? = nil) -> AquaSegmentedControl {
        let seg = AquaSegmentedControl(segments: segments, selectedSegment: selected)
        seg.target = target
        seg.action = action
        return seg
    }

    static func makeAquaTabView() -> AquaTabView {
        return AquaTabView()
    }

    /// Creates a standard outer stack view with proper Snow Leopard pane margins.
    static func makePaneContainer() -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        return stack
    }
}

// MARK: - System Settings Launcher

/// Opens System Settings to a specific pane and positions its window to the right of the app.
enum SystemSettingsLauncher {

    static func open(url settingsURL: String) {
        guard !settingsURL.isEmpty,
              let url = URL(string: "x-apple.systempreferences:\(settingsURL)") else { return }
        NSWorkspace.shared.open(url)
        positionSettingsWindow()
    }

    private static func positionSettingsWindow() {
        guard let appWindow = NSApp.mainWindow ?? NSApp.windows.first,
              let screen = appWindow.screen ?? NSScreen.main else { return }

        let rightEdge = appWindow.frame.maxX
        let windowTop = appWindow.frame.maxY
        let screenHeight = screen.frame.height

        // AppleScript uses top-left screen origin
        let x = Int(rightEdge + 12)
        let y = Int(screenHeight - windowTop)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let source = """
            tell application "System Settings"
                try
                    set position of window 1 to {\(x), \(y)}
                end try
            end tell
            """
            if let script = NSAppleScript(source: source) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
}

/// "Open in System Settings" button
class SnowLeopardJumpButton: NSButton {
    private let settingsURL: String

    init(settingsURL: String) {
        self.settingsURL = settingsURL
        super.init(frame: .zero)
        title = "Open in System Settings..."
        bezelStyle = .rounded
        font = SnowLeopardFonts.label(size: 10)
        target = self
        action = #selector(jumpToSettings)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func jumpToSettings() {
        SystemSettingsLauncher.open(url: settingsURL)
    }
}
