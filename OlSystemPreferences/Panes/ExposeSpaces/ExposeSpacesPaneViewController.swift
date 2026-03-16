import Cocoa

class ExposeSpacesPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "exposespaces" }
    var paneTitle: String { "Expose\u{0301} & Spaces" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Expose & Spaces") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 560) }
    var searchKeywords: [String] { ["expose", "spaces", "hot corner", "mission control", "desktop", "screen saver", "lock screen"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Desktop-Settings.extension" }

    // MARK: - Services

    private let defaults = DefaultsService.shared
    private let dockDomain = "com.apple.dock"
    private let spacesDomain = "com.apple.spaces"

    // MARK: - Tab view

    private let tabView = AquaTabView()

    // MARK: - Corner popup buttons (Exposé tab)

    private let topLeftPopup = NSPopUpButton()
    private let topRightPopup = NSPopUpButton()
    private let bottomLeftPopup = NSPopUpButton()
    private let bottomRightPopup = NSPopUpButton()

    // MARK: - Corner action definitions

    private let cornerActions: [(title: String, code: Int)] = [
        ("\u{2014}", 0),                  // em dash = none
        ("Mission Control", 2),
        ("Application Windows", 3),
        ("Desktop", 4),
        ("Start Screen Saver", 5),
        ("Disable Screen Saver", 6),
        ("Dashboard", 7),
        ("Launchpad", 11),
        ("Notification Center", 12),
        ("Lock Screen", 13),
        ("Put Display to Sleep", 10),
    ]

    // MARK: - Monitor bezel view

    private let monitorView = MonitorFrameView()

    // MARK: - Spaces tab controls

    private let enableSpacesCheck = AquaCheckbox(title: "Enable Spaces", isChecked: false)
    private let menuBarCheck = AquaCheckbox(title: "Show Spaces in menu bar", isChecked: false)
    private let rowsStepper = NSStepper()
    private let rowsValueLabel = NSTextField(labelWithString: "1")
    private let columnsStepper = NSStepper()
    private let columnsValueLabel = NSTextField(labelWithString: "1")
    private let spacesGridPreview = SpacesGridPreviewView()
    private let activateSpacesPopup = AquaPopUpButton(items: [], selectedIndex: 0)
    private let switchSpacesPopup = AquaPopUpButton(items: [], selectedIndex: 0)

    private var spacesRows: Int = 1
    private var spacesColumns: Int = 1

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12

        // Pane header
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        header.widthAnchor.constraint(equalToConstant: 620).isActive = true
        outerStack.addArrangedSubview(header)

        // Separator below header
        outerStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 620))

        // Tab view with Exposé and Spaces tabs
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTab(title: "Expose\u{0301}", view: createExposeTab())
        tabView.addTab(title: "Spaces", view: createSpacesTab())

        outerStack.addArrangedSubview(tabView)

        view.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            outerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            outerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
            tabView.widthAnchor.constraint(equalToConstant: 620),
            tabView.heightAnchor.constraint(equalToConstant: 460),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - Exposé Tab

    private func createExposeTab() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

        // Section box for hot corners
        let hotCornersBox = SnowLeopardPaneHelper.makeSectionBox(title: "Active Screen Corners")
        hotCornersBox.widthAnchor.constraint(equalToConstant: 580).isActive = true

        let hotCornersContent = createHotCornersContent()
        hotCornersBox.contentView = hotCornersContent

        stack.addArrangedSubview(hotCornersBox)

        // Description text
        let descLabel = SnowLeopardPaneHelper.makeLabel(
            "Move your pointer to a corner of the screen to start an action. You can also hold modifier keys to require them for activation.",
            size: 11
        )
        descLabel.preferredMaxLayoutWidth = 560
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 3
        descLabel.textColor = NSColor(white: 0.40, alpha: 1.0)
        stack.addArrangedSubview(descLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Hot Corners Content

    private func createHotCornersContent() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Monitor in center
        monitorView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(monitorView)

        // Setup all four corner popups
        for popup in [topLeftPopup, topRightPopup, bottomLeftPopup, bottomRightPopup] {
            setupCornerPopup(popup)
            popup.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(popup)
            popup.widthAnchor.constraint(equalToConstant: 170).isActive = true
        }

        // Corner labels
        let tlLabel = makeCornerLabel("Top Left:")
        let trLabel = makeCornerLabel("Top Right:")
        let blLabel = makeCornerLabel("Bottom Left:")
        let brLabel = makeCornerLabel("Bottom Right:")
        container.addSubview(tlLabel)
        container.addSubview(trLabel)
        container.addSubview(blLabel)
        container.addSubview(brLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 340),

            // Monitor centered
            monitorView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            monitorView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            monitorView.widthAnchor.constraint(equalToConstant: 240),
            monitorView.heightAnchor.constraint(equalToConstant: 180),

            // Top-left label + popup
            tlLabel.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            tlLabel.bottomAnchor.constraint(equalTo: topLeftPopup.topAnchor, constant: -2),

            topLeftPopup.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            topLeftPopup.centerYAnchor.constraint(equalTo: monitorView.topAnchor, constant: 20),

            // Top-right label + popup
            trLabel.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            trLabel.bottomAnchor.constraint(equalTo: topRightPopup.topAnchor, constant: -2),

            topRightPopup.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            topRightPopup.centerYAnchor.constraint(equalTo: monitorView.topAnchor, constant: 20),

            // Bottom-left label + popup
            blLabel.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            blLabel.bottomAnchor.constraint(equalTo: bottomLeftPopup.topAnchor, constant: -2),

            bottomLeftPopup.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            bottomLeftPopup.centerYAnchor.constraint(equalTo: monitorView.bottomAnchor, constant: -40),

            // Bottom-right label + popup
            brLabel.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            brLabel.bottomAnchor.constraint(equalTo: bottomRightPopup.topAnchor, constant: -2),

            bottomRightPopup.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            bottomRightPopup.centerYAnchor.constraint(equalTo: monitorView.bottomAnchor, constant: -40),
        ])

        return container
    }

    // MARK: - Spaces Tab

    private func createSpacesTab() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)

        // Enable Spaces checkbox
        enableSpacesCheck.target = self
        enableSpacesCheck.action = #selector(enableSpacesChanged(_:))
        stack.addArrangedSubview(enableSpacesCheck)

        // Show Spaces in menu bar checkbox
        menuBarCheck.target = self
        menuBarCheck.action = #selector(menuBarCheckChanged(_:))
        stack.addArrangedSubview(menuBarCheck)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Rows and Columns section with grid preview
        let gridConfigBox = SnowLeopardPaneHelper.makeSectionBox(title: "Number of Spaces")
        gridConfigBox.widthAnchor.constraint(equalToConstant: 560).isActive = true

        let gridConfigContent = createGridConfigContent()
        gridConfigBox.contentView = gridConfigContent

        stack.addArrangedSubview(gridConfigBox)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Keyboard shortcuts section
        let shortcutsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Keyboard Shortcuts")
        shortcutsBox.widthAnchor.constraint(equalToConstant: 560).isActive = true

        let shortcutsContent = createShortcutsContent()
        shortcutsBox.contentView = shortcutsContent

        stack.addArrangedSubview(shortcutsBox)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Grid Configuration Content

    private func createGridConfigContent() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Left side: rows and columns steppers
        let controlsStack = NSStackView()
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        controlsStack.orientation = .vertical
        controlsStack.alignment = .leading
        controlsStack.spacing = 10

        // Rows row
        let rowsLabel = SnowLeopardPaneHelper.makeLabel("Rows:", size: 11)
        rowsLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
        rowsLabel.alignment = .right

        configureStepper(rowsStepper, min: 1, max: 4, value: 1)
        rowsStepper.target = self
        rowsStepper.action = #selector(rowsStepperChanged(_:))

        rowsValueLabel.font = SnowLeopardFonts.label(size: 11)
        rowsValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        rowsValueLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let rowsRow = NSStackView(views: [rowsLabel, rowsStepper, rowsValueLabel])
        rowsRow.orientation = .horizontal
        rowsRow.spacing = 6
        rowsRow.alignment = .centerY
        controlsStack.addArrangedSubview(rowsRow)

        // Columns row
        let columnsLabel = SnowLeopardPaneHelper.makeLabel("Columns:", size: 11)
        columnsLabel.widthAnchor.constraint(equalToConstant: 70).isActive = true
        columnsLabel.alignment = .right

        configureStepper(columnsStepper, min: 1, max: 4, value: 1)
        columnsStepper.target = self
        columnsStepper.action = #selector(columnsStepperChanged(_:))

        columnsValueLabel.font = SnowLeopardFonts.label(size: 11)
        columnsValueLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        columnsValueLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true

        let columnsRow = NSStackView(views: [columnsLabel, columnsStepper, columnsValueLabel])
        columnsRow.orientation = .horizontal
        columnsRow.spacing = 6
        columnsRow.alignment = .centerY
        controlsStack.addArrangedSubview(columnsRow)

        container.addSubview(controlsStack)

        // Right side: grid preview
        spacesGridPreview.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spacesGridPreview)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 140),

            controlsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            controlsStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            spacesGridPreview.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            spacesGridPreview.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            spacesGridPreview.widthAnchor.constraint(equalToConstant: 260),
            spacesGridPreview.heightAnchor.constraint(equalToConstant: 120),
        ])

        return container
    }

    // MARK: - Shortcuts Content

    private func createShortcutsContent() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10

        let shortcutItems = [
            "\u{2014}",         // none
            "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8",
            "F9", "F10", "F11", "F12",
        ]

        // Activate Spaces row
        let activateLabel = SnowLeopardPaneHelper.makeLabel("To activate Spaces:", size: 11)
        activateLabel.widthAnchor.constraint(equalToConstant: 170).isActive = true
        activateLabel.alignment = .right

        activateSpacesPopup.items = shortcutItems
        activateSpacesPopup.selectedIndex = 0
        activateSpacesPopup.target = self
        activateSpacesPopup.action = #selector(activateShortcutChanged(_:))

        let activateRow = NSStackView(views: [activateLabel, activateSpacesPopup])
        activateRow.orientation = .horizontal
        activateRow.spacing = 8
        activateRow.alignment = .firstBaseline
        stack.addArrangedSubview(activateRow)

        // Switch between spaces row
        let switchLabel = SnowLeopardPaneHelper.makeLabel("To switch between spaces:", size: 11)
        switchLabel.widthAnchor.constraint(equalToConstant: 170).isActive = true
        switchLabel.alignment = .right

        switchSpacesPopup.items = shortcutItems
        switchSpacesPopup.selectedIndex = 0
        switchSpacesPopup.target = self
        switchSpacesPopup.action = #selector(switchShortcutChanged(_:))

        let switchRow = NSStackView(views: [switchLabel, switchSpacesPopup])
        switchRow.orientation = .horizontal
        switchRow.spacing = 8
        switchRow.alignment = .firstBaseline
        stack.addArrangedSubview(switchRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
        ])

        return container
    }

    // MARK: - Helpers

    private func makeCornerLabel(_ text: String) -> NSTextField {
        let label = SnowLeopardPaneHelper.makeLabel(text, size: 10, bold: true)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setupCornerPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for action in cornerActions {
            popup.addItem(withTitle: action.title)
            popup.lastItem?.tag = action.code
        }
        popup.font = SnowLeopardFonts.label(size: 11)
        popup.controlSize = .small
        popup.target = self
        popup.action = #selector(cornerChanged(_:))
    }

    private func configureStepper(_ stepper: NSStepper, min: Double, max: Double, value: Double) {
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.minValue = min
        stepper.maxValue = max
        stepper.doubleValue = value
        stepper.increment = 1
        stepper.valueWraps = false
        stepper.controlSize = .small
    }

    private func updateSpacesGridPreview() {
        spacesGridPreview.rows = spacesRows
        spacesGridPreview.columns = spacesColumns
        spacesGridPreview.needsDisplay = true
    }

    private func updateSpacesControlStates() {
        let enabled = enableSpacesCheck.isChecked
        menuBarCheck.isEnabled = enabled
        rowsStepper.isEnabled = enabled
        columnsStepper.isEnabled = enabled
        activateSpacesPopup.isEnabled = enabled
        switchSpacesPopup.isEnabled = enabled
        spacesGridPreview.alphaValue = enabled ? 1.0 : 0.5
    }

    // MARK: - Reload

    func reloadFromSystem() {
        // Hot corners
        loadCorner("wvous-tl-corner", popup: topLeftPopup)
        loadCorner("wvous-tr-corner", popup: topRightPopup)
        loadCorner("wvous-bl-corner", popup: bottomLeftPopup)
        loadCorner("wvous-br-corner", popup: bottomRightPopup)

        // Spaces settings
        // mru-spaces: when true, spaces reorder based on most recent use (opposite of "Enable Spaces" in the classic sense)
        let mruSpaces = defaults.bool(forKey: "mru-spaces", domain: dockDomain) ?? true
        enableSpacesCheck.isChecked = !mruSpaces

        // Show Spaces in menu bar (spans-displays controls multi-monitor behavior)
        let spansDisplays = defaults.bool(forKey: "spans-displays", domain: spacesDomain) ?? false
        menuBarCheck.isChecked = spansDisplays

        // Read spaces layout from com.apple.spaces
        // The actual grid is configured via spaces-rows and spaces-columns in com.apple.dock
        spacesRows = defaults.integer(forKey: "spaces-rows", domain: dockDomain) ?? 1
        spacesColumns = defaults.integer(forKey: "spaces-columns", domain: dockDomain) ?? 1

        // Clamp values
        spacesRows = max(1, min(4, spacesRows))
        spacesColumns = max(1, min(4, spacesColumns))

        rowsStepper.integerValue = spacesRows
        rowsValueLabel.stringValue = "\(spacesRows)"
        columnsStepper.integerValue = spacesColumns
        columnsValueLabel.stringValue = "\(spacesColumns)"

        updateSpacesGridPreview()
        updateSpacesControlStates()
    }

    private func loadCorner(_ key: String, popup: NSPopUpButton) {
        let code = defaults.integer(forKey: key, domain: dockDomain) ?? 0
        for i in 0..<popup.numberOfItems {
            if popup.item(at: i)?.tag == code {
                popup.selectItem(at: i)
                return
            }
        }
        popup.selectItem(at: 0)
    }

    // MARK: - Hot Corner Actions

    @objc private func cornerChanged(_ sender: NSPopUpButton) {
        guard let code = sender.selectedItem?.tag else { return }

        let key: String
        switch sender {
        case topLeftPopup:
            key = "wvous-tl-corner"
        case topRightPopup:
            key = "wvous-tr-corner"
        case bottomLeftPopup:
            key = "wvous-bl-corner"
        case bottomRightPopup:
            key = "wvous-br-corner"
        default:
            return
        }

        defaults.setInteger(code, forKey: key, domain: dockDomain)
        DockService.shared.applyChanges()
    }

    // MARK: - Spaces Actions

    @objc private func enableSpacesChanged(_ sender: AquaCheckbox) {
        // mru-spaces is the inverse: when Spaces is "enabled" in Snow Leopard, mru-spaces should be off
        defaults.setBool(!sender.isChecked, forKey: "mru-spaces", domain: dockDomain)
        DockService.shared.applyChanges()
        updateSpacesControlStates()
    }

    @objc private func menuBarCheckChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "spans-displays", domain: spacesDomain)
    }

    @objc private func rowsStepperChanged(_ sender: NSStepper) {
        spacesRows = sender.integerValue
        rowsValueLabel.stringValue = "\(spacesRows)"
        defaults.setInteger(spacesRows, forKey: "spaces-rows", domain: dockDomain)
        updateSpacesGridPreview()
        DockService.shared.applyChanges()
    }

    @objc private func columnsStepperChanged(_ sender: NSStepper) {
        spacesColumns = sender.integerValue
        columnsValueLabel.stringValue = "\(spacesColumns)"
        defaults.setInteger(spacesColumns, forKey: "spaces-columns", domain: dockDomain)
        updateSpacesGridPreview()
        DockService.shared.applyChanges()
    }

    @objc private func activateShortcutChanged(_ sender: AquaPopUpButton) {
        // Store the selected shortcut preference (UI-only for now since modern macOS uses different shortcut system)
        defaults.setInteger(sender.selectedIndex, forKey: "spaces-activate-shortcut", domain: dockDomain)
    }

    @objc private func switchShortcutChanged(_ sender: AquaPopUpButton) {
        // Store the selected shortcut preference (UI-only for now since modern macOS uses different shortcut system)
        defaults.setInteger(sender.selectedIndex, forKey: "spaces-switch-shortcut", domain: dockDomain)
    }
}

