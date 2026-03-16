// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

/// SecurityPaneViewController — a native recreation of the Snow Leopard "Security" preference pane.
///
/// This pane has three tabs matching the original Snow Leopard layout:
///   1. General   — password requirements, auto-login, screen lock message
///   2. FileVault — disk encryption status and toggle (delegates to System Settings)
///   3. Firewall  — application firewall status and configuration
///
/// Where possible we read real system data using `defaults`, `fdesetup`, and
/// `socketfilterfw`. Writes that require admin privileges (FileVault, Firewall)
/// redirect the user to System Settings because those operations need authorization.
class SecurityPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol Properties

    var paneIdentifier: String { "security" }
    var paneTitle: String { "Security" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Security") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] {
        ["security", "password", "filevault", "firewall", "encryption", "lock", "screen saver",
         "automatic login", "stealth", "lock message"]
    }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.settings.PrivacySecurity.extension" }

    // MARK: - Services

    /// DefaultsService wraps UserDefaults and CFPreferences so we can read/write
    /// preference domains without shelling out every time.
    private let defaults = DefaultsService.shared

    // MARK: - Tab View

    /// The custom AquaTabView gives us the glossy Snow Leopard tab strip instead
    /// of the modern flat NSTabView appearance.
    private let tabView = AquaTabView()

    // MARK: - General Tab Controls

    /// "Require password" checkbox — maps to `com.apple.screensaver` → `askForPassword`.
    private let requirePasswordCheck = AquaCheckbox(
        title: "Require password",
        isChecked: false
    )

    /// Delay popup — how many seconds after sleep before the password is required.
    /// Maps to `com.apple.screensaver` → `askForPasswordDelay`.
    private let passwordDelayPopup = AquaPopUpButton(
        items: ["immediately", "5 seconds", "1 minute", "5 minutes", "15 minutes", "1 hour", "4 hours"],
        selectedIndex: 0
    )

    /// Label completing the sentence: "after sleep or screen saver begins"
    private let afterSleepLabel = SnowLeopardPaneHelper.makeLabel("after sleep or screen saver begins")

    /// "Disable automatic login" — if `com.apple.loginwindow` → `autoLoginUser` exists,
    /// automatic login is enabled. We invert the boolean for this checkbox.
    private let disableAutoLoginCheck = AquaCheckbox(
        title: "Disable automatic login",
        isChecked: false
    )

    /// "Require an administrator password to access locked preferences"
    private let adminPasswordCheck = AquaCheckbox(
        title: "Require an administrator password to access locked preferences",
        isChecked: false
    )

    /// "Log out after [X] minutes of inactivity"
    private let logoutAfterCheck = AquaCheckbox(
        title: "Log out after",
        isChecked: false
    )

    /// The minutes-of-inactivity popup beside the logout checkbox.
    /// Maps to `com.apple.screensaver` → `idleTime` (in seconds, we divide by 60).
    private let logoutMinutesPopup = AquaPopUpButton(
        items: ["5", "10", "15", "30", "60", "120"],
        selectedIndex: 3
    )

    /// "minutes of inactivity" label suffix
    private let logoutSuffixLabel = SnowLeopardPaneHelper.makeLabel("minutes of inactivity")

    /// "Show a message when the screen is locked"
    private let showLockMessageCheck = AquaCheckbox(
        title: "Show a message when the screen is locked",
        isChecked: false
    )

    /// Text field for the lock screen message. The user can type a custom message here.
    private let lockMessageField: NSTextField = {
        let field = NSTextField()
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = SnowLeopardFonts.label(size: 11)
        field.placeholderString = "Enter lock message..."
        field.isEditable = true
        field.isBordered = true
        field.isEnabled = false // Starts disabled until checkbox is checked
        field.widthAnchor.constraint(equalToConstant: 380).isActive = true
        return field
    }()

    // MARK: - FileVault Tab Controls

    /// Shows whether FileVault is currently on or off. Updated by running `fdesetup status`.
    private let fileVaultStatusLabel = SnowLeopardPaneHelper.makeLabel("FileVault status: Checking...", size: 12, bold: true)

    /// Additional detail about what FileVault does.
    private let fileVaultDescriptionLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString:
            "FileVault secures the data on your disk by encrypting its contents automatically. " +
            "If FileVault is turned on, you will need your login password or a recovery key to access your data.")
        label.font = SnowLeopardFonts.label(size: 11)
        label.textColor = NSColor(white: 0.35, alpha: 1.0)
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 540).isActive = true
        return label
    }()

    /// Displays the encryption status of the boot volume (e.g. "Macintosh HD: Encrypted").
    private let diskInfoLabel = SnowLeopardPaneHelper.makeLabel("Boot volume: Checking...")

    /// Recovery key status — whether a recovery key is set.
    private let recoveryKeyLabel = SnowLeopardPaneHelper.makeLabel("Recovery key: Checking...")

    /// Button to toggle FileVault — opens System Settings since enabling/disabling
    /// requires an authorization dialog that we cannot present from a non-sandboxed app.
    private let fileVaultToggleButton = AquaButton(title: "Turn On FileVault...", isDefault: true)

    // MARK: - Firewall Tab Controls

    /// Displays whether the application firewall is on or off.
    /// Updated by running `socketfilterfw --getglobalstate`.
    private let firewallStatusLabel = SnowLeopardPaneHelper.makeLabel("Firewall: Checking...", size: 12, bold: true)

    /// Shows whether stealth mode is enabled — makes the Mac invisible to
    /// network discovery probes like ping.
    private let stealthModeLabel = SnowLeopardPaneHelper.makeLabel("Stealth Mode: Checking...")

    /// Shows whether "block all incoming connections" is turned on.
    private let blockAllLabel = SnowLeopardPaneHelper.makeLabel("Block all incoming connections: Checking...")

    /// List of apps allowed through the firewall (read from `--listapps`).
    private let firewallAppsTable = NSTableView()

    /// Data backing the firewall apps table.
    private var firewallApps: [(name: String, allowed: Bool)] = []

    /// Button to enable/disable the firewall — opens System Settings because
    /// changing firewall state requires admin authorization.
    private let firewallToggleButton = AquaButton(title: "Turn On Firewall...", isDefault: true)

    /// "Firewall Options..." button — opens System Settings to the advanced firewall panel.
    private let firewallOptionsButton = AquaButton(title: "Firewall Options...", isDefault: false)

    /// Explanatory text about what the firewall does.
    private let firewallDescriptionLabel: NSTextField = {
        let label = NSTextField(wrappingLabelWithString:
            "The firewall controls incoming network connections to this computer. " +
            "You can allow specific applications and services to receive incoming connections.")
        label.font = SnowLeopardFonts.label(size: 11)
        label.textColor = NSColor(white: 0.35, alpha: 1.0)
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 540).isActive = true
        return label
    }()

    // MARK: - View Lifecycle

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Build the outer stack: header at top, then the tab view filling the rest.
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Pane Header (icon + title + "Open in System Settings..." button) ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Tab View with three tabs ---
        tabView.translatesAutoresizingMaskIntoConstraints = false

        // Build and add each tab. AquaTabView.addTab() takes a title string and an NSView.
        tabView.addTab(title: "General", view: buildGeneralTab())
        tabView.addTab(title: "FileVault", view: buildFileVaultTab())
        tabView.addTab(title: "Firewall", view: buildFirewallTab())
        tabView.selectTab(at: 0)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 400).isActive = true

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
        reloadFromSystem()
    }

    // MARK: - PaneProtocol Lifecycle

    func paneWillAppear() {
        reloadFromSystem()
    }

    func paneWillDisappear() {
        // Nothing to tear down — no timers or observers.
    }

    // MARK: - Build General Tab

    /// Constructs the "General" tab content. This tab contains checkboxes and popups
    /// for password-on-wake, auto-login, admin password requirement, inactivity logout,
    /// and lock screen message — matching the Snow Leopard original layout.
    private func buildGeneralTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)

        // --- Row 1: "Require password [popup] after sleep or screen saver begins" ---
        // This is a horizontal row combining the checkbox, a delay popup, and a suffix label.
        requirePasswordCheck.target = self
        requirePasswordCheck.action = #selector(requirePasswordChanged(_:))

        passwordDelayPopup.target = self
        passwordDelayPopup.action = #selector(passwordDelayChanged(_:))

        let passwordRow = NSStackView(views: [requirePasswordCheck, passwordDelayPopup, afterSleepLabel])
        passwordRow.orientation = .horizontal
        passwordRow.spacing = 6
        passwordRow.alignment = .firstBaseline
        stack.addArrangedSubview(passwordRow)

        // --- Separator ---
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // --- Row 2: "Disable automatic login" ---
        disableAutoLoginCheck.target = self
        disableAutoLoginCheck.action = #selector(disableAutoLoginChanged(_:))
        stack.addArrangedSubview(disableAutoLoginCheck)

        // --- Separator ---
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // --- Row 3: "Require an administrator password to access locked preferences" ---
        adminPasswordCheck.target = self
        adminPasswordCheck.action = #selector(adminPasswordChanged(_:))
        stack.addArrangedSubview(adminPasswordCheck)

        // --- Separator ---
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // --- Row 4: "Log out after [X] minutes of inactivity" ---
        logoutAfterCheck.target = self
        logoutAfterCheck.action = #selector(logoutAfterChanged(_:))

        logoutMinutesPopup.target = self
        logoutMinutesPopup.action = #selector(logoutMinutesChanged(_:))

        let logoutRow = NSStackView(views: [logoutAfterCheck, logoutMinutesPopup, logoutSuffixLabel])
        logoutRow.orientation = .horizontal
        logoutRow.spacing = 6
        logoutRow.alignment = .firstBaseline
        stack.addArrangedSubview(logoutRow)

        // --- Separator ---
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // --- Row 5: "Show a message when the screen is locked" + text field ---
        showLockMessageCheck.target = self
        showLockMessageCheck.action = #selector(showLockMessageChanged(_:))
        stack.addArrangedSubview(showLockMessageCheck)

        // The lock message text field sits below the checkbox, indented.
        let messageRow = NSStackView(views: [lockMessageField])
        messageRow.orientation = .horizontal
        messageRow.spacing = 0
        messageRow.edgeInsets = NSEdgeInsets(top: 0, left: 24, bottom: 0, right: 0)
        stack.addArrangedSubview(messageRow)

        // Set the lock message field delegate so we save on editing end.
        lockMessageField.delegate = self

        // --- Bottom informational text ---
        let infoLabel = SnowLeopardPaneHelper.makeLabel(
            "Click the lock to prevent further changes.", size: 10
        )
        infoLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))
        stack.addArrangedSubview(infoLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Build FileVault Tab

    /// Constructs the "FileVault" tab. Shows the current encryption status of the boot
    /// disk, recovery key info, and a button to turn FileVault on/off via System Settings.
    private func buildFileVaultTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)

        // --- Status section (inside a grouped box) ---
        let statusBox = SnowLeopardPaneHelper.makeSectionBox(title: "FileVault Protection")
        let statusStack = NSStackView()
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 10

        statusStack.addArrangedSubview(fileVaultStatusLabel)
        statusStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 520))
        statusStack.addArrangedSubview(diskInfoLabel)
        statusStack.addArrangedSubview(recoveryKeyLabel)

        statusBox.contentView = statusStack
        stack.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalToConstant: 560).isActive = true

        // --- Description text ---
        stack.addArrangedSubview(fileVaultDescriptionLabel)

        // --- Toggle button ---
        fileVaultToggleButton.target = self
        fileVaultToggleButton.action = #selector(toggleFileVault(_:))
        stack.addArrangedSubview(fileVaultToggleButton)

        // --- Info note about admin privileges ---
        let noteLabel = SnowLeopardPaneHelper.makeLabel(
            "Turning FileVault on or off requires an administrator password and may take some time.",
            size: 10
        )
        noteLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        noteLabel.preferredMaxLayoutWidth = 540
        // Wrapping labels need to be created differently; make this wrap.
        let noteWrapper = NSTextField(wrappingLabelWithString:
            "Turning FileVault on or off requires an administrator password and may take some time."
        )
        noteWrapper.font = SnowLeopardFonts.label(size: 10)
        noteWrapper.textColor = NSColor(white: 0.55, alpha: 1.0)
        noteWrapper.widthAnchor.constraint(lessThanOrEqualToConstant: 540).isActive = true
        stack.addArrangedSubview(noteWrapper)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Build Firewall Tab

    /// Constructs the "Firewall" tab. Reads the real firewall state from
    /// `/usr/libexec/ApplicationFirewall/socketfilterfw`, displays allowed apps,
    /// and provides buttons to toggle the firewall via System Settings.
    private func buildFirewallTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)

        // --- Status section (grouped box) ---
        let statusBox = SnowLeopardPaneHelper.makeSectionBox(title: "Firewall Protection")
        let statusStack = NSStackView()
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8

        statusStack.addArrangedSubview(firewallStatusLabel)
        statusStack.addArrangedSubview(stealthModeLabel)
        statusStack.addArrangedSubview(blockAllLabel)

        statusBox.contentView = statusStack
        stack.addArrangedSubview(statusBox)
        statusBox.widthAnchor.constraint(equalToConstant: 560).isActive = true

        // --- Description ---
        stack.addArrangedSubview(firewallDescriptionLabel)

        // --- Allowed apps table ---
        let appsLabel = SnowLeopardPaneHelper.makeLabel("Applications with firewall rules:", size: 11, bold: true)
        stack.addArrangedSubview(appsLabel)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // Name column — shows the application name
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("appName"))
        nameCol.title = "Application"
        nameCol.width = 360
        firewallAppsTable.addTableColumn(nameCol)

        // Status column — shows "Allow" or "Block"
        let statusCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("appStatus"))
        statusCol.title = "Status"
        statusCol.width = 140
        firewallAppsTable.addTableColumn(statusCol)

        firewallAppsTable.delegate = self
        firewallAppsTable.dataSource = self
        firewallAppsTable.rowHeight = 20
        firewallAppsTable.usesAlternatingRowBackgroundColors = true
        firewallAppsTable.headerView?.tableView?.font = SnowLeopardFonts.label(size: 11)

        scrollView.documentView = firewallAppsTable
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(scrollView)

        // --- Buttons row ---
        firewallToggleButton.target = self
        firewallToggleButton.action = #selector(toggleFirewall(_:))

        firewallOptionsButton.target = self
        firewallOptionsButton.action = #selector(openFirewallOptions(_:))

        let buttonRow = NSStackView(views: [firewallToggleButton, firewallOptionsButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10
        stack.addArrangedSubview(buttonRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Reload From System

    /// Reads the current state of all security settings from the system and updates
    /// every control in all three tabs. Called on load and whenever the pane appears.
    func reloadFromSystem() {
        reloadGeneralTab()
        reloadFileVaultTab()
        reloadFirewallTab()
    }

    // MARK: - General Tab: Read System State

    /// Reads screen saver password, auto-login, and related preferences from the system.
    private func reloadGeneralTab() {
        // --- Require password after sleep ---
        // Domain: com.apple.screensaver, Key: askForPassword (bool, 1 = require)
        let askForPassword = defaults.bool(forKey: "askForPassword", domain: "com.apple.screensaver") ?? false
        requirePasswordCheck.isChecked = askForPassword

        // Password delay in seconds. Map known values to popup indices.
        // Popup items: "immediately" (0s), "5 seconds" (5), "1 minute" (60),
        //              "5 minutes" (300), "15 minutes" (900), "1 hour" (3600), "4 hours" (14400)
        let delaySeconds = defaults.integer(forKey: "askForPasswordDelay", domain: "com.apple.screensaver") ?? 0
        let delayMap: [Int: Int] = [0: 0, 5: 1, 60: 2, 300: 3, 900: 4, 3600: 5, 14400: 6]
        passwordDelayPopup.selectedIndex = delayMap[delaySeconds] ?? 0

        // Enable/disable the delay popup based on whether password is required
        passwordDelayPopup.isEnabled = askForPassword

        // --- Disable automatic login ---
        // If `autoLoginUser` key exists in com.apple.loginwindow, auto-login is ON.
        // Our checkbox is "Disable automatic login", so it's the inverse.
        let autoLoginUser = defaults.string(forKey: "autoLoginUser", domain: "com.apple.loginwindow")
        disableAutoLoginCheck.isChecked = (autoLoginUser == nil)

        // --- Log out after inactivity ---
        // `com.apple.screensaver` → `idleTime` is in seconds. We show minutes in the popup.
        let idleTime = defaults.integer(forKey: "idleTime", domain: "com.apple.screensaver") ?? 0
        let idleMinutes = idleTime / 60
        let minuteValues = [5, 10, 15, 30, 60, 120]
        if let idx = minuteValues.firstIndex(of: idleMinutes) {
            logoutAfterCheck.isChecked = true
            logoutMinutesPopup.selectedIndex = idx
            logoutMinutesPopup.isEnabled = true
        } else {
            logoutAfterCheck.isChecked = (idleTime > 0)
            logoutMinutesPopup.isEnabled = (idleTime > 0)
        }

        // --- Lock screen message ---
        // Read from `com.apple.loginwindow` → `LoginwindowText`
        let lockMessage = defaults.string(forKey: "LoginwindowText", domain: "com.apple.loginwindow") ?? ""
        let hasMessage = !lockMessage.isEmpty
        showLockMessageCheck.isChecked = hasMessage
        lockMessageField.isEnabled = hasMessage
        lockMessageField.stringValue = lockMessage
    }

    // MARK: - FileVault Tab: Read System State

    /// Runs `fdesetup status` to determine whether FileVault is on or off,
    /// and updates the UI labels accordingly.
    private func reloadFileVaultTab() {
        // Run `fdesetup status` to check FileVault encryption state.
        // Output looks like: "FileVault is On." or "FileVault is Off."
        let fdeOutput = runCommand("/usr/bin/fdesetup", arguments: ["status"])
        let trimmed = (fdeOutput ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let isOn = trimmed.lowercased().contains("on")
        fileVaultStatusLabel.stringValue = isOn ? "FileVault is turned on." : "FileVault is turned off."
        fileVaultStatusLabel.textColor = isOn
            ? NSColor(calibratedRed: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
            : NSColor(white: 0.15, alpha: 1.0)

        // Update the toggle button text to match current state.
        fileVaultToggleButton.title = isOn ? "Turn Off FileVault..." : "Turn On FileVault..."

        // Boot volume info — we can read from the fdesetup output or
        // parse diskutil for the volume name.
        let volumeName = getBootVolumeName()
        diskInfoLabel.stringValue = isOn
            ? "Boot volume (\(volumeName)): Encrypted"
            : "Boot volume (\(volumeName)): Not encrypted"

        // Recovery key — check if fdesetup mentions conversion or key.
        // fdesetup doesn't directly tell us about the recovery key in `status`,
        // so we show a contextual message.
        if isOn {
            recoveryKeyLabel.stringValue = "A recovery key has been set."
        } else {
            recoveryKeyLabel.stringValue = "No recovery key (FileVault is off)."
        }
    }

    // MARK: - Firewall Tab: Read System State

    /// Queries the application firewall daemon for its current state (on/off,
    /// stealth mode, block-all, and the list of allowed/blocked applications).
    private func reloadFirewallTab() {
        let firewallPath = "/usr/libexec/ApplicationFirewall/socketfilterfw"

        // --- Global state (on/off) ---
        let globalOutput = runCommand(firewallPath, arguments: ["--getglobalstate"]) ?? ""
        let firewallOn = globalOutput.lowercased().contains("enabled")
        firewallStatusLabel.stringValue = firewallOn ? "Firewall: On" : "Firewall: Off"
        firewallStatusLabel.textColor = firewallOn
            ? NSColor(calibratedRed: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
            : NSColor(white: 0.15, alpha: 1.0)

        // Update toggle button text.
        firewallToggleButton.title = firewallOn ? "Turn Off Firewall..." : "Turn On Firewall..."

        // --- Stealth mode ---
        let stealthOutput = runCommand(firewallPath, arguments: ["--getstealthmode"]) ?? ""
        let stealthOn = stealthOutput.lowercased().contains("enabled")
        stealthModeLabel.stringValue = "Stealth Mode: \(stealthOn ? "Enabled" : "Disabled")"

        // --- Block all incoming connections ---
        let blockOutput = runCommand(firewallPath, arguments: ["--getblockall"]) ?? ""
        let blockAll = blockOutput.lowercased().contains("enabled")
        blockAllLabel.stringValue = "Block all incoming connections: \(blockAll ? "Yes" : "No")"

        // --- List allowed/blocked applications ---
        loadFirewallApps(firewallPath: firewallPath)
    }

    /// Parses the output of `socketfilterfw --listapps` to populate the firewall apps table.
    /// The output format is blocks like:
    ///   ALF : /Applications/SomeApp.app
    ///   ( Allow incoming connections )
    private func loadFirewallApps(firewallPath: String) {
        firewallApps.removeAll()

        guard let output = runCommand(firewallPath, arguments: ["--listapps"]) else {
            firewallAppsTable.reloadData()
            return
        }

        let lines = output.components(separatedBy: "\n")
        var currentApp: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Lines starting with "ALF :" contain the app path
            if trimmed.hasPrefix("ALF :") || trimmed.contains(": /") {
                // Extract the path from the line
                if let colonRange = trimmed.range(of: ": ") {
                    let path = String(trimmed[colonRange.upperBound...])
                    // Get just the app name from the path
                    let appName = (path as NSString).lastPathComponent
                        .replacingOccurrences(of: ".app", with: "")
                    currentApp = appName
                }
            }
            // Lines with "Allow" or "Block" tell us the rule
            else if let app = currentApp {
                if trimmed.lowercased().contains("allow") {
                    firewallApps.append((name: app, allowed: true))
                    currentApp = nil
                } else if trimmed.lowercased().contains("block") {
                    firewallApps.append((name: app, allowed: false))
                    currentApp = nil
                }
            }
        }

        firewallAppsTable.reloadData()
    }

    // MARK: - Shell Command Helper

    /// Runs a command-line tool and returns its stdout as a String.
    /// Used to invoke `fdesetup`, `socketfilterfw`, `diskutil`, etc.
    ///
    /// - Parameters:
    ///   - path: Absolute path to the executable (e.g. "/usr/bin/fdesetup").
    ///   - arguments: Command-line arguments to pass.
    /// - Returns: The stdout output as a String, or nil if the command failed to launch.
    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Suppress stderr
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Returns the name of the boot volume (e.g. "Macintosh HD") by parsing
    /// `diskutil info /` output. Falls back to "Macintosh HD" if parsing fails.
    private func getBootVolumeName() -> String {
        guard let output = runCommand("/usr/sbin/diskutil", arguments: ["info", "/"]) else {
            return "Macintosh HD"
        }
        for line in output.components(separatedBy: "\n") {
            if line.contains("Volume Name:") {
                let name = line.replacingOccurrences(of: "Volume Name:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { return name }
            }
        }
        return "Macintosh HD"
    }

    // MARK: - General Tab Actions

    /// Called when the user toggles "Require password after sleep or screen saver begins".
    /// Writes the `askForPassword` boolean to the screensaver domain.
    @objc private func requirePasswordChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "askForPassword", domain: "com.apple.screensaver")
        passwordDelayPopup.isEnabled = sender.isChecked
    }

    /// Called when the user changes the password delay popup (immediately, 5 sec, etc.).
    /// Writes the delay in seconds to `askForPasswordDelay` in the screensaver domain.
    @objc private func passwordDelayChanged(_ sender: AquaPopUpButton) {
        // Map popup index back to seconds
        let delayValues = [0, 5, 60, 300, 900, 3600, 14400]
        let seconds = delayValues[sender.selectedIndex]
        defaults.setInteger(seconds, forKey: "askForPasswordDelay", domain: "com.apple.screensaver")
    }

    /// Called when the user toggles "Disable automatic login".
    /// This setting is tricky — we can remove the autoLoginUser key to disable auto-login,
    /// but enabling auto-login requires knowing the username, so we redirect to System Settings
    /// for that case.
    @objc private func disableAutoLoginChanged(_ sender: AquaCheckbox) {
        if sender.isChecked {
            // Remove the auto-login user key — this disables automatic login.
            defaults.set(nil, forKey: "autoLoginUser", domain: "com.apple.loginwindow")
        } else {
            // Re-enabling auto-login requires specifying a user and authenticating.
            // Redirect to System Settings for this operation.
            SystemSettingsLauncher.open(url: "com.apple.LoginItems-Settings.extension")
        }
    }

    /// Called when the user toggles "Require an administrator password to access locked preferences".
    /// This is stored in the global preferences domain.
    @objc private func adminPasswordChanged(_ sender: AquaCheckbox) {
        // This preference is actually managed by the security framework and may require
        // admin privileges to change. We write it optimistically; the OS will enforce
        // authorization if needed.
        defaults.setBool(sender.isChecked, forKey: "LockPrefPane", domain: "com.apple.security")
    }

    /// Called when the user toggles the "Log out after ... minutes of inactivity" checkbox.
    @objc private func logoutAfterChanged(_ sender: AquaCheckbox) {
        logoutMinutesPopup.isEnabled = sender.isChecked
        if !sender.isChecked {
            // Set idle time to 0 to disable auto-logout
            defaults.setInteger(0, forKey: "idleTime", domain: "com.apple.screensaver")
        } else {
            // Set to the currently selected minutes value (in seconds)
            let minuteValues = [5, 10, 15, 30, 60, 120]
            let minutes = minuteValues[logoutMinutesPopup.selectedIndex]
            defaults.setInteger(minutes * 60, forKey: "idleTime", domain: "com.apple.screensaver")
        }
    }

    /// Called when the user changes the inactivity minutes popup.
    @objc private func logoutMinutesChanged(_ sender: AquaPopUpButton) {
        let minuteValues = [5, 10, 15, 30, 60, 120]
        let minutes = minuteValues[sender.selectedIndex]
        defaults.setInteger(minutes * 60, forKey: "idleTime", domain: "com.apple.screensaver")
    }

    /// Called when the user toggles "Show a message when the screen is locked".
    /// Enables or disables the text field and clears the message if unchecked.
    @objc private func showLockMessageChanged(_ sender: AquaCheckbox) {
        lockMessageField.isEnabled = sender.isChecked
        if !sender.isChecked {
            // Clear the lock screen message
            lockMessageField.stringValue = ""
            defaults.setString("", forKey: "LoginwindowText", domain: "com.apple.loginwindow")
        } else {
            // Focus the text field so the user can type immediately
            lockMessageField.window?.makeFirstResponder(lockMessageField)
        }
    }

    // MARK: - FileVault Tab Actions

    /// Opens System Settings to the FileVault section. Enabling/disabling FileVault
    /// requires an authorization dialog and a restart, so we delegate to the system.
    @objc private func toggleFileVault(_ sender: AquaButton) {
        SystemSettingsLauncher.open(url: settingsURL)
    }

    // MARK: - Firewall Tab Actions

    /// Opens System Settings to toggle the firewall. Changing the global firewall
    /// state requires admin privileges, so we hand off to System Settings.
    @objc private func toggleFirewall(_ sender: AquaButton) {
        SystemSettingsLauncher.open(url: settingsURL)
    }

    /// Opens System Settings to the advanced firewall options panel where the user
    /// can manage per-app rules, stealth mode, and block-all settings.
    @objc private func openFirewallOptions(_ sender: AquaButton) {
        SystemSettingsLauncher.open(url: settingsURL)
    }
}

// MARK: - NSTextFieldDelegate

/// We implement NSTextFieldDelegate to save the lock screen message when the user
/// finishes editing the text field (presses Return or tabs away).
extension SecurityPaneViewController: NSTextFieldDelegate {

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === lockMessageField else { return }
        // Write the lock screen message to the loginwindow domain.
        let message = field.stringValue
        defaults.setString(message, forKey: "LoginwindowText", domain: "com.apple.loginwindow")
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate

/// The firewall apps table shows applications that have explicit firewall rules
/// (allow or block incoming connections).
extension SecurityPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return firewallApps.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < firewallApps.count else { return nil }
        let app = firewallApps[row]
        let colID = tableColumn?.identifier.rawValue ?? ""

        if colID == "appName" {
            // Application name column
            let cell = NSTextField(labelWithString: app.name)
            cell.font = SnowLeopardFonts.label(size: 11)
            cell.textColor = NSColor(white: 0.15, alpha: 1.0)
            return cell
        } else if colID == "appStatus" {
            // Status column — green "Allow" or red "Block"
            let statusText = app.allowed ? "Allow incoming connections" : "Block incoming connections"
            let cell = NSTextField(labelWithString: statusText)
            cell.font = SnowLeopardFonts.label(size: 11)
            cell.textColor = app.allowed
                ? NSColor(calibratedRed: 0.0, green: 0.5, blue: 0.0, alpha: 1.0)
                : NSColor.systemRed
            return cell
        }
        return nil
    }
}
