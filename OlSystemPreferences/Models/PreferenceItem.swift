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

// MARK: - Full Preference Item Registry

extension PreferenceItem {

    static let allItems: [PreferenceItem] = personalItems + hardwareItems + internetItems + systemItems

    // MARK: Personal

    static let personalItems: [PreferenceItem] = [
        PreferenceItem(
            id: "appearance",
            title: "Appearance",
            sfSymbol: "paintbrush.fill",
            iconColor: .systemPurple,
            category: .personal,
            settingsURL: "com.apple.Appearance-Settings.extension",
            keywords: ["dark mode", "light mode", "accent color", "highlight", "theme"]
        ),
        PreferenceItem(
            id: "wallpaper",
            title: "Wallpaper",
            sfSymbol: "photo.fill",
            iconColor: .systemCyan,
            category: .personal,
            settingsURL: "com.apple.Wallpaper-Settings.extension",
            keywords: ["desktop", "background", "picture", "wallpaper"]
        ),
        PreferenceItem(
            id: "screensaver",
            title: "Screen Saver",
            sfSymbol: "sparkles.tv.fill",
            iconColor: .systemIndigo,
            category: .personal,
            settingsURL: "com.apple.ScreenSaver-Settings.extension",
            keywords: ["screen saver", "screensaver", "hot corners", "idle"]
        ),
        PreferenceItem(
            id: "dock",
            title: "Desktop & Dock",
            sfSymbol: "dock.rectangle",
            iconColor: .systemBlue,
            category: .personal,
            settingsURL: "com.apple.Desktop-Settings.extension",
            keywords: ["dock", "size", "magnification", "autohide", "minimize", "mission control", "stage manager"]
        ),
        PreferenceItem(
            id: "notifications",
            title: "Notifications",
            sfSymbol: "bell.badge.fill",
            iconColor: .systemRed,
            category: .personal,
            settingsURL: "com.apple.Notifications-Settings.extension",
            keywords: ["alerts", "banners", "badges", "notification center"]
        ),
        PreferenceItem(
            id: "focus",
            title: "Focus",
            sfSymbol: "moon.fill",
            iconColor: .systemIndigo,
            category: .personal,
            settingsURL: "com.apple.Focus-Settings.extension",
            keywords: ["do not disturb", "focus mode", "sleep", "driving"]
        ),
        PreferenceItem(
            id: "controlcenter",
            title: "Control Center",
            sfSymbol: "switch.2",
            iconColor: NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.50, alpha: 1.0),
            category: .personal,
            settingsURL: "com.apple.ControlCenter-Settings.extension",
            keywords: ["menu bar", "control center", "widgets", "clock", "bluetooth", "wifi"]
        ),
        PreferenceItem(
            id: "spotlight",
            title: "Siri & Spotlight",
            sfSymbol: "magnifyingglass",
            iconColor: .systemPink,
            category: .personal,
            settingsURL: "com.apple.Siri-Settings.extension",
            keywords: ["siri", "spotlight", "search", "apple intelligence"]
        ),
        PreferenceItem(
            id: "exposespaces",
            title: "Exposé & Spaces",
            sfSymbol: "rectangle.3.group",
            iconColor: .systemBlue,
            category: .personal,
            settingsURL: "com.apple.Desktop-Settings.extension",
            keywords: ["expose", "spaces", "hot corner", "mission control", "desktop"]
        ),
    ]

    // MARK: Hardware

    static let hardwareItems: [PreferenceItem] = [
        PreferenceItem(
            id: "displays",
            title: "Displays",
            sfSymbol: "display",
            iconColor: .systemBlue,
            category: .hardware,
            settingsURL: "com.apple.Displays-Settings.extension",
            keywords: ["resolution", "brightness", "refresh rate", "night shift", "true tone", "monitor"]
        ),
        PreferenceItem(
            id: "sound",
            title: "Sound",
            sfSymbol: "speaker.wave.3.fill",
            iconColor: .systemPink,
            category: .hardware,
            settingsURL: "com.apple.Sound-Settings.extension",
            keywords: ["volume", "output", "input", "microphone", "speaker", "alert"]
        ),
        PreferenceItem(
            id: "keyboard",
            title: "Keyboard",
            sfSymbol: "keyboard",
            iconColor: NSColor(calibratedRed: 0.40, green: 0.42, blue: 0.48, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Keyboard-Settings.extension",
            keywords: ["key repeat", "shortcuts", "input sources", "dictation", "text replacement"]
        ),
        PreferenceItem(
            id: "mouse",
            title: "Mouse",
            sfSymbol: "computermouse.fill",
            iconColor: NSColor(calibratedRed: 0.40, green: 0.42, blue: 0.48, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Mouse-Settings.extension",
            keywords: ["tracking", "scrolling", "clicking", "mouse"]
        ),
        PreferenceItem(
            id: "trackpad",
            title: "Trackpad",
            sfSymbol: "rectangle.and.hand.point.up.left.fill",
            iconColor: NSColor(calibratedRed: 0.40, green: 0.42, blue: 0.48, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Trackpad-Settings.extension",
            keywords: ["trackpad", "gestures", "tap", "click", "scroll", "force click"]
        ),
        PreferenceItem(
            id: "printers",
            title: "Printers & Scanners",
            sfSymbol: "printer.fill",
            iconColor: NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.75, alpha: 1.0),
            category: .hardware,
            settingsURL: "com.apple.Print-Scan-Settings.extension",
            keywords: ["printer", "scanner", "print", "fax"]
        ),
        PreferenceItem(
            id: "battery",
            title: "Battery",
            sfSymbol: "battery.100.bolt",
            iconColor: .systemGreen,
            category: .hardware,
            settingsURL: "com.apple.Battery-Settings.extension",
            keywords: ["battery", "energy saver", "power", "charging", "low power mode"]
        ),
    ]

    // MARK: Internet & Wireless

    static let internetItems: [PreferenceItem] = [
        PreferenceItem(
            id: "appleid",
            title: "Apple ID",
            sfSymbol: "person.crop.circle.fill",
            iconColor: .systemBlue,
            category: .internetWireless,
            settingsURL: "com.apple.systempreferences.AppleIDSettings",
            keywords: ["apple id", "icloud", "account", "sign in", "apple account"]
        ),
        PreferenceItem(
            id: "wifi",
            title: "Wi-Fi",
            sfSymbol: "wifi",
            iconColor: .systemBlue,
            category: .internetWireless,
            settingsURL: "com.apple.wifi-settings-extension",
            keywords: ["wifi", "wireless", "network", "airport", "connect"]
        ),
        PreferenceItem(
            id: "bluetooth",
            title: "Bluetooth",
            sfSymbol: "wave.3.right",
            iconColor: .systemBlue,
            category: .internetWireless,
            settingsURL: "com.apple.BluetoothSettings",
            keywords: ["bluetooth", "wireless", "pair", "connect", "devices"]
        ),
        PreferenceItem(
            id: "network",
            title: "Network",
            sfSymbol: "network",
            iconColor: .systemBlue,
            category: .internetWireless,
            settingsURL: "com.apple.Network-Settings.extension",
            keywords: ["ethernet", "vpn", "dns", "proxy", "firewall", "ip"]
        ),
        PreferenceItem(
            id: "internetaccounts",
            title: "Internet Accounts",
            sfSymbol: "at",
            iconColor: .systemBlue,
            category: .internetWireless,
            settingsURL: "com.apple.Internet-Accounts-Settings.extension",
            keywords: ["email", "contacts", "calendar", "google", "exchange", "account"]
        ),
        PreferenceItem(
            id: "sharing",
            title: "Sharing",
            sfSymbol: "person.2.fill",
            iconColor: .systemBlue,
            category: .internetWireless,
            settingsURL: "com.apple.Sharing-Settings.extension",
            keywords: ["sharing", "file sharing", "screen sharing", "remote login", "airdrop", "hostname"]
        ),
    ]

    // MARK: System

    static let systemItems: [PreferenceItem] = [
        PreferenceItem(
            id: "general",
            title: "General",
            sfSymbol: "gearshape",
            iconColor: NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.55, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.systempreferences.GeneralSettings",
            keywords: ["about", "software update", "storage", "airdrop", "login items", "language"]
        ),
        PreferenceItem(
            id: "users",
            title: "Users & Groups",
            sfSymbol: "person.2.fill",
            iconColor: .systemBlue,
            category: .system,
            settingsURL: "com.apple.Users-Groups-Settings.extension",
            keywords: ["users", "accounts", "login", "password", "admin", "guest"]
        ),
        PreferenceItem(
            id: "passwords",
            title: "Passwords",
            sfSymbol: "key.fill",
            iconColor: .systemYellow,
            category: .system,
            settingsURL: "com.apple.Passwords-Settings.extension",
            keywords: ["passwords", "keychain", "passkey", "autofill"]
        ),
        PreferenceItem(
            id: "touchid",
            title: "Touch ID & Password",
            sfSymbol: "touchid",
            iconColor: .systemRed,
            category: .system,
            settingsURL: "com.apple.Touch-ID-Settings.extension",
            keywords: ["touch id", "fingerprint", "password", "login", "biometric"]
        ),
        PreferenceItem(
            id: "privacy",
            title: "Privacy & Security",
            sfSymbol: "hand.raised.fill",
            iconColor: .systemBlue,
            category: .system,
            settingsURL: "com.apple.settings.PrivacySecurity.extension",
            keywords: ["privacy", "security", "location", "camera", "microphone", "filevault", "firewall"]
        ),
        PreferenceItem(
            id: "datetime",
            title: "Date & Time",
            sfSymbol: "clock.fill",
            iconColor: .systemBlue,
            category: .system,
            settingsURL: "com.apple.Date-Time-Settings.extension",
            keywords: ["date", "time", "timezone", "clock", "ntp"]
        ),
        PreferenceItem(
            id: "softwareupdate",
            title: "Software Update",
            sfSymbol: "arrow.triangle.2.circlepath",
            iconColor: .systemBlue,
            category: .system,
            settingsURL: "com.apple.Software-Update-Settings.extension",
            keywords: ["update", "upgrade", "macos", "automatic updates"]
        ),
        PreferenceItem(
            id: "accessibility",
            title: "Accessibility",
            sfSymbol: "accessibility",
            iconColor: .systemBlue,
            category: .system,
            settingsURL: "com.apple.Accessibility-Settings.extension",
            keywords: ["voiceover", "zoom", "display", "hearing", "motor", "switch control"]
        ),
        PreferenceItem(
            id: "screentime",
            title: "Screen Time",
            sfSymbol: "hourglass",
            iconColor: .systemPurple,
            category: .system,
            settingsURL: "com.apple.Screen-Time-Settings.extension",
            keywords: ["screen time", "parental controls", "app limits", "downtime"]
        ),
        PreferenceItem(
            id: "lockscreen",
            title: "Lock Screen",
            sfSymbol: "lock.fill",
            iconColor: .systemYellow,
            category: .system,
            settingsURL: "com.apple.Lock-Screen-Settings.extension",
            keywords: ["lock", "login window", "message", "sleep", "screensaver"]
        ),
        PreferenceItem(
            id: "startupdisk",
            title: "Startup Disk",
            sfSymbol: "internaldrive.fill",
            iconColor: NSColor(calibratedRed: 0.50, green: 0.50, blue: 0.55, alpha: 1.0),
            category: .system,
            settingsURL: "com.apple.Startup-Disk-Settings.extension",
            keywords: ["startup", "boot", "disk", "volume"]
        ),
        PreferenceItem(
            id: "timemachine",
            title: "Time Machine",
            sfSymbol: "clock.arrow.circlepath",
            iconColor: .systemGreen,
            category: .system,
            settingsURL: "com.apple.Time-Machine-Settings.extension",
            keywords: ["backup", "time machine", "restore"]
        ),
        PreferenceItem(
            id: "gamecenter",
            title: "Game Center",
            sfSymbol: "gamecontroller.fill",
            iconColor: .systemPink,
            category: .system,
            settingsURL: "com.apple.Game-Center-Settings.extension",
            keywords: ["game center", "gaming", "friends", "achievements"]
        ),
        PreferenceItem(
            id: "wallet",
            title: "Wallet & Apple Pay",
            sfSymbol: "creditcard.fill",
            iconColor: .systemYellow,
            category: .system,
            settingsURL: "com.apple.WalletSettingsExtension",
            keywords: ["wallet", "apple pay", "credit card", "payment"]
        ),
    ]
}
