// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

/// ParentalControlsPaneViewController — Snow Leopard "Parental Controls" pane.
///
/// In real Mac OS X Snow Leopard, Parental Controls let parents restrict what
/// their children could do on the Mac. Modern macOS replaced this entirely with
/// Screen Time. This pane bridges the gap: it shows the Snow Leopard UI chrome
/// but reads Screen Time status from the system, and offers a button to open
/// the real Screen Time settings in System Settings.
///
/// Most Screen Time data lives behind private frameworks, so we read what we
/// can from `defaults` and `system_profiler`, and gracefully fall back to
/// "Open Screen Time to view" when the data isn't accessible.
class ParentalControlsPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    /// Unique identifier used by PaneRegistry to look up this pane.
    var paneIdentifier: String { "parentalcontrols" }

    /// Display title shown in the toolbar and grid.
    var paneTitle: String { "Parental Controls" }

    /// SF Symbol icon representing this pane in the grid and toolbar.
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "person.2.badge.gearshape", accessibilityDescription: "Parental Controls") ?? NSImage()
    }

    /// Category grouping — Parental Controls lives under System.
    var paneCategory: PaneCategory { .system }

    /// Preferred window size when this pane is displayed.
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 440) }

    /// Deep-link URL for System Settings (Screen Time replaced Parental Controls).
    var settingsURL: String { "com.apple.Screen-Time-Settings.extension" }

    /// Keywords that let the search bar find this pane.
    var searchKeywords: [String] {
        ["parental controls", "restrictions", "limits", "children", "screen time"]
    }

    /// Returns self since this view controller IS the pane.
    var viewController: NSViewController { self }

    // MARK: - UI Elements

    /// Green/red dot indicating whether Screen Time is enabled.
    private let statusDotView = NSView()

    /// Bold label showing "Screen Time is Enabled" or "Disabled".
    private let statusLabel = NSTextField(labelWithString: "")

    /// Shows which user account is being managed.
    private let managedUserLabel = NSTextField(labelWithString: "")

    /// Shows today's screen time usage or a fallback message.
    private let usageTodayLabel = NSTextField(labelWithString: "")

    /// Most-used app category (if we can read it).
    private let topCategoryLabel = NSTextField(labelWithString: "")

    /// Number of device pickups today (if we can read it).
    private let pickupsLabel = NSTextField(labelWithString: "")

    /// Status labels for the four restriction categories.
    private let downtimeStatusLabel = NSTextField(labelWithString: "")
    private let appLimitsStatusLabel = NSTextField(labelWithString: "")
    private let communicationStatusLabel = NSTextField(labelWithString: "")
    private let contentPrivacyStatusLabel = NSTextField(labelWithString: "")

    // MARK: - Load View

    /// Builds the entire pane UI programmatically — no XIB files.
    /// The layout follows the same pattern as every other Snow Leopard pane:
    /// header, separator, section boxes, and a lock row at the bottom.
    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // The outer stack is the main vertical container for the entire pane.
        // It handles spacing and padding so we don't have to set constraints
        // on every single element individually.
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        // Standard pane header with icon, title, and "Open in System Settings" button.
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

        // --- Info banner ---
        // Explain that Parental Controls was replaced by Screen Time.
        let infoBanner = SnowLeopardPaneHelper.makeLabel(
            "Parental Controls is now Screen Time in macOS. Showing current Screen Time status.",
            size: 11
        )
        infoBanner.textColor = .secondaryLabelColor
        infoBanner.maximumNumberOfLines = 2
        infoBanner.preferredMaxLayoutWidth = 580
        outerStack.addArrangedSubview(infoBanner)

        // ===== Section: Screen Time Status =====
        let statusBox = SnowLeopardPaneHelper.makeSectionBox(title: "Screen Time Status")
        let statusStack = buildStatusSection()
        statusBox.contentView = statusStack
        outerStack.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Usage Summary =====
        let usageBox = SnowLeopardPaneHelper.makeSectionBox(title: "Usage Summary")
        let usageStack = buildUsageSection()
        usageBox.contentView = usageStack
        outerStack.addArrangedSubview(usageBox)
        usageBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Restrictions =====
        let restrictionsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Restrictions")
        let restrictionsStack = buildRestrictionsSection()
        restrictionsBox.contentView = restrictionsStack
        outerStack.addArrangedSubview(restrictionsBox)
        restrictionsBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Open Screen Time Button =====
        // A prominent button that opens the real Screen Time settings.
        let openButtonRow = NSStackView()
        openButtonRow.orientation = .horizontal
        openButtonRow.alignment = .centerY
        openButtonRow.spacing = 0

        // Spacer pushes the button to the right side.
        let buttonSpacer = NSView()
        buttonSpacer.translatesAutoresizingMaskIntoConstraints = false
        buttonSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let openButton = NSButton(title: "Open Screen Time...", target: self, action: #selector(openScreenTimeSettings))
        openButton.bezelStyle = .rounded
        openButton.font = SnowLeopardFonts.boldLabel(size: 11)

        openButtonRow.addArrangedSubview(buttonSpacer)
        openButtonRow.addArrangedSubview(openButton)

        outerStack.addArrangedSubview(openButtonRow)
        openButtonRow.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Lock Icon Row =====
        // Matches the Snow Leopard convention: a small lock icon with
        // instructional text at the bottom of the pane.
        let lockRow = NSStackView()
        lockRow.orientation = .horizontal
        lockRow.alignment = .centerY
        lockRow.spacing = 6

        let lockIcon = NSImageView()
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        if let lockImage = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Lock") {
            lockIcon.image = lockImage
            lockIcon.contentTintColor = NSColor(white: 0.45, alpha: 1.0)
        }
        lockIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        lockIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let lockLabel = SnowLeopardPaneHelper.makeLabel("Click the lock to prevent further changes.", size: 10)
        lockLabel.textColor = NSColor(white: 0.45, alpha: 1.0)

        lockRow.addArrangedSubview(lockIcon)
        lockRow.addArrangedSubview(lockLabel)

        outerStack.addArrangedSubview(lockRow)

        // Pin the outer stack to the root view edges.
        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Section Builders

    /// Builds the Screen Time Status section content.
    /// Contains a green/red status dot, a bold enabled/disabled label,
    /// and the name of the user being managed.
    private func buildStatusSection() -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Status dot + label row (same pattern as Network/Bluetooth panes).
        // The dot is a tiny 10x10 circle that changes color based on status.
        statusDotView.translatesAutoresizingMaskIntoConstraints = false
        statusDotView.wantsLayer = true
        statusDotView.layer?.cornerRadius = 5
        statusDotView.layer?.backgroundColor = NSColor.systemGray.cgColor
        statusDotView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        statusDotView.heightAnchor.constraint(equalToConstant: 10).isActive = true

        statusLabel.font = SnowLeopardFonts.boldLabel(size: 11)
        statusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let statusRow = NSStackView(views: [statusDotView, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .centerY
        stack.addArrangedSubview(statusRow)

        // Managed user row — shows which account Screen Time is monitoring.
        managedUserLabel.font = SnowLeopardFonts.label(size: 11)
        managedUserLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let userRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Managed User:"),
            controls: [managedUserLabel]
        )
        stack.addArrangedSubview(userRow)

        return stack
    }

    /// Builds the Usage Summary section content.
    /// Shows today's screen time, top app category, and pickup count.
    /// Most of this data is behind private APIs, so we show fallback text
    /// when we can't read it.
    private func buildUsageSection() -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Today's Screen Time row
        usageTodayLabel.font = SnowLeopardFonts.label(size: 11)
        usageTodayLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let todayRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Today's Screen Time:"),
            controls: [usageTodayLabel]
        )
        stack.addArrangedSubview(todayRow)

        // Most used category row
        topCategoryLabel.font = SnowLeopardFonts.label(size: 11)
        topCategoryLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let categoryRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Top Category:"),
            controls: [topCategoryLabel]
        )
        stack.addArrangedSubview(categoryRow)

        // Pickups row
        pickupsLabel.font = SnowLeopardFonts.label(size: 11)
        pickupsLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let pickupsRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Pickups:"),
            controls: [pickupsLabel]
        )
        stack.addArrangedSubview(pickupsRow)

        return stack
    }

    /// Builds the Restrictions section content.
    /// Shows the status of four Screen Time restriction categories:
    /// Downtime, App Limits, Communication Limits, Content & Privacy.
    /// Each is a simple label + status text row.
    private func buildRestrictionsSection() -> NSStackView {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Style all status labels with the standard font and color.
        let allStatusLabels = [downtimeStatusLabel, appLimitsStatusLabel,
                               communicationStatusLabel, contentPrivacyStatusLabel]
        for label in allStatusLabels {
            label.font = SnowLeopardFonts.label(size: 11)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
        }

        // Downtime — whether a scheduled downtime is configured.
        let downtimeRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Downtime:"),
            controls: [downtimeStatusLabel]
        )
        stack.addArrangedSubview(downtimeRow)

        // App Limits — number of active limits or "None".
        let appLimitsRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("App Limits:"),
            controls: [appLimitsStatusLabel]
        )
        stack.addArrangedSubview(appLimitsRow)

        // Communication Limits — whether limits are configured.
        let commRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Communication Limits:"),
            controls: [communicationStatusLabel]
        )
        stack.addArrangedSubview(commRow)

        // Content & Privacy Restrictions — enabled or disabled.
        let contentRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Content & Privacy:"),
            controls: [contentPrivacyStatusLabel]
        )
        stack.addArrangedSubview(contentRow)

        return stack
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    /// Reads Screen Time state from the system and updates all UI labels.
    /// Screen Time data is mostly locked behind private frameworks, so we
    /// attempt to read what's available via `defaults` and fall back to
    /// friendly messages when the data isn't accessible.
    func reloadFromSystem() {
        // --- Screen Time Status ---
        let screenTimeEnabled = readScreenTimeEnabled()

        if screenTimeEnabled {
            statusDotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
            statusLabel.stringValue = "Screen Time is Enabled"
        } else {
            statusDotView.layer?.backgroundColor = NSColor.systemRed.cgColor
            statusLabel.stringValue = "Screen Time is Disabled"
        }

        // Show the current macOS username as the managed user.
        managedUserLabel.stringValue = NSFullUserName()

        // --- Usage Summary ---
        // Screen Time usage data is stored in a private SQLite database
        // (~/Library/Application Support/Knowledge/) and is not exposed
        // via public defaults. We show a fallback message directing the
        // user to open Screen Time for detailed data.
        usageTodayLabel.stringValue = "Open Screen Time to view"
        topCategoryLabel.stringValue = "Open Screen Time to view"
        pickupsLabel.stringValue = "N/A (desktop Mac)"

        // --- Restrictions ---
        // Attempt to read restriction states from Screen Time defaults.
        // These keys may not exist if Screen Time hasn't been configured.
        let downtimeEnabled = readDefaultsBool(key: "DowntimeEnabled")
        downtimeStatusLabel.stringValue = downtimeEnabled ? "Scheduled" : "Not Scheduled"

        let appLimitsEnabled = readDefaultsBool(key: "AppLimitsEnabled")
        appLimitsStatusLabel.stringValue = appLimitsEnabled ? "Active" : "None"

        let commLimitsEnabled = readDefaultsBool(key: "CommunicationLimitsEnabled")
        communicationStatusLabel.stringValue = commLimitsEnabled ? "Configured" : "None"

        let contentPrivacyEnabled = readDefaultsBool(key: "ContentPrivacyEnabled")
        contentPrivacyStatusLabel.stringValue = contentPrivacyEnabled ? "Enabled" : "Disabled"
    }

    // MARK: - System Reading Helpers

    /// Checks whether Screen Time is enabled by reading the ScreenTimeAgent
    /// defaults domain. Screen Time stores its enabled state here.
    /// Returns true if Screen Time appears to be active, false otherwise.
    private func readScreenTimeEnabled() -> Bool {
        // Try reading from the ScreenTimeAgent preferences.
        // The "ScreenTimeEnabled" key is set to 1 when Screen Time is on.
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.ScreenTimeAgent", "ScreenTimeEnabled"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "1" { return true }
            if trimmed == "0" { return false }
        }

        // Fallback: check if the ScreenTimeAgent process is running.
        // If the agent is active, Screen Time is likely enabled.
        if let output = runCommand("/bin/ps", arguments: ["-ax"]) {
            if output.contains("ScreenTimeAgent") {
                return true
            }
        }

        return false
    }

    /// Reads a boolean value from Screen Time defaults.
    /// Screen Time stores restriction flags in the com.apple.ScreenTimeAgent
    /// domain. If the key doesn't exist or can't be read, returns false.
    ///
    /// - Parameter key: The defaults key to read (e.g. "DowntimeEnabled").
    /// - Returns: true if the key's value is "1", false otherwise.
    private func readDefaultsBool(key: String) -> Bool {
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "com.apple.ScreenTimeAgent", key]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == "1"
        }
        return false
    }

    /// Runs a shell command and returns its stdout as a string.
    /// This is used throughout the pane to call `defaults`, `ps`, etc.
    ///
    /// - Parameters:
    ///   - path: Full path to the executable (e.g. "/usr/bin/defaults").
    ///   - arguments: Command-line arguments to pass.
    /// - Returns: The command's standard output as a string, or nil on failure.
    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        // Capture stderr separately so it doesn't pollute our output.
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

    // MARK: - Actions

    /// Opens Screen Time in System Settings when the user clicks
    /// "Open Screen Time..." button.
    @objc private func openScreenTimeSettings() {
        SystemSettingsLauncher.open(url: settingsURL)
    }
}
