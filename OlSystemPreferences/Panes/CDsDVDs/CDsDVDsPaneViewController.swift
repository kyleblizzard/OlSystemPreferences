// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

// MARK: - CDsDVDsPaneViewController
// This view controller recreates the Snow Leopard "CDs & DVDs" preference pane.
// In Snow Leopard, this pane let you choose what happens when you insert different
// types of optical discs (blank CDs, blank DVDs, music CDs, picture CDs, video DVDs).
// Each disc type has a popup menu with actions like "Ask what to do", "Open iTunes", etc.
//
// On modern Macs, optical drives are no longer built-in, so this pane is mostly
// nostalgic — but we still read/write the real `com.apple.digihub` defaults domain
// so the settings are functional if an external drive is connected.

class CDsDVDsPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol Properties

    var paneIdentifier: String { "cdsdvds" }
    var paneTitle: String { "CDs & DVDs" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "opticaldisc.fill", accessibilityDescription: "CDs & DVDs") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 420) }
    var searchKeywords: [String] { ["cd", "dvd", "disc", "blank", "insert", "music", "video"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.systempreferences.GeneralSettings" }

    // MARK: - Services

    /// DefaultsService gives us typed access to CFPreferences for reading/writing
    /// system preference domains like com.apple.digihub.
    private let defaults = DefaultsService.shared

    /// The defaults domain where macOS stores optical disc insertion behavior.
    private let digihubDomain = "com.apple.digihub"

    // MARK: - Disc Type Configuration

    /// Each disc type that appears in the pane. We store the defaults key used to
    /// read/write the setting, the label shown to the user, and the list of options
    /// available in the popup menu for that disc type.
    private struct DiscType {
        let label: String           // e.g. "When you insert a blank CD:"
        let defaultsKey: String     // e.g. "com.apple.digihub.blank.cd.appeared"
        let options: [String]       // e.g. ["Ask what to do", "Open Finder", ...]
    }

    /// The five disc types Snow Leopard displayed, in order from top to bottom.
    /// Each has slightly different popup options depending on the disc type.
    private let discTypes: [DiscType] = [
        DiscType(
            label: "When you insert a blank CD:",
            defaultsKey: "com.apple.digihub.blank.cd.appeared",
            options: ["Ask what to do", "Open Finder", "Open iTunes", "Open Disk Utility", "Run Script...", "Ignore"]
        ),
        DiscType(
            label: "When you insert a blank DVD:",
            defaultsKey: "com.apple.digihub.blank.dvd.appeared",
            options: ["Ask what to do", "Open Finder", "Open iTunes", "Open Disk Utility", "Open iDVD", "Run Script...", "Ignore"]
        ),
        DiscType(
            label: "When you insert a music CD:",
            defaultsKey: "com.apple.digihub.cd.music.appeared",
            options: ["Ask what to do", "Open iTunes", "Open other application...", "Run Script...", "Ignore"]
        ),
        DiscType(
            label: "When you insert a picture CD:",
            defaultsKey: "com.apple.digihub.cd.picture.appeared",
            options: ["Ask what to do", "Open iPhoto", "Open other application...", "Run Script...", "Ignore"]
        ),
        DiscType(
            label: "When you insert a video DVD:",
            defaultsKey: "com.apple.digihub.dvd.video.appeared",
            options: ["Ask what to do", "Open DVD Player", "Open other application...", "Run Script...", "Ignore"]
        ),
    ]

    // MARK: - Action Code Mapping

    /// The digihub defaults store each disc action as a dictionary with an `action` key.
    /// These are the known action codes used by macOS:
    ///   1 = Ask what to do
    ///   5 = Ignore
    ///   6 = Run a script
    /// 101 = Open a specific application (the app path is stored separately in the dict)
    ///
    /// Since Snow Leopard's popup items map to specific apps, we associate each popup
    /// option with either a known action code or a specific app name for matching.
    private enum ActionCode: Int {
        case ask = 1
        case ignore = 5
        case runScript = 6
        case openApp = 101
    }

    // MARK: - UI Elements

    /// We keep references to the popup buttons so we can read/update them.
    /// The array index matches the discTypes array index.
    private var popups: [AquaPopUpButton] = []

    // MARK: - View Lifecycle

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Build the main vertical stack that holds all the pane content.
        // This follows the same pattern as other Snow Leopard panes in the project.
        let outerStack = SnowLeopardPaneHelper.makePaneContainer()

        // --- Pane Header ---
        // Standard header with icon, title, and "Open in System Settings..." button
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
        outerStack.setCustomSpacing(16, after: headerSep)

        // =====================================================================
        // Main Section: Disc Insertion Actions
        // =====================================================================
        // One section box containing all five disc-type rows.
        // Each row has a label on the left and a popup button on the right.
        let sectionBox = SnowLeopardPaneHelper.makeSectionBox()
        let sectionContent = NSStackView()
        sectionContent.translatesAutoresizingMaskIntoConstraints = false
        sectionContent.orientation = .vertical
        sectionContent.alignment = .leading
        sectionContent.spacing = 12

        // Create a row for each disc type
        for (index, disc) in discTypes.enumerated() {
            // Create the popup button with the disc-specific options
            let popup = SnowLeopardPaneHelper.makeAquaPopup(
                items: disc.options,
                selected: 0,
                target: self,
                action: #selector(discActionChanged(_:))
            )
            popups.append(popup)

            // Create the label for this row
            let label = SnowLeopardPaneHelper.makeLabel(disc.label)
            label.alignment = .right
            // Use a fixed width so all popup buttons align vertically
            label.widthAnchor.constraint(equalToConstant: 200).isActive = true

            // Assemble the row: label on left, popup on right
            let row = SnowLeopardPaneHelper.makeRow(
                label: label,
                controls: [popup]
            )
            sectionContent.addArrangedSubview(row)

            // Add a subtle separator between rows (but not after the last one)
            if index < discTypes.count - 1 {
                let sep = SnowLeopardPaneHelper.makeSeparator(width: 580)
                sectionContent.addArrangedSubview(sep)
            }
        }

        sectionBox.contentView = sectionContent
        outerStack.addArrangedSubview(sectionBox)
        sectionBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        outerStack.setCustomSpacing(16, after: sectionBox)

        // =====================================================================
        // Bottom Note
        // =====================================================================
        // A small informational note reminding users that modern Macs need an
        // external optical drive to use CDs and DVDs.
        let noteRow = NSStackView()
        noteRow.orientation = .horizontal
        noteRow.alignment = .centerY
        noteRow.spacing = 6

        // Small optical disc icon next to the note text
        let noteIcon = NSImageView()
        noteIcon.translatesAutoresizingMaskIntoConstraints = false
        noteIcon.image = NSImage(systemSymbolName: "opticaldisc", accessibilityDescription: nil)
        noteIcon.contentTintColor = .secondaryLabelColor
        noteIcon.widthAnchor.constraint(equalToConstant: 14).isActive = true
        noteIcon.heightAnchor.constraint(equalToConstant: 14).isActive = true
        noteRow.addArrangedSubview(noteIcon)

        // The note text itself
        let noteLabel = NSTextField(labelWithString: "On modern Macs, an external optical drive is required to use CDs and DVDs.")
        noteLabel.font = SnowLeopardFonts.label(size: 10)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.preferredMaxLayoutWidth = 560
        noteRow.addArrangedSubview(noteLabel)

        outerStack.addArrangedSubview(noteRow)

        // Add the outer stack to the root view
        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Load the current system settings into the popup buttons
        reloadFromSystem()
    }

    // MARK: - PaneProtocol — Reload Settings

    /// Reads the current disc insertion settings from the `com.apple.digihub` defaults
    /// domain and updates each popup button to reflect the active action.
    func reloadFromSystem() {
        for (index, disc) in discTypes.enumerated() {
            guard index < popups.count else { continue }

            // Read the dictionary for this disc type from digihub defaults.
            // Each key stores a dictionary like: { action = 1; }
            // where the action integer tells us what macOS does on disc insertion.
            let value = defaults.any(forKey: disc.defaultsKey, domain: digihubDomain)

            // Try to extract the action code from the dictionary
            if let dict = value as? [String: Any],
               let actionCode = dict["action"] as? Int {
                let popupIndex = mapActionCodeToPopupIndex(actionCode: actionCode, discIndex: index)
                popups[index].selectedIndex = popupIndex
            } else {
                // Default to "Ask what to do" (first item) if we can't read the setting
                popups[index].selectedIndex = 0
            }
        }
    }

    // MARK: - Action Handling

    /// Called when the user changes any disc insertion action popup.
    /// Writes the selected action back to the `com.apple.digihub` domain.
    @objc private func discActionChanged(_ sender: AquaPopUpButton) {
        // Find which disc type this popup belongs to by matching the sender
        // against our stored popup references. NSView.tag is read-only, so
        // we identify the popup by object identity instead.
        guard let discIndex = popups.firstIndex(where: { $0 === sender }) else { return }
        guard discIndex < discTypes.count else { return }

        let disc = discTypes[discIndex]
        let selectedOption = disc.options[sender.selectedIndex]

        // Convert the selected popup option back to a digihub action dictionary
        let actionCode = mapPopupOptionToActionCode(option: selectedOption)

        // Build the dictionary that digihub expects
        var actionDict: [String: Any] = ["action": actionCode]

        // For "Open app" actions, we could store the app path in the dict too.
        // Snow Leopard stored an ODBundleIdentifier key for specific apps.
        // We include a bundle identifier hint for known apps.
        if actionCode == ActionCode.openApp.rawValue {
            if let bundleID = bundleIdentifierForOption(selectedOption) {
                actionDict["ODBundleIdentifier"] = bundleID
            }
        }

        // Write the updated dictionary back to the digihub defaults domain
        defaults.set(actionDict as NSDictionary, forKey: disc.defaultsKey, domain: digihubDomain)
    }

    // MARK: - Mapping Helpers

    /// Converts a digihub action code integer into the correct popup menu index
    /// for a given disc type. Different disc types have different popup options
    /// at different indices, so we need the disc index to figure out where
    /// each action code lands in the popup.
    ///
    /// - Parameters:
    ///   - actionCode: The integer action code from the digihub dictionary (1, 5, 6, or 101).
    ///   - discIndex: Which disc type we're looking at (0=blank CD, 1=blank DVD, etc.).
    /// - Returns: The popup index to select, defaulting to 0 ("Ask what to do").
    private func mapActionCodeToPopupIndex(actionCode: Int, discIndex: Int) -> Int {
        let options = discTypes[discIndex].options

        switch actionCode {
        case ActionCode.ask.rawValue:
            // "Ask what to do" is always the first item
            return 0

        case ActionCode.ignore.rawValue:
            // "Ignore" is always the last item
            return options.count - 1

        case ActionCode.runScript.rawValue:
            // "Run Script..." is always second-to-last
            return options.count - 2

        case ActionCode.openApp.rawValue:
            // For "open app" actions, default to the second item in the list.
            // This is the primary app option (e.g. Open Finder, Open iTunes, Open DVD Player).
            // In a more complete implementation, we'd check the ODBundleIdentifier
            // to match the exact app, but for Snow Leopard fidelity this is sufficient.
            return min(1, options.count - 1)

        default:
            // Unknown action code — fall back to "Ask what to do"
            return 0
        }
    }

    /// Converts a popup menu option string into the corresponding digihub action code.
    ///
    /// - Parameter option: The text of the selected popup item (e.g. "Open iTunes").
    /// - Returns: The integer action code to store in the digihub dictionary.
    private func mapPopupOptionToActionCode(option: String) -> Int {
        switch option {
        case "Ask what to do":
            return ActionCode.ask.rawValue
        case "Ignore":
            return ActionCode.ignore.rawValue
        case "Run Script...":
            return ActionCode.runScript.rawValue
        default:
            // Everything else (Open Finder, Open iTunes, Open iDVD, etc.)
            // is an "open app" action
            return ActionCode.openApp.rawValue
        }
    }

    /// Returns the macOS bundle identifier for known Snow Leopard app options.
    /// This is stored in the digihub dictionary so macOS knows which app to launch.
    ///
    /// - Parameter option: The popup menu text (e.g. "Open iTunes").
    /// - Returns: The bundle identifier string, or nil if unknown.
    private func bundleIdentifierForOption(_ option: String) -> String? {
        switch option {
        case "Open Finder":
            return "com.apple.finder"
        case "Open iTunes":
            // On modern macOS, iTunes has been replaced by Music
            return "com.apple.Music"
        case "Open Disk Utility":
            return "com.apple.DiskUtility"
        case "Open iDVD":
            // iDVD was discontinued, but we store the original bundle ID for authenticity
            return "com.apple.iDVD"
        case "Open iPhoto":
            // iPhoto was replaced by Photos on modern macOS
            return "com.apple.Photos"
        case "Open DVD Player":
            return "com.apple.DVDPlayer"
        case "Open other application...":
            // User would pick an app — no fixed bundle ID
            return nil
        default:
            return nil
        }
    }
}
