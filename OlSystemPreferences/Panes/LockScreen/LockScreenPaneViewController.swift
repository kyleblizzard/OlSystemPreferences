import Cocoa

class LockScreenPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "lockscreen" }
    var paneTitle: String { "Security" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Security") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 420) }
    var searchKeywords: [String] { ["lock screen", "security", "password", "login", "screen saver", "sleep", "message", "automatic login"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Lock-Screen-Settings.extension" }

    // MARK: - Data

    private let defaults = DefaultsService.shared

    // General section
    private let requirePasswordCheck = NSButton(checkboxWithTitle: "Require password", target: nil, action: nil)
    private let passwordDelayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let afterSleepLabel = NSTextField(labelWithString: "after sleep or screen saver begins")

    // Screen Lock Message section
    private let showMessageCheck = NSButton(checkboxWithTitle: "Show a message when the screen is locked", target: nil, action: nil)
    private let messageField = NSTextField()

    // Advanced section
    private let autoLogoutLabel = NSTextField(labelWithString: "")
    private let disableAutoLoginCheck = NSButton(checkboxWithTitle: "Disable automatic login", target: nil, action: nil)

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

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

        // --- Separator ---
        let headerSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        outerStack.addArrangedSubview(headerSep)

        // ===== Section: General =====
        let generalBox = SnowLeopardPaneHelper.makeSectionBox(title: "General")
        let generalStack = NSStackView()
        generalStack.translatesAutoresizingMaskIntoConstraints = false
        generalStack.orientation = .vertical
        generalStack.alignment = .leading
        generalStack.spacing = 10
        generalStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Require password row
        requirePasswordCheck.target = self
        requirePasswordCheck.action = #selector(requirePasswordToggled(_:))
        SnowLeopardPaneHelper.styleControl(requirePasswordCheck)

        // Password delay popup
        passwordDelayPopup.removeAllItems()
        let delayOptions = ["immediately", "5 seconds", "1 minute", "5 minutes", "15 minutes", "1 hour", "4 hours"]
        for option in delayOptions {
            passwordDelayPopup.addItem(withTitle: option)
        }
        passwordDelayPopup.target = self
        passwordDelayPopup.action = #selector(passwordDelayChanged(_:))
        SnowLeopardPaneHelper.styleControl(passwordDelayPopup, size: 11)

        afterSleepLabel.font = SnowLeopardFonts.label(size: 11)
        afterSleepLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let passwordRow = NSStackView(views: [requirePasswordCheck, passwordDelayPopup, afterSleepLabel])
        passwordRow.orientation = .horizontal
        passwordRow.spacing = 6
        passwordRow.alignment = .firstBaseline
        generalStack.addArrangedSubview(passwordRow)

        // Explanation
        let pwExplain = SnowLeopardPaneHelper.makeLabel(
            "A login password will be required to wake the computer from sleep or the screen saver.",
            size: 10
        )
        pwExplain.textColor = .secondaryLabelColor
        pwExplain.maximumNumberOfLines = 2
        pwExplain.preferredMaxLayoutWidth = 540

        let explainRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [pwExplain]
        )
        generalStack.addArrangedSubview(explainRow)

        generalBox.contentView = generalStack
        outerStack.addArrangedSubview(generalBox)
        generalBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Screen Lock Message =====
        let messageBox = SnowLeopardPaneHelper.makeSectionBox(title: "Screen Lock Message")
        let messageStack = NSStackView()
        messageStack.translatesAutoresizingMaskIntoConstraints = false
        messageStack.orientation = .vertical
        messageStack.alignment = .leading
        messageStack.spacing = 10
        messageStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Show message checkbox
        showMessageCheck.target = self
        showMessageCheck.action = #selector(showMessageToggled(_:))
        SnowLeopardPaneHelper.styleControl(showMessageCheck)

        let showRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [showMessageCheck]
        )
        messageStack.addArrangedSubview(showRow)

        // Message text field
        messageField.translatesAutoresizingMaskIntoConstraints = false
        messageField.font = SnowLeopardFonts.label(size: 11)
        messageField.placeholderString = "Enter lock screen message..."
        messageField.isEditable = true
        messageField.isSelectable = true
        messageField.widthAnchor.constraint(equalToConstant: 400).isActive = true
        messageField.target = self
        messageField.action = #selector(messageFieldChanged(_:))

        let msgRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Message:"),
            controls: [messageField]
        )
        messageStack.addArrangedSubview(msgRow)

        // Info about admin requirement
        let msgInfo = SnowLeopardPaneHelper.makeLabel(
            "Setting the lock screen message may require administrator privileges.",
            size: 10
        )
        msgInfo.textColor = .secondaryLabelColor
        msgInfo.maximumNumberOfLines = 2
        msgInfo.preferredMaxLayoutWidth = 540
        messageStack.addArrangedSubview(msgInfo)

        messageBox.contentView = messageStack
        outerStack.addArrangedSubview(messageBox)
        messageBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // ===== Section: Advanced =====
        let advancedBox = SnowLeopardPaneHelper.makeSectionBox(title: "Advanced")
        let advancedStack = NSStackView()
        advancedStack.translatesAutoresizingMaskIntoConstraints = false
        advancedStack.orientation = .vertical
        advancedStack.alignment = .leading
        advancedStack.spacing = 10
        advancedStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Auto logout info
        autoLogoutLabel.font = SnowLeopardFonts.label(size: 11)
        autoLogoutLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        autoLogoutLabel.maximumNumberOfLines = 2
        autoLogoutLabel.preferredMaxLayoutWidth = 400

        let logoutRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Auto Log Out:"),
            controls: [autoLogoutLabel]
        )
        advancedStack.addArrangedSubview(logoutRow)

        // Disable automatic login
        disableAutoLoginCheck.target = self
        disableAutoLoginCheck.action = #selector(autoLoginToggled(_:))
        SnowLeopardPaneHelper.styleControl(disableAutoLoginCheck)

        let autoLoginRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [disableAutoLoginCheck]
        )
        advancedStack.addArrangedSubview(autoLoginRow)

        advancedStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Info
        let advInfo = SnowLeopardPaneHelper.makeLabel(
            "Changing advanced security settings requires administrator privileges. Use Open in System Settings to make changes.",
            size: 10
        )
        advInfo.textColor = .secondaryLabelColor
        advInfo.maximumNumberOfLines = 2
        advInfo.preferredMaxLayoutWidth = 540
        advancedStack.addArrangedSubview(advInfo)

        advancedBox.contentView = advancedStack
        outerStack.addArrangedSubview(advancedBox)
        advancedBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

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

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        // Require password after sleep
        let askForPassword = defaults.bool(forKey: "askForPassword", domain: "com.apple.screensaver") ?? true
        requirePasswordCheck.state = askForPassword ? .on : .off

        // Password delay
        let delay = defaults.integer(forKey: "askForPasswordDelay", domain: "com.apple.screensaver") ?? 0
        let delayIndex = delayToIndex(delay)
        passwordDelayPopup.selectItem(at: delayIndex)
        passwordDelayPopup.isEnabled = askForPassword

        // Lock screen message
        let loginText = readLoginWindowText()
        let hasMessage = !loginText.isEmpty
        showMessageCheck.state = hasMessage ? .on : .off
        messageField.stringValue = loginText
        messageField.isEnabled = hasMessage

        // Auto logout
        let autoLogoutMinutes = readAutoLogoutMinutes()
        if autoLogoutMinutes > 0 {
            autoLogoutLabel.stringValue = "Log out after \(autoLogoutMinutes) minutes of inactivity"
        } else {
            autoLogoutLabel.stringValue = "Disabled"
        }

        // Automatic login
        let autoLoginDisabled = readAutoLoginDisabled()
        disableAutoLoginCheck.state = autoLoginDisabled ? .on : .off
    }

    // MARK: - Reading System Settings

    private func readLoginWindowText() -> String {
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "/Library/Preferences/com.apple.loginwindow", "LoginwindowText"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            // defaults read returns error text if key doesn't exist
            if !trimmed.contains("does not exist") && !trimmed.isEmpty {
                return trimmed
            }
        }
        return ""
    }

    private func readAutoLogoutMinutes() -> Int {
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", ".GlobalPreferences", "com.apple.autologout.AutoLogOutDelay"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if let minutes = Int(trimmed) {
                return minutes
            }
        }
        return 0
    }

    private func readAutoLoginDisabled() -> Bool {
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "/Library/Preferences/com.apple.loginwindow", "autoLoginUser"]) {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            // If autoLoginUser exists and is non-empty, auto-login is enabled (so "disable" checkbox should be off)
            if !trimmed.contains("does not exist") && !trimmed.isEmpty {
                return false
            }
        }
        // No autoLoginUser key means auto-login is disabled
        return true
    }

    private func delayToIndex(_ seconds: Int) -> Int {
        switch seconds {
        case 0: return 0         // immediately
        case 5: return 1         // 5 seconds
        case 60: return 2        // 1 minute
        case 300: return 3       // 5 minutes
        case 900: return 4       // 15 minutes
        case 3600: return 5      // 1 hour
        case 14400: return 6     // 4 hours
        default: return 0
        }
    }

    private func indexToDelay(_ index: Int) -> Int {
        switch index {
        case 0: return 0
        case 1: return 5
        case 2: return 60
        case 3: return 300
        case 4: return 900
        case 5: return 3600
        case 6: return 14400
        default: return 0
        }
    }

    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
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

    @objc private func requirePasswordToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        defaults.setBool(enabled, forKey: "askForPassword", domain: "com.apple.screensaver")
        passwordDelayPopup.isEnabled = enabled
    }

    @objc private func passwordDelayChanged(_ sender: NSPopUpButton) {
        let delaySeconds = indexToDelay(sender.indexOfSelectedItem)
        defaults.setInteger(delaySeconds, forKey: "askForPasswordDelay", domain: "com.apple.screensaver")
    }

    @objc private func showMessageToggled(_ sender: NSButton) {
        let show = sender.state == .on
        messageField.isEnabled = show
        if !show {
            // Clear the message — requires admin, open System Settings
            messageField.stringValue = ""
            openLockScreenSettings()
        }
    }

    @objc private func messageFieldChanged(_ sender: NSTextField) {
        // Writing to loginwindow plist requires admin — inform user
        let message = sender.stringValue
        if !message.isEmpty {
            // Attempt to write, but this typically requires sudo
            _ = runCommand("/usr/bin/defaults", arguments: ["write", "/Library/Preferences/com.apple.loginwindow", "LoginwindowText", message])
        }
    }

    @objc private func autoLoginToggled(_ sender: NSButton) {
        // This requires admin privileges — open System Settings
        openLockScreenSettings()
    }

    private func openLockScreenSettings() {
        guard let url = URL(string: "x-apple.systempreferences:\(settingsURL)") else { return }
        NSWorkspace.shared.open(url)
    }
}