// MARK: - Spaces Grid Preview View

/// Draws a visual grid of workspace tiles matching the configured rows and columns layout.
class SpacesGridPreviewView: NSView {

    var rows: Int = 1
    var columns: Int = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset: CGFloat = 8
        let spacing: CGFloat = 4
        let drawRect = bounds.insetBy(dx: inset, dy: inset)

        // Background
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        NSColor(white: 0.22, alpha: 1.0).setFill()
        bgPath.fill()

        // Inner screen area
        let screenPath = NSBezierPath(roundedRect: drawRect, xRadius: 3, yRadius: 3)
        NSColor(white: 0.12, alpha: 1.0).setFill()
        screenPath.fill()

        guard rows > 0, columns > 0 else { return }

        let cellInset: CGFloat = 4
        let cellArea = drawRect.insetBy(dx: cellInset, dy: cellInset)

        let totalHSpacing = spacing * CGFloat(columns - 1)
        let totalVSpacing = spacing * CGFloat(rows - 1)
        let cellWidth = (cellArea.width - totalHSpacing) / CGFloat(columns)
        let cellHeight = (cellArea.height - totalVSpacing) / CGFloat(rows)

        for row in 0..<rows {
            for col in 0..<columns {
                let x = cellArea.origin.x + CGFloat(col) * (cellWidth + spacing)
                let y = cellArea.origin.y + cellArea.height - CGFloat(row + 1) * cellHeight - CGFloat(row) * spacing
                let cellRect = NSRect(x: x, y: y, width: cellWidth, height: cellHeight)

                // Gradient for each space tile (Aqua blue tint)
                let tilePath = NSBezierPath(roundedRect: cellRect, xRadius: 2, yRadius: 2)

                let gradient = NSGradient(
                    starting: NSColor(calibratedRed: 0.40, green: 0.60, blue: 0.85, alpha: 1.0),
                    ending: NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.75, alpha: 1.0)
                )
                gradient?.draw(in: tilePath, angle: 90)

                // Border
                NSColor(calibratedRed: 0.18, green: 0.35, blue: 0.65, alpha: 1.0).setStroke()
                tilePath.lineWidth = 0.5
                tilePath.stroke()

                // Space number label
                let spaceNumber = row * columns + col + 1
                let numStr = "\(spaceNumber)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: SnowLeopardFonts.boldLabel(size: 10),
                    .foregroundColor: NSColor.white,
                ]
                let strSize = numStr.size(withAttributes: attrs)
                let strPoint = NSPoint(
                    x: cellRect.midX - strSize.width / 2,
                    y: cellRect.midY - strSize.height / 2
                )
                numStr.draw(at: strPoint, withAttributes: attrs)
            }
        }
    }
}
