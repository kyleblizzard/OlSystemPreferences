// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

// MARK: - PrintFaxPaneViewController
// This view controller recreates the Snow Leopard "Print & Fax" preference pane.
// It uses a split-view layout: a printer list on the left, and details about the
// selected printer on the right. Printer information is gathered from the system
// using shell commands (lpstat) and NSPrinter APIs.

class PrintFaxPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol Properties
    // These properties tell the main window controller how to display this pane
    // in the grid, toolbar, and window chrome.

    var paneIdentifier: String { "printfax" }
    var paneTitle: String { "Print & Fax" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "printer.fill", accessibilityDescription: "Print & Fax") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 500) }
    var searchKeywords: [String] { ["printer", "fax", "print", "scanner", "default", "paper"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Print-Scan-Settings.extension" }

    // MARK: - Data Model
    // Each printer discovered on the system is stored as a PrinterInfo struct.
    // We track its name, kind (model), status, and location so we can display
    // them in the detail panel when the user selects a printer from the list.

    private struct PrinterInfo {
        let name: String               // The CUPS queue name (e.g. "HP_LaserJet")
        var displayName: String = ""    // A human-friendly name if available
        var kind: String = "Unknown"    // Printer model/type parsed from lpstat
        var status: String = "Unknown"  // idle, printing, disabled, etc.
        var location: String = ""       // Physical location if reported by the printer
    }

    /// All printers discovered on the system
    private var printers: [PrinterInfo] = []

    /// Index of the currently selected printer in the table view
    private var selectedIndex: Int = 0

    // MARK: - UI Elements
    // The left panel holds a scrollable table of printers. The right panel
    // holds detail labels and popups that update when the selection changes.

    // Left panel — printer list
    private let printerTable = NSTableView()
    private let printerScrollView = NSScrollView()

    // Right panel — detail labels for the selected printer
    private let printerNameLabel = NSTextField(labelWithString: "")
    private let kindLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let locationLabel = NSTextField(labelWithString: "")

    // Popups for default printer and paper size
    private let defaultPrinterPopup = NSPopUpButton()
    private let defaultPaperPopup = NSPopUpButton()

    // Bottom section controls
    private let sharingCheckbox = NSButton(checkboxWithTitle: "Share printers connected to this computer", target: nil, action: nil)
    private let openQueueButton = NSButton(title: "Open Print Queue...", target: nil, action: nil)

    // MARK: - Load View
    // Builds the entire UI programmatically — no XIBs or storyboards.
    // The layout follows the same split-view pattern as NetworkPaneViewController:
    // header at top, then a horizontal split with a 200px list on the left
    // and a detail box filling the remaining width on the right.

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // The outer stack holds everything vertically: header, separator, split, bottom controls
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        // Standard pane header with icon, title, and "Open in System Settings..." button
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Separator below the header ---
        let headerSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        outerStack.addArrangedSubview(headerSep)

        // --- Split Container: left printer list + right detail panel ---
        let splitContainer = NSView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false

        // ========== LEFT PANEL: Printer List ==========
        // An NSScrollView wrapping an NSTableView that shows each printer
        // with a printer icon and name, similar to the Snow Leopard layout.

        printerScrollView.translatesAutoresizingMaskIntoConstraints = false
        printerScrollView.hasVerticalScroller = true
        printerScrollView.borderType = .bezelBorder

        // Single column — we render custom cells with icon + name
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("printer"))
        nameCol.title = "Printers"
        nameCol.width = 180
        printerTable.addTableColumn(nameCol)
        printerTable.headerView = nil           // No column header — Snow Leopard style
        printerTable.delegate = self
        printerTable.dataSource = self
        printerTable.rowHeight = 28
        printerTable.usesAlternatingRowBackgroundColors = true
        printerScrollView.documentView = printerTable

        splitContainer.addSubview(printerScrollView)

        // +/– buttons below the printer list (informational only — they point to System Settings)
        let addRemoveBar = makeAddRemoveBar()
        splitContainer.addSubview(addRemoveBar)

        // ========== RIGHT PANEL: Selected Printer Details ==========
        // Wrapped in a Snow Leopard-style section box (NSBox with grouped appearance).

        let detailBox = SnowLeopardPaneHelper.makeSectionBox()
        let detailStack = NSStackView()
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 10
        detailStack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Printer name (bold, prominent)
        printerNameLabel.font = SnowLeopardFonts.boldLabel(size: 13)
        printerNameLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        detailStack.addArrangedSubview(printerNameLabel)

        detailStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 360))

        // Kind / Type row — shows the printer model (e.g. "HP LaserJet Pro")
        kindLabel.font = SnowLeopardFonts.label(size: 11)
        kindLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        let kindRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Kind:"),
            controls: [kindLabel]
        )
        detailStack.addArrangedSubview(kindRow)

        // Status row — shows idle, printing, disabled, etc.
        statusLabel.font = SnowLeopardFonts.label(size: 11)
        statusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        let statusRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Status:"),
            controls: [statusLabel]
        )
        detailStack.addArrangedSubview(statusRow)

        // Location row — physical location if the printer reports one
        locationLabel.font = SnowLeopardFonts.label(size: 11)
        locationLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        let locationRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Location:"),
            controls: [locationLabel]
        )
        detailStack.addArrangedSubview(locationRow)

        detailStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 360))

        // Default printer popup — lets user see which printer is the system default.
        // In Snow Leopard, this was a dropdown showing all printers; the current
        // default was pre-selected.
        SnowLeopardPaneHelper.styleControl(defaultPrinterPopup, size: 11)
        defaultPrinterPopup.target = self
        defaultPrinterPopup.action = #selector(defaultPrinterChanged(_:))
        let defaultPrinterRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Default printer:"),
            controls: [defaultPrinterPopup]
        )
        detailStack.addArrangedSubview(defaultPrinterRow)

        // Default paper size popup — common paper sizes. Snow Leopard showed
        // US Letter, US Legal, A4, Tabloid, etc.
        SnowLeopardPaneHelper.styleControl(defaultPaperPopup, size: 11)
        defaultPaperPopup.addItems(withTitles: ["US Letter", "US Legal", "A4", "Tabloid"])
        defaultPaperPopup.target = self
        defaultPaperPopup.action = #selector(defaultPaperChanged(_:))
        let defaultPaperRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Default paper size:"),
            controls: [defaultPaperPopup]
        )
        detailStack.addArrangedSubview(defaultPaperRow)

        detailBox.contentView = detailStack
        detailBox.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(detailBox)

        // ========== Layout Constraints for the Split ==========
        // Left list is 200px wide, detail box fills the rest.
        // The +/– bar sits directly below the scroll view.
        NSLayoutConstraint.activate([
            // Printer list (left, top, 200px wide)
            printerScrollView.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor),
            printerScrollView.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            printerScrollView.widthAnchor.constraint(equalToConstant: 200),
            // Leave room at the bottom for the +/– bar
            printerScrollView.bottomAnchor.constraint(equalTo: addRemoveBar.topAnchor, constant: -1),

            // +/– bar pinned below the list, same width
            addRemoveBar.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor),
            addRemoveBar.widthAnchor.constraint(equalToConstant: 200),
            addRemoveBar.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
            addRemoveBar.heightAnchor.constraint(equalToConstant: 24),

            // Detail box (right side, full height)
            detailBox.leadingAnchor.constraint(equalTo: printerScrollView.trailingAnchor, constant: 12),
            detailBox.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor),
            detailBox.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            detailBox.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
        ])

        outerStack.addArrangedSubview(splitContainer)
        splitContainer.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        splitContainer.heightAnchor.constraint(equalToConstant: 300).isActive = true

        // --- Bottom Section ---
        // Sharing checkbox and "Open Print Queue..." button, just like Snow Leopard.

        let bottomSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        outerStack.addArrangedSubview(bottomSep)

        // Sharing checkbox — read-only indicator of whether printer sharing is enabled
        sharingCheckbox.font = SnowLeopardFonts.label(size: 11)
        sharingCheckbox.isEnabled = false   // Read-only — actual changes require System Settings
        outerStack.addArrangedSubview(sharingCheckbox)

        // "Open Print Queue..." button — opens the CUPS print queue for the selected printer
        openQueueButton.bezelStyle = .rounded
        SnowLeopardPaneHelper.styleControl(openQueueButton, size: 11)
        openQueueButton.target = self
        openQueueButton.action = #selector(openPrintQueue(_:))
        outerStack.addArrangedSubview(openQueueButton)

        // Pin the outer stack to the root view
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

    // MARK: - PaneProtocol — Reload
    // Called when the pane first appears and whenever the user navigates back.
    // Gathers all printer data fresh from the system.

    func reloadFromSystem() {
        printers.removeAll()

        // Step 1: Discover printers using NSPrinter API first, then fall back to lpstat
        let printerNames = discoverPrinters()

        // Step 2: For each printer, gather detailed info via lpstat
        for name in printerNames {
            var info = PrinterInfo(name: name, displayName: name)
            let details = getPrinterDetails(name: name)
            info.kind = details.kind
            info.status = details.status
            info.location = details.location
            printers.append(info)
        }

        // Fallback: if no printers were found at all, show a helpful placeholder
        if printers.isEmpty {
            printers.append(PrinterInfo(
                name: "No Printers",
                displayName: "No Printers Available",
                kind: "N/A",
                status: "No printers configured",
                location: ""
            ))
        }

        // Refresh the table and select the first printer
        printerTable.reloadData()
        if !printers.isEmpty {
            printerTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateDetailView(index: 0)
        }

        // Populate the default printer popup with all discovered printers
        populateDefaultPrinterPopup()

        // Read the current default paper size from system preferences
        readDefaultPaperSize()

        // Check if printer sharing is enabled
        checkPrinterSharing()
    }

    // MARK: - Printer Discovery
    // We try NSPrinter.printerNames first because it's a clean Cocoa API.
    // If that returns nothing (common on modern macOS where CUPS has changed),
    // we fall back to parsing the output of `lpstat -a` which lists all CUPS queues.

    private func discoverPrinters() -> [String] {
        // Attempt 1: Use the Cocoa NSPrinter API
        let cocoaNames = NSPrinter.printerNames
        if !cocoaNames.isEmpty {
            return cocoaNames
        }

        // Attempt 2: Fall back to lpstat -a (lists all accepting printers)
        // Each line looks like: "PrinterName accepting requests since ..."
        guard let output = runCommand("/usr/bin/lpstat", arguments: ["-a"]) else {
            return []
        }

        var names: [String] = []
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            // The printer name is the first word on each line
            if let firstSpace = trimmed.firstIndex(of: " ") {
                let name = String(trimmed[trimmed.startIndex..<firstSpace])
                names.append(name)
            }
        }
        return names
    }

    // MARK: - Printer Detail Parsing
    // Uses `lpstat -l -p <name>` to get verbose printer info, and `lpstat -p <name>`
    // for a simpler status line. We parse the output to extract kind, status, and location.

    private func getPrinterDetails(name: String) -> (kind: String, status: String, location: String) {
        var kind = "Unknown"
        var status = "Unknown"
        var location = ""

        // Get verbose printer info — includes description and location fields
        if let verbose = runCommand("/usr/bin/lpstat", arguments: ["-l", "-p", name]) {
            let lines = verbose.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // The "Description:" line often contains the printer model
                if trimmed.hasPrefix("Description:") {
                    let value = trimmed.replacingOccurrences(of: "Description:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        kind = value
                    }
                }

                // The "Location:" line shows where the printer is physically
                if trimmed.hasPrefix("Location:") {
                    let value = trimmed.replacingOccurrences(of: "Location:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    if !value.isEmpty {
                        location = value
                    }
                }
            }
        }

        // Get simple status — "printer X is idle", "printer X disabled", etc.
        if let statusOutput = runCommand("/usr/bin/lpstat", arguments: ["-p", name]) {
            let trimmed = statusOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("idle") {
                status = "Idle"
            } else if trimmed.contains("printing") {
                status = "Printing"
            } else if trimmed.contains("disabled") {
                status = "Disabled"
            } else if !trimmed.isEmpty {
                // Use whatever lpstat says if we can't match a known status
                status = trimmed
            }
        }

        return (kind, status, location)
    }

    // MARK: - Default Printer Popup
    // Populates the popup with all printer names and selects whichever
    // printer is the current system default (from `lpstat -d`).

    private func populateDefaultPrinterPopup() {
        defaultPrinterPopup.removeAllItems()

        // Add all discovered printer names to the popup
        for printer in printers {
            defaultPrinterPopup.addItem(withTitle: printer.displayName)
        }

        // Figure out which printer is the system default
        if let output = runCommand("/usr/bin/lpstat", arguments: ["-d"]) {
            // Output looks like: "system default destination: PrinterName"
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if let colonIndex = trimmed.lastIndex(of: ":") {
                let defaultName = String(trimmed[trimmed.index(after: colonIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                // Try to select this printer in the popup
                defaultPrinterPopup.selectItem(withTitle: defaultName)

                // If the exact name didn't match, try matching against display names
                if defaultPrinterPopup.indexOfSelectedItem == -1 {
                    for (index, printer) in printers.enumerated() {
                        if printer.name == defaultName {
                            defaultPrinterPopup.selectItem(at: index)
                            break
                        }
                    }
                }
            }
        }
    }

    // MARK: - Default Paper Size
    // Reads the default paper size from macOS printing preferences.
    // The preference is stored in com.apple.print.PrintingPrefs as "DefaultPaperID".
    // Common values: "na-letter" (US Letter), "na-legal" (US Legal),
    // "iso-a4" (A4), "na-ledger" (Tabloid).

    private func readDefaultPaperSize() {
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.print.PrintingPrefs", "DefaultPaperID"]) {
            let paperID = output.trimmingCharacters(in: .whitespacesAndNewlines)

            // Map the CUPS paper ID to a human-readable name
            let paperName: String
            switch paperID {
            case "na-letter":
                paperName = "US Letter"
            case "na-legal":
                paperName = "US Legal"
            case "iso-a4":
                paperName = "A4"
            case "na-ledger", "tabloid":
                paperName = "Tabloid"
            default:
                // If it's something we don't recognize, default to US Letter
                paperName = "US Letter"
            }

            defaultPaperPopup.selectItem(withTitle: paperName)
        } else {
            // If the pref doesn't exist, default to US Letter
            defaultPaperPopup.selectItem(withTitle: "US Letter")
        }
    }

    // MARK: - Printer Sharing Check
    // Snow Leopard had a checkbox for "Share printers connected to this computer".
    // On modern macOS, printer sharing is managed by the CUPS service.
    // We check if the sharing service is loaded via launchctl.

    private func checkPrinterSharing() {
        // Check if the CUPS printer sharing service is running
        if let output = runCommand("/bin/launchctl", arguments: ["list"]) {
            let isSharing = output.contains("com.apple.PrinterSharing")
                || output.contains("cupsd")
            sharingCheckbox.state = isSharing ? .on : .off
        } else {
            sharingCheckbox.state = .off
        }
    }

    // MARK: - Detail View Update
    // Called whenever the user selects a different printer in the left list.
    // Updates all the labels and fields in the right detail panel.

    private func updateDetailView(index: Int) {
        guard index >= 0, index < printers.count else { return }
        let printer = printers[index]

        printerNameLabel.stringValue = printer.displayName
        kindLabel.stringValue = printer.kind
        statusLabel.stringValue = printer.status
        locationLabel.stringValue = printer.location.isEmpty ? "N/A" : printer.location
    }

    // MARK: - +/– Button Bar
    // Creates the small bar with + and – buttons below the printer list,
    // matching the Snow Leopard aesthetic. These buttons are disabled because
    // adding/removing printers requires elevated privileges that must go
    // through System Settings.

    private func makeAddRemoveBar() -> NSView {
        let bar = NSView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor(white: 0.90, alpha: 1.0).cgColor
        bar.layer?.borderColor = NSColor(white: 0.70, alpha: 1.0).cgColor
        bar.layer?.borderWidth = 0.5

        // "+" button — would add a printer in real Snow Leopard
        let addButton = NSButton(title: "+", target: self, action: #selector(addRemoveTapped(_:)))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .smallSquare
        addButton.font = SnowLeopardFonts.label(size: 13)
        addButton.isEnabled = false // Informational only
        addButton.toolTip = "Use System Settings to add printers"
        bar.addSubview(addButton)

        // "–" button — would remove a printer in real Snow Leopard
        let removeButton = NSButton(title: "–", target: self, action: #selector(addRemoveTapped(_:)))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        removeButton.bezelStyle = .smallSquare
        removeButton.font = SnowLeopardFonts.label(size: 13)
        removeButton.isEnabled = false // Informational only
        removeButton.toolTip = "Use System Settings to remove printers"
        bar.addSubview(removeButton)

        NSLayoutConstraint.activate([
            addButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            addButton.topAnchor.constraint(equalTo: bar.topAnchor),
            addButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            addButton.widthAnchor.constraint(equalToConstant: 28),

            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: -1),
            removeButton.topAnchor.constraint(equalTo: bar.topAnchor),
            removeButton.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 28),
        ])

        return bar
    }

    // MARK: - Actions

    /// Called when +/– buttons are tapped — opens System Settings since we can't
    /// add or remove printers directly without elevated privileges.
    @objc private func addRemoveTapped(_ sender: NSButton) {
        SystemSettingsLauncher.open(url: settingsURL)
    }

    /// Called when the user changes the default printer popup selection.
    /// We don't actually change the system default here (that requires lpadmin),
    /// but this shows the user's intent.
    @objc private func defaultPrinterChanged(_ sender: NSPopUpButton) {
        // In a real implementation this would call:
        // lpadmin -d <printerName>
        // For now, just open System Settings where the user can make the change
        // with proper authorization.
    }

    /// Called when the user changes the default paper size popup.
    /// Similar to the printer popup — read-only for display purposes.
    @objc private func defaultPaperChanged(_ sender: NSPopUpButton) {
        // In a real implementation this would write to:
        // defaults write com.apple.print.PrintingPrefs DefaultPaperID <value>
    }

    /// Opens the CUPS web interface for the selected printer's print queue.
    /// Snow Leopard had a dedicated "Print Queue" window — on modern macOS,
    /// the closest equivalent is the CUPS web interface at localhost:631.
    @objc private func openPrintQueue(_ sender: NSButton) {
        guard selectedIndex >= 0, selectedIndex < printers.count else { return }
        let printerName = printers[selectedIndex].name

        // Build a URL to the CUPS printer page
        let cupsURL = "http://localhost:631/printers/\(printerName)"
        if let url = URL(string: cupsURL) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Shell Command Helper
    // Runs an external process and captures its stdout as a string.
    // Used throughout this pane to query CUPS (lpstat) and system defaults.
    // Returns nil if the process fails to launch or produces no output.

    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // Suppress stderr to avoid noise
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

// MARK: - NSTableViewDataSource & Delegate
// Powers the printer list table on the left side of the split view.
// Each row shows a small printer icon and the printer's display name.

extension PrintFaxPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    /// Returns how many printers we have to show in the list
    func numberOfRows(in tableView: NSTableView) -> Int {
        return printers.count
    }

    /// Builds a custom cell view for each printer row — an icon and a name label.
    /// This matches the Snow Leopard aesthetic of showing a small printer icon
    /// next to each printer name in the list.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let printer = printers[row]

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Small printer icon (SF Symbol) for each row
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: "Printer")
        iconView.contentTintColor = NSColor(white: 0.35, alpha: 1.0)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(iconView)

        // Printer name label
        let label = NSTextField(labelWithString: printer.displayName)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = SnowLeopardFonts.label(size: 12)
        label.textColor = NSColor(white: 0.15, alpha: 1.0)
        label.lineBreakMode = .byTruncatingTail
        container.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
        ])

        return container
    }

    /// Called when the user clicks a different printer in the list.
    /// Updates the right detail panel to show the newly selected printer's info.
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }
        selectedIndex = row
        updateDetailView(index: row)
    }
}
