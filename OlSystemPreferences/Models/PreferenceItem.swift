import Cocoa

struct PreferenceItem {
    let id: String
    let title: String
    let category: PaneCategory
    let keywords: [String]

    // System preference fields
    let sfSymbol: String
    let iconColor: NSColor
    let settingsURL: String

    // App preference fields
    let appBundleIdentifier: String?
    private let appIcon: NSImage?

    var isAppItem: Bool { appBundleIdentifier != nil }

    // MARK: - System Preference Init

    init(id: String, title: String, sfSymbol: String, iconColor: NSColor, category: PaneCategory, settingsURL: String, keywords: [String]) {
        self.id = id
        self.title = title
        self.sfSymbol = sfSymbol
        self.iconColor = iconColor
        self.category = category
        self.settingsURL = settingsURL
        self.keywords = keywords
        self.appBundleIdentifier = nil
        self.appIcon = nil
    }

    // MARK: - App Preference Init

    init(id: String, title: String, appBundleIdentifier: String, appIcon: NSImage, category: PaneCategory, keywords: [String]) {
        self.id = id
        self.title = title
        self.appBundleIdentifier = appBundleIdentifier
        self.appIcon = appIcon
        self.category = category
        self.keywords = keywords
        self.sfSymbol = ""
        self.iconColor = .clear
        self.settingsURL = ""
    }

    // MARK: - Icon

    var icon: NSImage {
        if let appIcon = appIcon {
            return appIcon
        }
        // Use skeuomorphic icon if available
        if let skeuIcon = SkeuomorphicIconFactory.presetIcon(for: id, size: AppConstants.iconSize) {
            return skeuIcon
        }
        // Fallback: generate from SF Symbol + color
        return SkeuomorphicIconFactory.icon(sfSymbol: sfSymbol, baseColor: iconColor, size: AppConstants.iconSize)
    }

    // MARK: - Open Action

    func open() {
        if let bundleId = appBundleIdentifier {
            AppDetector.openAppPreferences(bundleIdentifier: bundleId)
        } else {
            SystemSettingsLauncher.open(url: settingsURL)
        }
    }
}

// MARK: - Snow Leopard 10.6 Preference Item Registry (28 panes)

extension PreferenceItem {

    static let allItems: [PreferenceItem] = personalItems + hardwareItems + internetItems + systemItems

    // MARK: Personal (7)

