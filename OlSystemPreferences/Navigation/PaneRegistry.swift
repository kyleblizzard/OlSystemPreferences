import Cocoa

enum PaneRegistry {

    static let factories: [String: () -> PaneProtocol] = [
        "general":       { GeneralPaneViewController() },
        "dock":          { DockPaneViewController() },
        "sound":         { SoundPaneViewController() },
        "keyboard":      { KeyboardPaneViewController() },
        "displays":      { DisplaysPaneViewController() },
        "mouse":         { MouseTrackpadPaneViewController() },
        "trackpad":      { MouseTrackpadPaneViewController() },
        "wallpaper":     { DesktopScreenSaverPaneViewController() },
        "screensaver":   { DesktopScreenSaverPaneViewController() },
        "exposespaces":  { ExposeSpacesPaneViewController() },
        "network":       { NetworkPaneViewController() },
        "datetime":      { DateTimePaneViewController() },
        "sharing":       { SharingPaneViewController() },
        "battery":       { BatteryPaneViewController() },
        "users":         { UsersPaneViewController() },
        "startupdisk":   { StartupDiskPaneViewController() },
        "softwareupdate": { SoftwareUpdatePaneViewController() },
        "bluetooth":     { BluetoothPaneViewController() },
        "wifi":          { WiFiPaneViewController() },
        "notifications": { NotificationsPaneViewController() },
        "accessibility": { AccessibilityPaneViewController() },
        "lockscreen":    { LockScreenPaneViewController() },
    ]

    static func createPane(_ id: String) -> PaneProtocol? {
        factories[id]?()
    }
}
