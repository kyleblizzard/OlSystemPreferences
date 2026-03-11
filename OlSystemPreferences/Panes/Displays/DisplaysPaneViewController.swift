import Cocoa

class DisplaysPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "displays" }
    var paneTitle: String { "Displays" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "display", accessibilityDescription: "Displays") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 480) }
    var searchKeywords: [String] { ["display", "monitor", "resolution", "screen", "brightness", "refresh rate", "scaled"] }
    var viewController: NSViewController { self }

    // MARK: - UI Elements

    private let resolutionLabel = NSTextField(labelWithString: "Resolution:")
    private let defaultRadio = NSButton(radioButtonWithTitle: "Default for display", target: nil, action: nil)
    private let scaledRadio = NSButton(radioButtonWithTitle: "Scaled", target: nil, action: nil)

    private let resolutionTable = NSTableView()
    private let refreshRateLabel = NSTextField(labelWithString: "Refresh Rate:")
    private let refreshRatePopup = NSPopUpButton()

    private let currentResLabel = NSTextField(labelWithString: "")

    private var displayModes: [(width: Int, height: Int, refreshRate: Double)] = []

    override func loadView() {
        view = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)

        // Display preview (blue rectangle representing screen)
        let previewBox = NSBox()
        previewBox.boxType = .custom
        previewBox.fillColor = NSColor.controlAccentColor.withAlphaComponent(0.15)
        previewBox.borderColor = NSColor.controlAccentColor
        previewBox.borderWidth = 2
        previewBox.cornerRadius = 8
        previewBox.translatesAutoresizingMaskIntoConstraints = false
        previewBox.widthAnchor.constraint(equalToConstant: 200).isActive = true
        previewBox.heightAnchor.constraint(equalToConstant: 125).isActive = true

        let previewRow = NSStackView(views: [previewBox])
        previewRow.alignment = .centerX

        // Resolution radio buttons
        defaultRadio.target = self; defaultRadio.action = #selector(resolutionModeChanged(_:))
        scaledRadio.target = self; scaledRadio.action = #selector(resolutionModeChanged(_:))
        let resRadioRow = NSStackView(views: [resolutionLabel, defaultRadio, scaledRadio])
        resRadioRow.spacing = 12

        // Resolution table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = resolutionTable

        let resCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("resolution"))
        resCol.title = "Resolution"
        resCol.width = 200
        resolutionTable.addTableColumn(resCol)

        let rateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("rate"))
        rateCol.title = "Refresh Rate"
        rateCol.width = 100
        resolutionTable.addTableColumn(rateCol)

        resolutionTable.delegate = self
        resolutionTable.dataSource = self
        resolutionTable.rowHeight = 22

        scrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        // Current resolution info
        currentResLabel.font = NSFont.systemFont(ofSize: 11)
        currentResLabel.textColor = .secondaryLabelColor

        stack.addArrangedSubview(previewRow)
        stack.addArrangedSubview(resRadioRow)
        stack.addArrangedSubview(scrollView)
        stack.addArrangedSubview(currentResLabel)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])

        // Start with "Default" selected, table hidden
        defaultRadio.state = .on
        scrollView.isHidden = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    func reloadFromSystem() {
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

    @objc private func resolutionModeChanged(_ sender: NSButton) {
        if sender === defaultRadio {
            scaledRadio.state = .off
            // Find and hide the scroll view
            if let scrollView = view.subviews.first?.subviews.compactMap({ $0 as? NSScrollView }).first {
                scrollView.isHidden = true
            }
        } else {
            defaultRadio.state = .off
            if let scrollView = view.subviews.first?.subviews.compactMap({ $0 as? NSScrollView }).first {
                scrollView.isHidden = false
            }
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
            return NSTextField(labelWithString: "\(mode.width) x \(mode.height)")
        } else {
            return NSTextField(labelWithString: "\(Int(mode.refreshRate)) Hz")
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
