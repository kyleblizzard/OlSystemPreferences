import Cocoa

// MARK: - Shortcut Data Model

private struct ShortcutEntry {
    let name: String
    let key: String
    var isEnabled: Bool
}

private struct ShortcutCategory {
    let name: String
    var shortcuts: [ShortcutEntry]
}

class KeyboardPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "keyboard" }
    var paneTitle: String { "Keyboard" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 500) }
    var searchKeywords: [String] { ["keyboard", "key repeat", "delay", "autocorrect", "capitalize", "smart quotes", "shortcuts", "modifier keys"] }
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

    // Keyboard Shortcuts tab controls
    private let categoryTableView = NSTableView()
    private let shortcutsTableView = NSTableView()
    private var shortcutCategories: [ShortcutCategory] = []
    private var selectedCategoryIndex: Int = 0

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
        tabView.addTab(title: "Keyboard Shortcuts", view: buildKeyboardShortcutsTab())

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

        // Modifier Keys... button
        let modifierKeysButton = SnowLeopardPaneHelper.makeAquaButton(
            title: "Modifier Keys...",
            target: self,
            action: #selector(modifierKeysPressed(_:))
        )
        let modifierRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [modifierKeysButton]
        )
        stack.addArrangedSubview(modifierRow)

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

    // MARK: - Keyboard Shortcuts Tab

    private func buildKeyboardShortcutsTab() -> NSView {
        populateShortcutCategories()

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Split view: left category list, right shortcuts list
        let splitContainer = NSView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(splitContainer)

        NSLayoutConstraint.activate([
            splitContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            splitContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            splitContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            splitContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])

        // --- Left sidebar: category list ---
        let categoryColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CategoryColumn"))
        categoryColumn.title = "Categories"
        categoryColumn.width = 170
        categoryColumn.minWidth = 140
        categoryTableView.addTableColumn(categoryColumn)
        categoryTableView.headerView = nil
        categoryTableView.delegate = self
        categoryTableView.dataSource = self
        categoryTableView.rowHeight = 20
        categoryTableView.font = SnowLeopardFonts.label(size: 11)
        categoryTableView.selectionHighlightStyle = .sourceList
        categoryTableView.tag = 1

        let categoryScroll = NSScrollView()
        categoryScroll.translatesAutoresizingMaskIntoConstraints = false
        categoryScroll.documentView = categoryTableView
        categoryScroll.hasVerticalScroller = true
        categoryScroll.borderType = .bezelBorder
        splitContainer.addSubview(categoryScroll)

        // --- Right area: shortcuts table ---
        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("EnabledColumn"))
        enabledColumn.title = ""
        enabledColumn.width = 24
        enabledColumn.minWidth = 24
        enabledColumn.maxWidth = 24
        shortcutsTableView.addTableColumn(enabledColumn)

        let shortcutNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ShortcutColumn"))
        shortcutNameColumn.title = "Shortcut"
        shortcutNameColumn.width = 260
        shortcutNameColumn.minWidth = 150
        shortcutsTableView.addTableColumn(shortcutNameColumn)

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("KeyColumn"))
        keyColumn.title = "Key"
        keyColumn.width = 120
        keyColumn.minWidth = 80
        shortcutsTableView.addTableColumn(keyColumn)

        shortcutsTableView.delegate = self
        shortcutsTableView.dataSource = self
        shortcutsTableView.rowHeight = 20
        shortcutsTableView.font = SnowLeopardFonts.label(size: 11)
        shortcutsTableView.usesAlternatingRowBackgroundColors = true
        shortcutsTableView.tag = 2

        let shortcutsScroll = NSScrollView()
        shortcutsScroll.translatesAutoresizingMaskIntoConstraints = false
        shortcutsScroll.documentView = shortcutsTableView
        shortcutsScroll.hasVerticalScroller = true
        shortcutsScroll.borderType = .bezelBorder
        splitContainer.addSubview(shortcutsScroll)

        // Layout: left sidebar ~170pt, right takes the rest
        NSLayoutConstraint.activate([
            categoryScroll.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            categoryScroll.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor),
            categoryScroll.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
            categoryScroll.widthAnchor.constraint(equalToConstant: 170),

            shortcutsScroll.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            shortcutsScroll.leadingAnchor.constraint(equalTo: categoryScroll.trailingAnchor, constant: 8),
            shortcutsScroll.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor),
            shortcutsScroll.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),

            splitContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
        ])

        // Select first category by default
        DispatchQueue.main.async { [weak self] in
            self?.categoryTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        return container
    }

    // MARK: - Shortcut Data

    private func populateShortcutCategories() {
        shortcutCategories = [
            ShortcutCategory(name: "Dashboard & Dock", shortcuts: [
                ShortcutEntry(name: "Turn Hiding On/Off", key: "\u{2325}\u{2318}D", isEnabled: true),
                ShortcutEntry(name: "Show Dashboard", key: "F12", isEnabled: true),
            ]),
            ShortcutCategory(name: "Expose\u{0301} & Spaces", shortcuts: [
                ShortcutEntry(name: "All Windows", key: "F9", isEnabled: true),
                ShortcutEntry(name: "Application Windows", key: "F10", isEnabled: true),
                ShortcutEntry(name: "Show Desktop", key: "F11", isEnabled: true),
                ShortcutEntry(name: "Show Spaces", key: "F8", isEnabled: true),
                ShortcutEntry(name: "Move Left a Space", key: "\u{2303}\u{2190}", isEnabled: true),
                ShortcutEntry(name: "Move Right a Space", key: "\u{2303}\u{2192}", isEnabled: true),
            ]),
            ShortcutCategory(name: "Spotlight", shortcuts: [
                ShortcutEntry(name: "Show Spotlight Search", key: "\u{2318}Space", isEnabled: true),
                ShortcutEntry(name: "Show Spotlight Window", key: "\u{2325}\u{2318}Space", isEnabled: true),
            ]),
            ShortcutCategory(name: "Universal Access", shortcuts: [
                ShortcutEntry(name: "Turn Zoom On or Off", key: "\u{2325}\u{2318}8", isEnabled: true),
                ShortcutEntry(name: "Zoom In", key: "\u{2325}\u{2318}=", isEnabled: true),
                ShortcutEntry(name: "Zoom Out", key: "\u{2325}\u{2318}-", isEnabled: true),
                ShortcutEntry(name: "Turn Image Smoothing On/Off", key: "\u{2325}\u{2318}\\", isEnabled: false),
                ShortcutEntry(name: "Invert Colors", key: "\u{2303}\u{2325}\u{2318}8", isEnabled: true),
                ShortcutEntry(name: "Turn VoiceOver On or Off", key: "\u{2318}F5", isEnabled: true),
            ]),
            ShortcutCategory(name: "Keyboard & Text Input", shortcuts: [
                ShortcutEntry(name: "Change the Way Tab Moves Focus", key: "\u{2303}F7", isEnabled: true),
                ShortcutEntry(name: "Turn Keyboard Access On/Off", key: "\u{2303}F1", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Menu Bar", key: "\u{2303}F2", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Dock", key: "\u{2303}F3", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Window Toolbar", key: "\u{2303}F5", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Floating Window", key: "\u{2303}F6", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Next Window", key: "\u{2318}`", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Status Menus", key: "\u{2303}F8", isEnabled: true),
                ShortcutEntry(name: "Select Next Source in Input Menu", key: "\u{2318}Space", isEnabled: false),
            ]),
            ShortcutCategory(name: "Screen Shots", shortcuts: [
                ShortcutEntry(name: "Save Picture of Screen as File", key: "\u{21E7}\u{2318}3", isEnabled: true),
                ShortcutEntry(name: "Copy Picture of Screen to Clipboard", key: "\u{2303}\u{21E7}\u{2318}3", isEnabled: true),
                ShortcutEntry(name: "Save Picture of Selected Area as File", key: "\u{21E7}\u{2318}4", isEnabled: true),
                ShortcutEntry(name: "Copy Picture of Selected Area to Clipboard", key: "\u{2303}\u{21E7}\u{2318}4", isEnabled: true),
            ]),
            ShortcutCategory(name: "Services", shortcuts: [
                ShortcutEntry(name: "No shortcuts configured", key: "", isEnabled: false),
            ]),
            ShortcutCategory(name: "Front Row", shortcuts: [
                ShortcutEntry(name: "Open Front Row", key: "\u{2318}Esc", isEnabled: true),
            ]),
            ShortcutCategory(name: "Keyboard Navigation", shortcuts: [
                ShortcutEntry(name: "Move Focus to Next Window", key: "\u{2318}`", isEnabled: true),
                ShortcutEntry(name: "Move Focus to Status Menus", key: "\u{2303}F8", isEnabled: true),
            ]),
        ]
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

    @objc private func modifierKeysPressed(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Modifier Keys"
        alert.informativeText = "Modifier Keys configuration requires System Settings."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    @objc private func shortcutCheckboxToggled(_ sender: NSButton) {
        let row = shortcutsTableView.row(for: sender)
        guard row >= 0, row < shortcutCategories[selectedCategoryIndex].shortcuts.count else { return }
        shortcutCategories[selectedCategoryIndex].shortcuts[row].isEnabled = (sender.state == .on)
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

extension KeyboardPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 1 {
            return shortcutCategories.count
        } else {
            guard selectedCategoryIndex < shortcutCategories.count else { return 0 }
            return shortcutCategories[selectedCategoryIndex].shortcuts.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let columnID = tableColumn?.identifier.rawValue ?? ""

        if tableView.tag == 1 {
            // Category sidebar
            let cellID = NSUserInterfaceItemIdentifier("CategoryCell")
            let cell: NSTextField
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                cell = existing
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.font = SnowLeopardFonts.label(size: 11)
                cell.lineBreakMode = .byTruncatingTail
            }
            guard row < shortcutCategories.count else { return cell }
            cell.stringValue = shortcutCategories[row].name
            return cell
        }

        // Shortcuts table
        guard selectedCategoryIndex < shortcutCategories.count else { return nil }
        let shortcuts = shortcutCategories[selectedCategoryIndex].shortcuts
        guard row < shortcuts.count else { return nil }
        let entry = shortcuts[row]

        if columnID == "EnabledColumn" {
            let cellID = NSUserInterfaceItemIdentifier("EnabledCell")
            let checkbox: NSButton
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSButton {
                checkbox = existing
            } else {
                checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(shortcutCheckboxToggled(_:)))
                checkbox.identifier = cellID
            }
            checkbox.state = entry.isEnabled ? .on : .off
            return checkbox

        } else if columnID == "ShortcutColumn" {
            let cellID = NSUserInterfaceItemIdentifier("ShortcutNameCell")
            let cell: NSTextField
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                cell = existing
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.font = SnowLeopardFonts.label(size: 11)
                cell.lineBreakMode = .byTruncatingTail
            }
            cell.stringValue = entry.name
            return cell

        } else if columnID == "KeyColumn" {
            let cellID = NSUserInterfaceItemIdentifier("KeyCell")
            let cell: NSTextField
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                cell = existing
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.font = SnowLeopardFonts.label(size: 11)
                cell.alignment = .right
            }
            cell.stringValue = entry.key
            return cell
        }

        return nil
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView, tableView.tag == 1 else { return }
        let newIndex = tableView.selectedRow
        guard newIndex >= 0, newIndex < shortcutCategories.count else { return }
        selectedCategoryIndex = newIndex
        shortcutsTableView.reloadData()
    }
}
