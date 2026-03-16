import Cocoa

enum PaneRegistry {

    static let factories: [String: () -> PaneProtocol] = [
        // Personal
        "appearance":        { GeneralPaneViewController() },
        "desktopscreensaver": { DesktopScreenSaverPaneViewController() },
        "dock":              { DockPaneViewController() },
        "exposespaces":      { ExposeSpacesPaneViewController() },
        "spotlight":         { RedirectPaneViewController(identifier: "spotlight", title: "Spotlight", sfSymbol: "magnifyingglass", category: .personal, settingsURL: "com.apple.Siri-Settings.extension", keywords: ["spotlight", "search"], description: "Configure Spotlight search categories and privacy settings.") },

        // Hardware
        "displays":          { DisplaysPaneViewController() },
        "energysaver":       { BatteryPaneViewController() },
        "keyboard":          { KeyboardPaneViewController() },
        "mouse":             { MouseTrackpadPaneViewController() },
        "trackpad":          { MouseTrackpadPaneViewController() },
        "sound":             { SoundPaneViewController() },

        // Internet & Wireless
        "bluetooth":         { BluetoothPaneViewController() },
        "network":           { NetworkPaneViewController() },
        "sharing":           { SharingPaneViewController() },

        // System
        "accounts":          { UsersPaneViewController() },
        "datetime":          { DateTimePaneViewController() },
        "softwareupdate":    { SoftwareUpdatePaneViewController() },
        "startupdisk":       { StartupDiskPaneViewController() },
        "universalaccess":   { AccessibilityPaneViewController() },

        // Redirect panes (Snow Leopard panes without native implementation)
        "languagetext":      { RedirectPaneViewController(identifier: "languagetext", title: "Language & Text", sfSymbol: "character.book.closed.fill", category: .personal, settingsURL: "com.apple.Keyboard-Settings.extension", keywords: ["language", "text", "input"], description: "Configure language, region, and text input settings.") },
        "security":          { RedirectPaneViewController(identifier: "security", title: "Security", sfSymbol: "lock.fill", category: .personal, settingsURL: "com.apple.settings.PrivacySecurity.extension", keywords: ["security", "password", "filevault", "firewall"], description: "Configure security settings including password, FileVault, and Firewall.") },
        "cdsdvds":           { RedirectPaneViewController(identifier: "cdsdvds", title: "CDs & DVDs", sfSymbol: "opticaldisc.fill", category: .hardware, settingsURL: "com.apple.systempreferences.GeneralSettings", keywords: ["cd", "dvd", "disc"], description: "Choose what happens when you insert a CD or DVD.") },
        "printfax":          { RedirectPaneViewController(identifier: "printfax", title: "Print & Fax", sfSymbol: "printer.fill", category: .hardware, settingsURL: "com.apple.Print-Scan-Settings.extension", keywords: ["printer", "fax"], description: "Add and configure printers and fax machines.") },
        "mobileme":          { RedirectPaneViewController(identifier: "mobileme", title: "MobileMe", sfSymbol: "cloud.fill", category: .internetWireless, settingsURL: "com.apple.Internet-Accounts-Settings.extension", keywords: ["mobileme", "icloud", "sync"], description: "MobileMe has been replaced by iCloud. Configure your account in Internet Accounts.") },
        "parentalcontrols":  { RedirectPaneViewController(identifier: "parentalcontrols", title: "Parental Controls", sfSymbol: "person.2.badge.gearshape", category: .system, settingsURL: "com.apple.Screen-Time-Settings.extension", keywords: ["parental", "controls", "restrictions"], description: "Parental Controls is now part of Screen Time.") },
        "speech":            { RedirectPaneViewController(identifier: "speech", title: "Speech", sfSymbol: "waveform", category: .system, settingsURL: "com.apple.Accessibility-Settings.extension", keywords: ["speech", "voiceover", "dictation"], description: "Speech settings are now part of Accessibility.") },
        "timemachine":       { RedirectPaneViewController(identifier: "timemachine", title: "Time Machine", sfSymbol: "clock.arrow.circlepath", category: .system, settingsURL: "com.apple.Time-Machine-Settings.extension", keywords: ["backup", "time machine"], description: "Configure Time Machine backup settings.") },
    ]

    static func createPane(_ id: String) -> PaneProtocol? {
        factories[id]?()
    }
}
