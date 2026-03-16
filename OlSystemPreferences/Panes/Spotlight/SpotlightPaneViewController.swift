// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

// MARK: - SpotlightPaneViewController
/// Recreates the Snow Leopard "Spotlight" preference pane with two tabs:
///   1. "Search Results" — a checklist of Spotlight categories the user can enable/disable
///   2. "Privacy" — a list of folders excluded from Spotlight indexing
///
/// We read the real Spotlight preferences via `defaults read com.apple.spotlight orderedItems`
/// to populate category states, and fall back to a hardcoded default list if the read fails.

class SpotlightPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "spotlight" }
    var paneTitle: String { "Spotlight" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Spotlight") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] { ["spotlight", "search", "index", "privacy", "categories"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Siri-Settings.extension" }

    // MARK: - Data Model

    /// Represents a single Spotlight search category (e.g. "Applications", "Documents").
    /// Each category has a display name and an enabled flag that controls whether
    /// Spotlight includes that category in search results.
    private struct SpotlightCategory {
        let name: String
        var enabled: Bool
    }

    /// The ordered list of Spotlight categories shown in the Search Results tab.
    /// Populated from system preferences or defaults if the read fails.
    private var categories: [SpotlightCategory] = []

    /// Paths excluded from Spotlight indexing, shown in the Privacy tab.
    private var excludedPaths: [String] = []

    // MARK: - UI References

    /// Table view for the Search Results tab — displays categories with checkboxes.
    private let categoryTable = NSTableView()
    private let categoryScrollView = NSScrollView()

    /// Table view for the Privacy tab — displays excluded directory paths.
    private let privacyTable = NSTableView()
    private let privacyScrollView = NSScrollView()

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Main vertical stack — holds the pane header and tab view
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header: icon, title, and "Open in System Settings" button ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Tab View: "Search Results" and "Privacy" ---
        let tabView = SnowLeopardPaneHelper.makeAquaTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        // Build and add both tabs
        tabView.addTab(title: "Search Results", view: makeSearchTabContent())
        tabView.addTab(title: "Privacy", view: makePrivacyTabContent())
        tabView.selectTab(at: 0)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true

        // Pin the outer stack to the root view edges
        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Search Results Tab

    /// Builds the content view for the "Search Results" tab.
    /// Contains a table of Spotlight categories with checkboxes and an informational note.
    private func makeSearchTabContent() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Instructional label at top of the tab
        let instructionLabel = SnowLeopardPaneHelper.makeLabel(
            "Only selected categories will appear in Spotlight search results:",
            size: 11,
            bold: true
        )
        stack.addArrangedSubview(instructionLabel)

        // --- Category table with a checkbox column and a name column ---
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = false
        categoryScrollView.hasVerticalScroller = true
        categoryScrollView.borderType = .bezelBorder

        // Checkbox column — narrow, just wide enough for the checkbox
        let checkCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("check"))
        checkCol.title = ""
        checkCol.width = 28
        checkCol.minWidth = 28
        checkCol.maxWidth = 28
        categoryTable.addTableColumn(checkCol)

        // Category name column — takes the remaining width
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Category"
        nameCol.width = 520
        categoryTable.addTableColumn(nameCol)

        // Tag 1 distinguishes this table from the privacy table in delegate methods
        categoryTable.tag = 1
        categoryTable.delegate = self
        categoryTable.dataSource = self
        categoryTable.rowHeight = 22
        categoryTable.usesAlternatingRowBackgroundColors = true
        categoryTable.headerView = nil  // Snow Leopard Spotlight had no table header

        categoryScrollView.documentView = categoryTable
        categoryScrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        categoryScrollView.heightAnchor.constraint(equalToConstant: 320).isActive = true
        stack.addArrangedSubview(categoryScrollView)

        // Separator before the info note
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Informational text about drag-to-reorder — Snow Leopard's original pane had this
        let reorderNote = SnowLeopardPaneHelper.makeLabel(
            "Drag categories to change the order in which results appear in Spotlight.",
            size: 10
        )
        reorderNote.textColor = .secondaryLabelColor
        reorderNote.maximumNumberOfLines = 2
        reorderNote.preferredMaxLayoutWidth = 560
        stack.addArrangedSubview(reorderNote)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Privacy Tab

    /// Builds the content view for the "Privacy" tab.
    /// Shows a list of directories excluded from Spotlight indexing, plus +/- buttons.
    private func makePrivacyTabContent() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Instructional label
        let privacyLabel = SnowLeopardPaneHelper.makeLabel(
            "Prevent Spotlight from searching these locations:",
            size: 11,
            bold: true
        )
        stack.addArrangedSubview(privacyLabel)

        // --- Excluded paths table — single column showing directory paths ---
        privacyScrollView.translatesAutoresizingMaskIntoConstraints = false
        privacyScrollView.hasVerticalScroller = true
        privacyScrollView.borderType = .bezelBorder

        let pathCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("path"))
        pathCol.title = "Path"
        pathCol.width = 560
        privacyTable.addTableColumn(pathCol)

        // Tag 2 distinguishes this table from the category table
        privacyTable.tag = 2
        privacyTable.delegate = self
        privacyTable.dataSource = self
        privacyTable.rowHeight = 22
        privacyTable.usesAlternatingRowBackgroundColors = true
        privacyTable.headerView = nil

        privacyScrollView.documentView = privacyTable
        privacyScrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        privacyScrollView.heightAnchor.constraint(equalToConstant: 280).isActive = true
        stack.addArrangedSubview(privacyScrollView)

        // +/- button row beneath the table
        let addButton = NSButton(title: "+", target: self, action: #selector(addPrivacyPath(_:)))
        addButton.bezelStyle = .smallSquare
        addButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        addButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        SnowLeopardPaneHelper.styleControl(addButton, size: 12)

        let removeButton = NSButton(title: "\u{2212}", target: self, action: #selector(removePrivacyPath(_:)))
        removeButton.bezelStyle = .smallSquare
        removeButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        removeButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        SnowLeopardPaneHelper.styleControl(removeButton, size: 12)

        let buttonRow = NSStackView(views: [addButton, removeButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 0
        stack.addArrangedSubview(buttonRow)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Informational note about admin privileges
        let adminNote = SnowLeopardPaneHelper.makeLabel(
            "Adding or removing locations may require administrator privileges. Changes take effect after Spotlight re-indexes.",
            size: 10
        )
        adminNote.textColor = .secondaryLabelColor
        adminNote.maximumNumberOfLines = 3
        adminNote.preferredMaxLayoutWidth = 560
        stack.addArrangedSubview(adminNote)

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

    // MARK: - PaneProtocol — Reload

    /// Reads Spotlight preferences from the system and refreshes both tables.
    func reloadFromSystem() {
        loadCategories()
        loadExcludedPaths()
        categoryTable.reloadData()
        privacyTable.reloadData()
    }

    // MARK: - Load Categories from System

    /// Attempts to read Spotlight's ordered category list via `defaults read`.
    /// The output is a plist-style array of dictionaries, each containing `enabled` and `name` keys.
    /// If the read fails (e.g., first launch, sandboxed, or changed format), we fall back to defaults.
    private func loadCategories() {
        categories.removeAll()

        // Try reading the real Spotlight preferences
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.spotlight", "orderedItems"]) {
            let parsed = parseOrderedItems(output)
            if !parsed.isEmpty {
                categories = parsed
                return
            }
        }

        // Fallback: show all Snow Leopard categories as enabled
        categories = defaultCategories()
    }

    /// Parses the plist-style output from `defaults read com.apple.spotlight orderedItems`.
    /// The format looks like:
    /// ```
    /// (
    ///     { enabled = 1; name = "APPLICATIONS"; },
    ///     { enabled = 0; name = "MENU_EXPRESSION"; },
    ///     ...
    /// )
    /// ```
    /// We extract each `name` and `enabled` value and map internal names to display names.
    private func parseOrderedItems(_ output: String) -> [SpotlightCategory] {
        var result: [SpotlightCategory] = []
        let lines = output.components(separatedBy: "\n")

        var currentName: String?
        var currentEnabled: Bool?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for `enabled = 1;` or `enabled = 0;`
            if trimmed.hasPrefix("enabled") {
                if trimmed.contains("1") {
                    currentEnabled = true
                } else {
                    currentEnabled = false
                }
            }

            // Look for `name = "SOME_NAME";`
            if trimmed.hasPrefix("name") {
                // Extract the value between quotes
                if let openQuote = trimmed.firstIndex(of: "\""),
                   let closeQuote = trimmed[trimmed.index(after: openQuote)...].firstIndex(of: "\"") {
                    let rawName = String(trimmed[trimmed.index(after: openQuote)..<closeQuote])
                    currentName = rawName
                }
                // Some entries don't use quotes: name = APPLICATIONS;
                else {
                    let parts = trimmed.components(separatedBy: "=")
                    if parts.count >= 2 {
                        let rawName = parts[1]
                            .replacingOccurrences(of: ";", with: "")
                            .replacingOccurrences(of: "\"", with: "")
                            .trimmingCharacters(in: .whitespaces)
                        currentName = rawName
                    }
                }
            }

            // When we hit the closing brace of a dict entry, save the category
            if trimmed.contains("}") || trimmed.contains("),") {
                if let name = currentName {
                    let displayName = spotlightDisplayName(for: name)
                    let enabled = currentEnabled ?? true
                    result.append(SpotlightCategory(name: displayName, enabled: enabled))
                    currentName = nil
                    currentEnabled = nil
                }
            }
        }

        return result
    }

    /// Maps Spotlight's internal category identifiers (e.g. "APPLICATIONS", "MENU_EXPRESSION")
    /// to the human-readable names shown in Snow Leopard's Spotlight preferences.
    private func spotlightDisplayName(for internalName: String) -> String {
        let map: [String: String] = [
            "APPLICATIONS": "Applications",
            "MENU_EXPRESSION": "Calculator",
            "CONTACT": "Contacts",
            "MENU_CONVERSION": "Conversion",
            "MENU_DEFINITION": "Definition",
            "SOURCE": "Developer",
            "DOCUMENTS": "Documents",
            "EVENT_TODO": "Events & To Do's",
            "DIRECTORIES": "Folders",
            "FONTS": "Fonts",
            "IMAGES": "Images",
            "MESSAGES": "Mail Messages",
            "MOVIES": "Movies",
            "MUSIC": "Music",
            "MENU_OTHER": "Other",
            "PDF": "PDF Documents",
            "PRESENTATIONS": "Presentations",
            "SPREADSHEETS": "Spreadsheets",
            "SYSTEM_PREFS": "System Preferences",
            "TIPS": "Tips",
            "BOOKMARKS": "Bookmarks & History",
            "MENU_SPOTLIGHT_SUGGESTIONS": "Spotlight Suggestions",
            "MENU_WEBSEARCH": "Web Searches",
        ]
        return map[internalName] ?? internalName
    }

    /// Provides the default list of Spotlight categories as they appeared in Snow Leopard.
    /// Used when we can't read from the system preferences.
    private func defaultCategories() -> [SpotlightCategory] {
        let names = [
            "Applications",
            "Calculator",
            "Contacts",
            "Conversion",
            "Definition",
            "Developer",
            "Documents",
            "Events & To Do's",
            "Folders",
            "Fonts",
            "Images",
            "Mail Messages",
            "Movies",
            "Music",
            "Other",
            "PDF Documents",
            "Presentations",
            "Spreadsheets",
            "System Preferences",
        ]
        return names.map { SpotlightCategory(name: $0, enabled: true) }
    }

    // MARK: - Load Privacy Exclusions

    /// Reads the list of paths excluded from Spotlight indexing.
    /// Uses `defaults read com.apple.spotlight Exclusions` and also tries to parse
    /// the more modern `ExclusionPaths` key from the Spotlight domain.
    private func loadExcludedPaths() {
        excludedPaths.removeAll()

        // Try reading exclusion paths from Spotlight preferences
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.spotlight", "Exclusions"]) {
            let parsed = parseExclusionPaths(output)
            if !parsed.isEmpty {
                excludedPaths = parsed
                return
            }
        }

        // Also try the newer key name
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.spotlight", "ExclusionPaths"]) {
            let parsed = parseExclusionPaths(output)
            if !parsed.isEmpty {
                excludedPaths = parsed
                return
            }
        }

        // If no exclusions found, leave the list empty — that's normal
    }

    /// Parses the plist-style array of exclusion paths from `defaults read`.
    /// The output is typically a parenthesized list of quoted strings:
    /// ```
    /// (
    ///     "/Volumes/ExternalDrive",
    ///     "/Users/someone/Private"
    /// )
    /// ```
    private func parseExclusionPaths(_ output: String) -> [String] {
        var paths: [String] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip array delimiters and empty lines
            if trimmed == "(" || trimmed == ")" || trimmed.isEmpty { continue }

            // Extract path — may be quoted with trailing comma
            var path = trimmed
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: ",", with: "")
                .trimmingCharacters(in: .whitespaces)

            // Only include entries that look like file paths
            if path.hasPrefix("/") {
                paths.append(path)
            }
        }

        return paths
    }

    // MARK: - Shell Command Helper

    /// Runs a command-line tool and returns its stdout as a string.
    /// Used for `defaults read` to fetch Spotlight preferences from the system.
    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()  // Discard stderr to avoid noise
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Actions

    /// Called when the user clicks the "+" button on the Privacy tab.
    /// Opens a folder picker to let the user choose a directory to exclude from Spotlight.
    /// Note: Actually applying the exclusion requires admin privileges (via `mdutil`),
    /// so we show an informational alert after the folder is chosen.
    @objc private func addPrivacyPath(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose a folder to exclude from Spotlight search:"

        panel.beginSheetModal(for: view.window!) { [weak self] response in
            guard let self = self, response == .OK, let url = panel.url else { return }
            let path = url.path

            // Don't add duplicates
            guard !self.excludedPaths.contains(path) else { return }

            self.excludedPaths.append(path)
            self.privacyTable.reloadData()

            // Show an informational alert — modifying Spotlight exclusions requires admin
            let alert = NSAlert()
            alert.messageText = "Administrator Privileges Required"
            alert.informativeText = "Adding \"\(url.lastPathComponent)\" to the Spotlight privacy list requires administrator privileges. Use System Settings > Siri & Spotlight to manage exclusions with proper authorization."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Called when the user clicks the "-" button on the Privacy tab.
    /// Removes the currently selected path from the exclusion list.
    @objc private func removePrivacyPath(_ sender: NSButton) {
        let selectedRow = privacyTable.selectedRow
        guard selectedRow >= 0, selectedRow < excludedPaths.count else { return }

        excludedPaths.remove(at: selectedRow)
        privacyTable.reloadData()
    }

    /// Called when a checkbox in the category table is clicked.
    /// Toggles the enabled state of the corresponding Spotlight category.
    @objc private func categoryCheckboxToggled(_ sender: NSButton) {
        let row = categoryTable.row(for: sender)
        guard row >= 0, row < categories.count else { return }

        // Toggle the enabled state
        categories[row].enabled = (sender.state == .on)
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension SpotlightPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.tag {
        case 1:
            // Category table (Search Results tab)
            return categories.count
        case 2:
            // Privacy table
            return excludedPaths.count
        default:
            return 0
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let colID = tableColumn?.identifier.rawValue ?? ""

        switch tableView.tag {
        case 1:
            // --- Category table ---
            guard row < categories.count else { return nil }
            let category = categories[row]

            if colID == "check" {
                // Checkbox column — an NSButton configured as a checkbox
                let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(categoryCheckboxToggled(_:)))
                checkbox.state = category.enabled ? .on : .off
                return checkbox
            } else if colID == "name" {
                // Category name label
                let label = NSTextField(labelWithString: category.name)
                label.font = SnowLeopardFonts.label(size: 12)
                label.textColor = NSColor(white: 0.15, alpha: 1.0)
                return label
            }

        case 2:
            // --- Privacy table ---
            guard row < excludedPaths.count else { return nil }
            let path = excludedPaths[row]

            if colID == "path" {
                let label = NSTextField(labelWithString: path)
                label.font = SnowLeopardFonts.label(size: 12)
                label.textColor = NSColor(white: 0.15, alpha: 1.0)
                label.lineBreakMode = .byTruncatingMiddle
                return label
            }

        default:
            break
        }

        return nil
    }
}
