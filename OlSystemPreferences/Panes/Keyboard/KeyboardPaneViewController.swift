import Cocoa

class KeyboardPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "keyboard" }
    var paneTitle: String { "Keyboard" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 500) }
    var searchKeywords: [String] { ["keyboard", "key repeat", "delay", "autocorrect", "capitalize", "smart quotes"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Keyboard-Settings.extension" }

    // MARK: - Services

    private let defaults = DefaultsService.shared

    // MARK: - Tabs

    private let tabView = AquaTabView()

    // Keyboard tab controls
    private let keyRepeatSlider = AquaSlider(minValue: 1, maxValue: 120, value: 2)
    private let delaySlider = AquaSlider(minValue: 10, maxValue: 120, value: 25)
    private let testField = NSTextField()
    private let fnKeysCheck = AquaCheckbox(title: "Use F1, F2, etc. keys as standard function keys", isChecked: false)

    // Text tab controls
    private let autocorrectCheck = AquaCheckbox(title: "Correct spelling automatically", isChecked: false)
    private let capitalizeCheck = AquaCheckbox(title: "Capitalize words automatically", isChecked: false)
    private let periodCheck = AquaCheckbox(title: "Add period with double-space", isChecked: false)
    private let smartQuotesCheck = AquaCheckbox(title: "Use smart quotes and dashes", isChecked: false)
    private let smartDashesCheck = AquaCheckbox(title: "Use smart dashes", isChecked: false)

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
        tabView.addTab(title: "Keyboard", view: buildKeyboardTab())
        tabView.addTab(title: "Text", view: buildTextTab())

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

    // MARK: - Keyboard Tab

    private func buildKeyboardTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // Key Repeat Rate section
        let repeatBox = SnowLeopardPaneHelper.makeSectionBox(title: "Key Repeat Rate")
        let repeatStack = NSStackView()
        repeatStack.translatesAutoresizingMaskIntoConstraints = false
        repeatStack.orientation = .vertical
        repeatStack.alignment = .leading
        repeatStack.spacing = 8
        repeatStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        keyRepeatSlider.target = self
        keyRepeatSlider.action = #selector(keyRepeatChanged(_:))
        keyRepeatSlider.isContinuous = false
        keyRepeatSlider.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let slowLabel = SnowLeopardPaneHelper.makeLabel("Slow", size: 10)
        let fastLabel = SnowLeopardPaneHelper.makeLabel("Fast", size: 10)

        let repeatRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Key Repeat:"),
            controls: [slowLabel, keyRepeatSlider, fastLabel],
            spacing: 6
        )
        repeatStack.addArrangedSubview(repeatRow)
        repeatBox.contentView = repeatStack
        stack.addArrangedSubview(repeatBox)
        repeatBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        // Delay Until Repeat section
        let delayBox = SnowLeopardPaneHelper.makeSectionBox(title: "Delay Until Repeat")
        let delayStack = NSStackView()
        delayStack.translatesAutoresizingMaskIntoConstraints = false
        delayStack.orientation = .vertical
        delayStack.alignment = .leading
        delayStack.spacing = 8
        delayStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        delaySlider.target = self
        delaySlider.action = #selector(delayChanged(_:))
        delaySlider.isContinuous = false
        delaySlider.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let longLabel = SnowLeopardPaneHelper.makeLabel("Long", size: 10)
        let shortLabel = SnowLeopardPaneHelper.makeLabel("Short", size: 10)

        let delayRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Delay:"),
            controls: [longLabel, delaySlider, shortLabel],
            spacing: 6
        )
        delayStack.addArrangedSubview(delayRow)
        delayBox.contentView = delayStack
        stack.addArrangedSubview(delayBox)
        delayBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        // Test field
        testField.translatesAutoresizingMaskIntoConstraints = false
        testField.font = SnowLeopardFonts.label(size: 12)
        testField.placeholderString = "Type here to test key repeat"
        testField.isBordered = true
        testField.isBezeled = true
        testField.bezelStyle = .roundedBezel
        testField.isEditable = true
        testField.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let testRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [testField]
        )
        stack.addArrangedSubview(testRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Function keys toggle
        fnKeysCheck.target = self
        fnKeysCheck.action = #selector(fnKeysChanged(_:))

        let fnRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [fnKeysCheck]
        )
        stack.addArrangedSubview(fnRow)

        let fnInfoLabel = SnowLeopardPaneHelper.makeLabel(
            "When this option is selected, press the Fn key to use the special features printed on each key.",
            size: 10
        )
        fnInfoLabel.textColor = .secondaryLabelColor
        fnInfoLabel.maximumNumberOfLines = 2
        fnInfoLabel.preferredMaxLayoutWidth = 440
        stack.addArrangedSubview(fnInfoLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Text Tab

    private func buildTextTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // Text correction section
        let correctionBox = SnowLeopardPaneHelper.makeSectionBox(title: "Spelling & Text")
        let corrStack = NSStackView()
        corrStack.translatesAutoresizingMaskIntoConstraints = false
        corrStack.orientation = .vertical
        corrStack.alignment = .leading
        corrStack.spacing = 6
        corrStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let allChecks: [(AquaCheckbox, String)] = [
            (autocorrectCheck, "autocorrect"),
            (capitalizeCheck, "capitalize"),
            (periodCheck, "period"),
            (smartQuotesCheck, "quotes"),
            (smartDashesCheck, "dashes"),
        ]
        for (check, _) in allChecks {
            check.target = self
            check.action = #selector(textOptionChanged(_:))

            let row = SnowLeopardPaneHelper.makeRow(
                label: SnowLeopardPaneHelper.makeLabel(""),
                controls: [check]
            )
            corrStack.addArrangedSubview(row)
        }

        correctionBox.contentView = corrStack
        stack.addArrangedSubview(correctionBox)
        correctionBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

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
        // Key repeat: lower value = faster. Invert for slider so right = fast
        let repeatRate = defaults.integer(forKey: "KeyRepeat") ?? 2
        keyRepeatSlider.doubleValue = Double(121 - repeatRate)

        let initialRepeat = defaults.integer(forKey: "InitialKeyRepeat") ?? 25
        delaySlider.doubleValue = Double(121 - initialRepeat)

        // Function keys toggle
        let fnState = defaults.bool(forKey: "com.apple.keyboard.fnState") ?? false
        fnKeysCheck.isChecked = fnState

        autocorrectCheck.isChecked = defaults.bool(forKey: "NSAutomaticSpellingCorrectionEnabled") ?? false
        capitalizeCheck.isChecked = defaults.bool(forKey: "NSAutomaticCapitalizationEnabled") ?? true
        periodCheck.isChecked = defaults.bool(forKey: "NSAutomaticPeriodSubstitutionEnabled") ?? true
        smartQuotesCheck.isChecked = defaults.bool(forKey: "NSAutomaticQuoteSubstitutionEnabled") ?? true
        smartDashesCheck.isChecked = defaults.bool(forKey: "NSAutomaticDashSubstitutionEnabled") ?? true
    }

    // MARK: - Actions

    @objc private func keyRepeatChanged(_ sender: AquaSlider) {
        let value = 121 - Int(sender.doubleValue)
        defaults.setInteger(max(1, value), forKey: "KeyRepeat")
    }

    @objc private func delayChanged(_ sender: AquaSlider) {
        let value = 121 - Int(sender.doubleValue)
        defaults.setInteger(max(10, value), forKey: "InitialKeyRepeat")
    }

    @objc private func fnKeysChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "com.apple.keyboard.fnState")
    }

    @objc private func textOptionChanged(_ sender: AquaCheckbox) {
        let on = sender.isChecked
        switch sender {
        case autocorrectCheck:
            defaults.setBool(on, forKey: "NSAutomaticSpellingCorrectionEnabled")
        case capitalizeCheck:
            defaults.setBool(on, forKey: "NSAutomaticCapitalizationEnabled")
        case periodCheck:
            defaults.setBool(on, forKey: "NSAutomaticPeriodSubstitutionEnabled")
        case smartQuotesCheck:
            defaults.setBool(on, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        case smartDashesCheck:
            defaults.setBool(on, forKey: "NSAutomaticDashSubstitutionEnabled")
        default:
            break
        }
    }
}
