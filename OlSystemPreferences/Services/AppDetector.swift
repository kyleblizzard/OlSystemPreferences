import Cocoa

/// Detects installed third-party apps and creates PreferenceItems for their settings.
/// Apps are opened and sent Cmd+, to trigger their Preferences window.
class AppDetector {

    struct KnownApp {
        let bundleIdentifier: String
        let displayName: String
        let keywords: [String]
    }

    static let knownApps: [KnownApp] = [
        // Browsers
        KnownApp(bundleIdentifier: "com.apple.Safari", displayName: "Safari", keywords: ["browser", "web", "safari"]),
        KnownApp(bundleIdentifier: "com.google.Chrome", displayName: "Chrome", keywords: ["browser", "web", "chrome", "google"]),
        KnownApp(bundleIdentifier: "org.mozilla.firefox", displayName: "Firefox", keywords: ["browser", "web", "firefox", "mozilla"]),
        KnownApp(bundleIdentifier: "company.thebrowser.Browser", displayName: "Arc", keywords: ["browser", "web", "arc"]),
        KnownApp(bundleIdentifier: "com.microsoft.edgemac", displayName: "Edge", keywords: ["browser", "web", "edge", "microsoft"]),
        KnownApp(bundleIdentifier: "com.brave.Browser", displayName: "Brave", keywords: ["browser", "web", "brave"]),
        KnownApp(bundleIdentifier: "com.operasoftware.Opera", displayName: "Opera", keywords: ["browser", "web", "opera"]),

        // Development
        KnownApp(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode", keywords: ["development", "ide", "xcode", "apple"]),
        KnownApp(bundleIdentifier: "com.microsoft.VSCode", displayName: "VS Code", keywords: ["development", "editor", "code", "vscode"]),
        KnownApp(bundleIdentifier: "com.googlecode.iterm2", displayName: "iTerm", keywords: ["terminal", "shell", "iterm"]),
        KnownApp(bundleIdentifier: "com.sublimetext.4", displayName: "Sublime Text", keywords: ["editor", "text", "sublime"]),
        KnownApp(bundleIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor", keywords: ["development", "editor", "cursor", "ai"]),

        // Creative — Adobe
        KnownApp(bundleIdentifier: "com.adobe.Photoshop", displayName: "Photoshop", keywords: ["adobe", "photo", "image", "design"]),
        KnownApp(bundleIdentifier: "com.adobe.Illustrator", displayName: "Illustrator", keywords: ["adobe", "vector", "design", "illustration"]),
        KnownApp(bundleIdentifier: "com.adobe.PremierePro", displayName: "Premiere Pro", keywords: ["adobe", "video", "editing"]),
        KnownApp(bundleIdentifier: "com.adobe.AfterEffects", displayName: "After Effects", keywords: ["adobe", "motion", "vfx", "compositing"]),
        KnownApp(bundleIdentifier: "com.adobe.LightroomClassicCC7", displayName: "Lightroom", keywords: ["adobe", "photo", "raw", "lightroom"]),
        KnownApp(bundleIdentifier: "com.adobe.InDesign", displayName: "InDesign", keywords: ["adobe", "layout", "publishing"]),

        // Creative — Apple & Other
        KnownApp(bundleIdentifier: "com.apple.FinalCut", displayName: "Final Cut Pro", keywords: ["video", "editing", "apple", "final cut"]),
        KnownApp(bundleIdentifier: "com.apple.logic10", displayName: "Logic Pro", keywords: ["music", "audio", "daw", "apple", "logic"]),
        KnownApp(bundleIdentifier: "com.blackmagic-design.DaVinciResolve", displayName: "DaVinci Resolve", keywords: ["video", "color", "editing", "davinci"]),
        KnownApp(bundleIdentifier: "com.figma.Desktop", displayName: "Figma", keywords: ["design", "ui", "prototype", "figma"]),
        KnownApp(bundleIdentifier: "com.bohemiancoding.sketch3", displayName: "Sketch", keywords: ["design", "ui", "vector", "sketch"]),
        KnownApp(bundleIdentifier: "org.blenderfoundation.blender", displayName: "Blender", keywords: ["3d", "modeling", "animation", "blender"]),

        // Communication
        KnownApp(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack", keywords: ["chat", "messaging", "work", "slack"]),
        KnownApp(bundleIdentifier: "com.hnc.Discord", displayName: "Discord", keywords: ["chat", "voice", "gaming", "discord"]),
        KnownApp(bundleIdentifier: "us.zoom.xos", displayName: "Zoom", keywords: ["video", "meetings", "zoom", "call"]),
        KnownApp(bundleIdentifier: "ru.keepcoder.Telegram", displayName: "Telegram", keywords: ["chat", "messaging", "telegram"]),
        KnownApp(bundleIdentifier: "com.microsoft.teams2", displayName: "Teams", keywords: ["chat", "meetings", "microsoft", "teams"]),

        // Productivity
        KnownApp(bundleIdentifier: "notion.id", displayName: "Notion", keywords: ["notes", "wiki", "database", "notion"]),
        KnownApp(bundleIdentifier: "md.obsidian", displayName: "Obsidian", keywords: ["notes", "markdown", "obsidian"]),
        KnownApp(bundleIdentifier: "com.1password.1password", displayName: "1Password", keywords: ["password", "security", "1password"]),
        KnownApp(bundleIdentifier: "com.microsoft.Word", displayName: "Word", keywords: ["document", "writing", "microsoft", "word"]),
        KnownApp(bundleIdentifier: "com.microsoft.Excel", displayName: "Excel", keywords: ["spreadsheet", "data", "microsoft", "excel"]),
        KnownApp(bundleIdentifier: "com.linear", displayName: "Linear", keywords: ["project", "issues", "linear", "tasks"]),
        KnownApp(bundleIdentifier: "com.raycast.macos", displayName: "Raycast", keywords: ["launcher", "productivity", "raycast"]),

        // Media
        KnownApp(bundleIdentifier: "com.spotify.client", displayName: "Spotify", keywords: ["music", "streaming", "spotify"]),
        KnownApp(bundleIdentifier: "org.videolan.vlc", displayName: "VLC", keywords: ["video", "media", "player", "vlc"]),
        KnownApp(bundleIdentifier: "com.colliderli.iina", displayName: "IINA", keywords: ["video", "media", "player", "iina"]),

        // Other
        KnownApp(bundleIdentifier: "com.valvesoftware.steam", displayName: "Steam", keywords: ["games", "gaming", "steam"]),
        KnownApp(bundleIdentifier: "com.docker.docker", displayName: "Docker", keywords: ["containers", "docker", "development"]),
    ]

    /// Scans for installed apps and returns PreferenceItems for the "Other" category.
    static func detectInstalledApps() -> [PreferenceItem] {
        var items: [PreferenceItem] = []

        for app in knownApps {
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
                continue
            }

            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 64, height: 64)

            items.append(PreferenceItem(
                id: "app_\(app.bundleIdentifier)",
                title: app.displayName,
                appBundleIdentifier: app.bundleIdentifier,
                appIcon: icon,
                category: .other,
                keywords: app.keywords
            ))
        }

        return items
    }

    /// Opens an app and sends Cmd+, to trigger its Preferences window.
    static func openAppPreferences(bundleIdentifier: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }

        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let script = NSAppleScript(source: """
                    tell application "System Events"
                        keystroke "," using command down
                    end tell
                """)
                var errorInfo: NSDictionary?
                script?.executeAndReturnError(&errorInfo)
            }
        }
    }
}
