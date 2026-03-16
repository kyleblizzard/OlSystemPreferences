import Cocoa

enum PaneRegistry {

    static let factories: [String: () -> PaneProtocol] = [
        // Personal
        "appearance":        { GeneralPaneViewController() },
        "desktopscreensaver": { DesktopScreenSaverPaneViewController() },
        "dock":              { DockPaneViewController() },
        "exposespaces":      { ExposeSpacesPaneViewController() },
        "languagetext":      { LanguageTextPaneViewController() },
        "security":          { SecurityPaneViewController() },
        "spotlight":         { SpotlightPaneViewController() },

        // Hardware
        "cdsdvds":           { CDsDVDsPaneViewController() },
        "displays":          { DisplaysPaneViewController() },
        "energysaver":       { BatteryPaneViewController() },
        "keyboard":          { KeyboardPaneViewController() },
        "mouse":             { MouseTrackpadPaneViewController() },
        "trackpad":          { MouseTrackpadPaneViewController() },
        "printfax":          { PrintFaxPaneViewController() },
        "sound":             { SoundPaneViewController() },

        // Internet & Wireless
        "bluetooth":         { BluetoothPaneViewController() },
        "mobileme":          { MobileMePaneViewController() },
        "network":           { NetworkPaneViewController() },
        "sharing":           { SharingPaneViewController() },

        // System
        "accounts":          { UsersPaneViewController() },
        "datetime":          { DateTimePaneViewController() },
        "parentalcontrols":  { ParentalControlsPaneViewController() },
        "softwareupdate":    { SoftwareUpdatePaneViewController() },
        "speech":            { SpeechPaneViewController() },
        "startupdisk":       { StartupDiskPaneViewController() },
        "timemachine":       { TimeMachinePaneViewController() },
        "universalaccess":   { AccessibilityPaneViewController() },
    ]

    static func createPane(_ id: String) -> PaneProtocol? {
        factories[id]?()
    }
}