    static let personalItems: [PreferenceItem] = [
        PreferenceItem(
            id: "appearance",
            title: "Appearance",
            sfSymbol: "paintbrush.fill",
            iconColor: NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.75, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.Appearance-Settings.extension",
            keywords: ["appearance", "blue", "graphite", "accent color", "highlight", "font smoothing"]
        ),
        PreferenceItem(
            id: "desktopscreensaver",
            title: "Desktop & Screen Saver",
            sfSymbol: "photo.fill",
            iconColor: NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.80, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.Wallpaper-Settings.extension",
            keywords: ["desktop", "background", "picture", "screen saver", "screensaver"]
        ),
        PreferenceItem(
            id: "dock",
            title: "Dock",
            sfSymbol: "dock.rectangle",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.Desktop-Settings.extension",
            keywords: ["dock", "size", "magnification", "autohide", "minimize"]
        ),
        PreferenceItem(
            id: "exposespaces",
            title: "Exposé & Spaces",
            sfSymbol: "rectangle.3.group",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.80, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.Desktop-Settings.extension",
            keywords: ["expose", "spaces", "hot corner", "mission control", "desktop"]
        ),
        PreferenceItem(
            id: "languagetext",
            title: "Language & Text",
            sfSymbol: "character.book.closed.fill",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.Keyboard-Settings.extension",
            keywords: ["language", "region", "text", "input source", "format", "international"]
        ),
        PreferenceItem(
            id: "security",
            title: "Security",
            sfSymbol: "lock.fill",
            iconColor: NSColor(calibratedRed: 0.85, green: 0.70, blue: 0.20, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.settings.PrivacySecurity.extension",
            keywords: ["security", "password", "filevault", "firewall", "require password"]
        ),
        PreferenceItem(
            id: "spotlight",
            title: "Spotlight",
            sfSymbol: "magnifyingglass",
            iconColor: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.Siri-Settings.extension",
            keywords: ["spotlight", "search", "index", "privacy"]
        ),
    ]

    // MARK: Hardware (8)

    static let hardwareItems: [PreferenceItem] = [
        PreferenceItem(
            id: "cdsdvds",
            title: "CDs & DVDs",
            sfSymbol: "opticaldisc.fill",
            iconColor: NSColor(calibratedRed: 0.48, green: 0.48, blue: 0.55, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.systempreferences.GeneralSettings",
            keywords: ["cd", "dvd", "disc", "blank", "insert"]
        ),
        PreferenceItem(
            id: "displays",
            title: "Displays",
            sfSymbol: "display",
            iconColor: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.78, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Displays-Settings.extension",
            keywords: ["resolution", "brightness", "color", "display", "monitor", "arrangement"]
        ),
        PreferenceItem(
            id: "energysaver",
            title: "Energy Saver",
            sfSymbol: "battery.100.bolt",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.68, blue: 0.35, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Battery-Settings.extension",
            keywords: ["energy saver", "sleep", "power", "battery", "schedule", "ups"]
        ),
        PreferenceItem(
            id: "keyboard",
            title: "Keyboard",
            sfSymbol: "keyboard",
            iconColor: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.52, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Keyboard-Settings.extension",
            keywords: ["key repeat", "shortcuts", "input sources", "modifier keys"]
        ),
        PreferenceItem(
            id: "mouse",
            title: "Mouse",
            sfSymbol: "computermouse.fill",
            iconColor: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.52, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Mouse-Settings.extension",
            keywords: ["tracking", "scrolling", "clicking", "mouse"]
        ),
        PreferenceItem(
            id: "printfax",
            title: "Print & Fax",
            sfSymbol: "printer.fill",
            iconColor: NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.75, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Print-Scan-Settings.extension",
            keywords: ["printer", "fax", "print", "scanner"]
        ),
        PreferenceItem(
            id: "sound",
            title: "Sound",
            sfSymbol: "speaker.wave.3.fill",
            iconColor: NSColor(calibratedRed: 0.80, green: 0.35, blue: 0.50, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Sound-Settings.extension",
            keywords: ["volume", "output", "input", "microphone", "speaker", "alert"]
        ),
        PreferenceItem(
            id: "trackpad",
            title: "Trackpad",
            sfSymbol: "rectangle.and.hand.point.up.left.fill",
            iconColor: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.52, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Trackpad-Settings.extension",
            keywords: ["trackpad", "gestures", "tap", "click", "scroll"]
        ),
    ]

    // MARK: Internet & Wireless (4)

    static let internetItems: [PreferenceItem] = [
        PreferenceItem(
            id: "bluetooth",
            title: "Bluetooth",
            sfSymbol: "wave.3.right",
            iconColor: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.85, alpha: 1.0),
            category: .internetWireless,
            settingsURL: "com.apple.BluetoothSettings",
            keywords: ["bluetooth", "wireless", "pair", "connect", "devices"]
        ),
        PreferenceItem(
            id: "mobileme",
            title: "MobileMe",
            sfSymbol: "cloud.fill",
            iconColor: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0),
            category: .internetWireless,
            settingsURL: "com.apple.Internet-Accounts-Settings.extension",
            keywords: ["mobileme", "icloud", "sync", "idisk", "mail", "account"]
        ),
        PreferenceItem(
            id: "network",
            title: "Network",
            sfSymbol: "network",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0),
            category: .internetWireless,
            settingsURL: "com.apple.Network-Settings.extension",
            keywords: ["ethernet", "wifi", "airport", "vpn", "dns", "proxy", "firewall", "ip"]
        ),
        PreferenceItem(
            id: "sharing",
            title: "Sharing",
            sfSymbol: "person.2.fill",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0),
            category: .internetWireless,
            settingsURL: "com.apple.Sharing-Settings.extension",
            keywords: ["sharing", "file sharing", "screen sharing", "remote login", "computer name"]
        ),
    ]

    // MARK: System (8)

    static let systemItems: [PreferenceItem] = [
        PreferenceItem(
            id: "accounts",
            title: "Accounts",
            sfSymbol: "person.2.fill",
            iconColor: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Users-Groups-Settings.extension",
            keywords: ["users", "accounts", "login", "password", "admin", "guest"]
        ),
        PreferenceItem(
            id: "datetime",
            title: "Date & Time",
            sfSymbol: "clock.fill",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.80, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Date-Time-Settings.extension",
            keywords: ["date", "time", "timezone", "clock", "ntp"]
        ),
        PreferenceItem(
            id: "parentalcontrols",
            title: "Parental Controls",
            sfSymbol: "person.2.badge.gearshape",
            iconColor: NSColor(calibratedRed: 0.85, green: 0.70, blue: 0.20, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Screen-Time-Settings.extension",
            keywords: ["parental controls", "restrictions", "limits", "children"]
        ),
        PreferenceItem(
            id: "softwareupdate",
            title: "Software Update",
            sfSymbol: "arrow.triangle.2.circlepath",
            iconColor: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Software-Update-Settings.extension",
            keywords: ["update", "upgrade", "macos", "automatic updates"]
        ),
        PreferenceItem(
            id: "speech",
            title: "Speech",
            sfSymbol: "waveform",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Accessibility-Settings.extension",
            keywords: ["speech", "text to speech", "voiceover", "recognition", "dictation"]
        ),
        PreferenceItem(
            id: "startupdisk",
            title: "Startup Disk",
            sfSymbol: "internaldrive.fill",
            iconColor: NSColor(calibratedRed: 0.48, green: 0.48, blue: 0.55, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Startup-Disk-Settings.extension",
            keywords: ["startup", "boot", "disk", "volume"]
        ),
        PreferenceItem(
            id: "timemachine",
            title: "Time Machine",
            sfSymbol: "clock.arrow.circlepath",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.68, blue: 0.35, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Time-Machine-Settings.extension",
            keywords: ["backup", "time machine", "restore"]
        ),
        PreferenceItem(
            id: "universalaccess",
            title: "Universal Access",
            sfSymbol: "accessibility",
            iconColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Accessibility-Settings.extension",
            keywords: ["voiceover", "zoom", "display", "hearing", "universal access", "accessibility"]
        ),
    ]
}
