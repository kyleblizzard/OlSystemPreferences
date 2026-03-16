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
        KnownApp(bundleIdentifier: "com.vivaldi.Vivaldi", displayName: "Vivaldi", keywords: ["browser", "web", "vivaldi"]),
        KnownApp(bundleIdentifier: "org.chromium.Chromium", displayName: "Chromium", keywords: ["browser", "web", "chromium"]),
        KnownApp(bundleIdentifier: "com.nickvision.nicepaper", displayName: "Orion", keywords: ["browser", "web", "orion"]),

        // Development — IDEs & Editors
        KnownApp(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode", keywords: ["development", "ide", "xcode", "apple"]),
        KnownApp(bundleIdentifier: "com.microsoft.VSCode", displayName: "VS Code", keywords: ["development", "editor", "code", "vscode"]),
        KnownApp(bundleIdentifier: "com.googlecode.iterm2", displayName: "iTerm", keywords: ["terminal", "shell", "iterm"]),
        KnownApp(bundleIdentifier: "com.sublimetext.4", displayName: "Sublime Text", keywords: ["editor", "text", "sublime"]),
        KnownApp(bundleIdentifier: "com.todesktop.230313mzl4w4u92", displayName: "Cursor", keywords: ["development", "editor", "cursor", "ai"]),
        KnownApp(bundleIdentifier: "dev.zed.Zed", displayName: "Zed", keywords: ["development", "editor", "zed"]),
        KnownApp(bundleIdentifier: "com.github.atom", displayName: "Atom", keywords: ["editor", "text", "atom", "github"]),
        KnownApp(bundleIdentifier: "com.panic.Nova", displayName: "Nova", keywords: ["editor", "web", "nova", "panic"]),
        KnownApp(bundleIdentifier: "com.barebones.bbedit", displayName: "BBEdit", keywords: ["editor", "text", "bbedit"]),
        KnownApp(bundleIdentifier: "com.coteditor.CotEditor", displayName: "CotEditor", keywords: ["editor", "text", "coteditor"]),

        // Development — JetBrains IDEs
        KnownApp(bundleIdentifier: "com.jetbrains.intellij", displayName: "IntelliJ IDEA", keywords: ["development", "ide", "java", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.WebStorm", displayName: "WebStorm", keywords: ["development", "ide", "javascript", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.pycharm", displayName: "PyCharm", keywords: ["development", "ide", "python", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.CLion", displayName: "CLion", keywords: ["development", "ide", "c++", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.goland", displayName: "GoLand", keywords: ["development", "ide", "go", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.rider", displayName: "Rider", keywords: ["development", "ide", "dotnet", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.rubymine", displayName: "RubyMine", keywords: ["development", "ide", "ruby", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.PhpStorm", displayName: "PhpStorm", keywords: ["development", "ide", "php", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.AppCode", displayName: "AppCode", keywords: ["development", "ide", "swift", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.datagrip", displayName: "DataGrip", keywords: ["database", "sql", "jetbrains"]),
        KnownApp(bundleIdentifier: "com.jetbrains.fleet", displayName: "Fleet", keywords: ["editor", "jetbrains", "fleet"]),

        // Development — Tools
        KnownApp(bundleIdentifier: "com.docker.docker", displayName: "Docker", keywords: ["containers", "docker", "development"]),
        KnownApp(bundleIdentifier: "com.postmanlabs.mac", displayName: "Postman", keywords: ["api", "http", "postman", "development"]),
        KnownApp(bundleIdentifier: "com.insomnia.app", displayName: "Insomnia", keywords: ["api", "http", "insomnia"]),
        KnownApp(bundleIdentifier: "com.github.GitHubClient", displayName: "GitHub Desktop", keywords: ["git", "github", "development"]),
        KnownApp(bundleIdentifier: "com.torusknot.SourceTreeNotMAS", displayName: "Sourcetree", keywords: ["git", "sourcetree", "development"]),
        KnownApp(bundleIdentifier: "com.git-tower.Tower3", displayName: "Tower", keywords: ["git", "tower", "development"]),
        KnownApp(bundleIdentifier: "com.nspnk.LaunchControl", displayName: "LaunchControl", keywords: ["launchd", "services", "development"]),
        KnownApp(bundleIdentifier: "com.charliemonroe.Downie-4", displayName: "Downie", keywords: ["download", "video", "downie"]),

        // Apple Built-in Apps
        KnownApp(bundleIdentifier: "com.apple.Terminal", displayName: "Terminal", keywords: ["terminal", "shell", "command", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.ActivityMonitor", displayName: "Activity Monitor", keywords: ["processes", "cpu", "memory", "activity"]),
        KnownApp(bundleIdentifier: "com.apple.DiskUtility", displayName: "Disk Utility", keywords: ["disk", "partition", "format", "utility"]),
        KnownApp(bundleIdentifier: "com.apple.KeychainAccess", displayName: "Keychain Access", keywords: ["keychain", "password", "certificate", "security"]),
        KnownApp(bundleIdentifier: "com.apple.Console", displayName: "Console", keywords: ["logs", "console", "debug", "system"]),
        KnownApp(bundleIdentifier: "com.apple.DigitalColorMeter", displayName: "Digital Color Meter", keywords: ["color", "picker", "measure"]),
        KnownApp(bundleIdentifier: "com.apple.ScriptEditor2", displayName: "Script Editor", keywords: ["applescript", "script", "automation"]),
        KnownApp(bundleIdentifier: "com.apple.Automator", displayName: "Automator", keywords: ["automation", "workflow", "automator"]),
        KnownApp(bundleIdentifier: "com.apple.iWork.Pages", displayName: "Pages", keywords: ["document", "writing", "apple", "pages"]),
        KnownApp(bundleIdentifier: "com.apple.iWork.Numbers", displayName: "Numbers", keywords: ["spreadsheet", "apple", "numbers"]),
        KnownApp(bundleIdentifier: "com.apple.iWork.Keynote", displayName: "Keynote", keywords: ["presentation", "slides", "apple", "keynote"]),
        KnownApp(bundleIdentifier: "com.apple.garageband10", displayName: "GarageBand", keywords: ["music", "audio", "garageband", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.iMovieApp", displayName: "iMovie", keywords: ["video", "editing", "imovie", "apple"]),

        // Creative — Adobe
        KnownApp(bundleIdentifier: "com.adobe.Photoshop", displayName: "Photoshop", keywords: ["adobe", "photo", "image", "design"]),
        KnownApp(bundleIdentifier: "com.adobe.Illustrator", displayName: "Illustrator", keywords: ["adobe", "vector", "design", "illustration"]),
        KnownApp(bundleIdentifier: "com.adobe.PremierePro", displayName: "Premiere Pro", keywords: ["adobe", "video", "editing"]),
        KnownApp(bundleIdentifier: "com.adobe.AfterEffects", displayName: "After Effects", keywords: ["adobe", "motion", "vfx", "compositing"]),
        KnownApp(bundleIdentifier: "com.adobe.LightroomClassicCC7", displayName: "Lightroom", keywords: ["adobe", "photo", "raw", "lightroom"]),
        KnownApp(bundleIdentifier: "com.adobe.InDesign", displayName: "InDesign", keywords: ["adobe", "layout", "publishing"]),
        KnownApp(bundleIdentifier: "com.adobe.Adobe-XD", displayName: "Adobe XD", keywords: ["adobe", "design", "prototype", "xd"]),
        KnownApp(bundleIdentifier: "com.adobe.Audition", displayName: "Audition", keywords: ["adobe", "audio", "editing"]),
        KnownApp(bundleIdentifier: "com.adobe.Animate", displayName: "Animate", keywords: ["adobe", "animation", "flash"]),

        // Creative — Affinity Suite (v1 and v2 bundle IDs)
        KnownApp(bundleIdentifier: "com.seriflabs.affinitydesigner2", displayName: "Affinity Designer 2", keywords: ["design", "vector", "affinity"]),
        KnownApp(bundleIdentifier: "com.seriflabs.affinitydesigner", displayName: "Affinity Designer", keywords: ["design", "vector", "affinity"]),
        KnownApp(bundleIdentifier: "com.seriflabs.affinityphoto2", displayName: "Affinity Photo 2", keywords: ["photo", "editing", "affinity"]),
        KnownApp(bundleIdentifier: "com.seriflabs.affinityphoto", displayName: "Affinity Photo", keywords: ["photo", "editing", "affinity"]),
        KnownApp(bundleIdentifier: "com.seriflabs.affinitypublisher2", displayName: "Affinity Publisher 2", keywords: ["publishing", "layout", "affinity"]),
        KnownApp(bundleIdentifier: "com.seriflabs.affinitypublisher", displayName: "Affinity Publisher", keywords: ["publishing", "layout", "affinity"]),

        // Creative — Apple & Other
        KnownApp(bundleIdentifier: "com.apple.FinalCut", displayName: "Final Cut Pro", keywords: ["video", "editing", "apple", "final cut"]),
        KnownApp(bundleIdentifier: "com.apple.logic10", displayName: "Logic Pro", keywords: ["music", "audio", "daw", "apple", "logic"]),
        KnownApp(bundleIdentifier: "com.blackmagic-design.DaVinciResolve", displayName: "DaVinci Resolve", keywords: ["video", "color", "editing", "davinci"]),
        KnownApp(bundleIdentifier: "com.figma.Desktop", displayName: "Figma", keywords: ["design", "ui", "prototype", "figma"]),
        KnownApp(bundleIdentifier: "com.bohemiancoding.sketch3", displayName: "Sketch", keywords: ["design", "ui", "vector", "sketch"]),
        KnownApp(bundleIdentifier: "com.bohemiancoding.sketch3.appstore", displayName: "Sketch", keywords: ["design", "ui", "vector", "sketch"]),
        KnownApp(bundleIdentifier: "org.blenderfoundation.blender", displayName: "Blender", keywords: ["3d", "modeling", "animation", "blender"]),
        KnownApp(bundleIdentifier: "com.pixelmatorteam.pixelmator.x", displayName: "Pixelmator Pro", keywords: ["photo", "editing", "pixelmator"]),
        KnownApp(bundleIdentifier: "com.noodlesoft.Hazel", displayName: "Hazel", keywords: ["automation", "files", "hazel"]),

        // Communication
        KnownApp(bundleIdentifier: "com.tinyspeck.slackmacgap", displayName: "Slack", keywords: ["chat", "messaging", "work", "slack"]),
        KnownApp(bundleIdentifier: "com.hnc.Discord", displayName: "Discord", keywords: ["chat", "voice", "gaming", "discord"]),
        KnownApp(bundleIdentifier: "us.zoom.xos", displayName: "Zoom", keywords: ["video", "meetings", "zoom", "call"]),
        KnownApp(bundleIdentifier: "ru.keepcoder.Telegram", displayName: "Telegram", keywords: ["chat", "messaging", "telegram"]),
        KnownApp(bundleIdentifier: "com.microsoft.teams2", displayName: "Teams", keywords: ["chat", "meetings", "microsoft", "teams"]),
        KnownApp(bundleIdentifier: "net.whatsapp.WhatsApp", displayName: "WhatsApp", keywords: ["chat", "messaging", "whatsapp"]),
        KnownApp(bundleIdentifier: "com.skype.skype", displayName: "Skype", keywords: ["video", "call", "chat", "skype"]),
        KnownApp(bundleIdentifier: "com.webex.meetingmanager", displayName: "Webex", keywords: ["video", "meetings", "webex", "cisco"]),
        KnownApp(bundleIdentifier: "com.facebook.archon.developerID", displayName: "Messenger", keywords: ["chat", "messaging", "facebook"]),
        KnownApp(bundleIdentifier: "is.workflow.my.app", displayName: "Signal", keywords: ["chat", "messaging", "signal", "privacy"]),

        // Productivity
        KnownApp(bundleIdentifier: "notion.id", displayName: "Notion", keywords: ["notes", "wiki", "database", "notion"]),
        KnownApp(bundleIdentifier: "md.obsidian", displayName: "Obsidian", keywords: ["notes", "markdown", "obsidian"]),
        KnownApp(bundleIdentifier: "com.1password.1password", displayName: "1Password", keywords: ["password", "security", "1password"]),
        KnownApp(bundleIdentifier: "com.microsoft.Word", displayName: "Word", keywords: ["document", "writing", "microsoft", "word"]),
        KnownApp(bundleIdentifier: "com.microsoft.Excel", displayName: "Excel", keywords: ["spreadsheet", "data", "microsoft", "excel"]),
        KnownApp(bundleIdentifier: "com.microsoft.Powerpoint", displayName: "PowerPoint", keywords: ["presentation", "slides", "microsoft"]),
        KnownApp(bundleIdentifier: "com.microsoft.onenote.mac", displayName: "OneNote", keywords: ["notes", "microsoft", "onenote"]),
        KnownApp(bundleIdentifier: "com.microsoft.Outlook", displayName: "Outlook", keywords: ["email", "calendar", "microsoft", "outlook"]),
        KnownApp(bundleIdentifier: "com.linear", displayName: "Linear", keywords: ["project", "issues", "linear", "tasks"]),
        KnownApp(bundleIdentifier: "com.raycast.macos", displayName: "Raycast", keywords: ["launcher", "productivity", "raycast"]),
        KnownApp(bundleIdentifier: "com.flexibits.fantastical2", displayName: "Fantastical", keywords: ["calendar", "schedule", "fantastical"]),
        KnownApp(bundleIdentifier: "com.todoist.mac.Todoist", displayName: "Todoist", keywords: ["tasks", "todo", "todoist"]),
        KnownApp(bundleIdentifier: "com.culturedcode.ThingsMac", displayName: "Things 3", keywords: ["tasks", "todo", "things", "gtd"]),
        KnownApp(bundleIdentifier: "com.omnigroup.OmniFocus3", displayName: "OmniFocus", keywords: ["tasks", "todo", "omnifocus", "gtd"]),
        KnownApp(bundleIdentifier: "com.agiletortoise.Drafts-OSX", displayName: "Drafts", keywords: ["notes", "text", "drafts"]),
        KnownApp(bundleIdentifier: "com.bitwarden.desktop", displayName: "Bitwarden", keywords: ["password", "security", "bitwarden"]),

        // Cloud Storage
        KnownApp(bundleIdentifier: "com.getdropbox.dropbox", displayName: "Dropbox", keywords: ["cloud", "storage", "sync", "dropbox"]),
        KnownApp(bundleIdentifier: "com.google.drivefs", displayName: "Google Drive", keywords: ["cloud", "storage", "sync", "google"]),
        KnownApp(bundleIdentifier: "com.microsoft.OneDrive", displayName: "OneDrive", keywords: ["cloud", "storage", "sync", "microsoft"]),
        KnownApp(bundleIdentifier: "com.boxinc.Box-Drive", displayName: "Box", keywords: ["cloud", "storage", "sync", "box"]),

        // VPN & Networking
        KnownApp(bundleIdentifier: "io.tailscale.ipn.macos", displayName: "Tailscale", keywords: ["vpn", "network", "tailscale"]),
        KnownApp(bundleIdentifier: "com.wireguard.macos", displayName: "WireGuard", keywords: ["vpn", "network", "wireguard"]),
        KnownApp(bundleIdentifier: "com.nordvpn.osx", displayName: "NordVPN", keywords: ["vpn", "privacy", "nordvpn"]),
        KnownApp(bundleIdentifier: "com.nordvpn.NordVPN", displayName: "NordVPN", keywords: ["vpn", "privacy", "nordvpn"]),
        KnownApp(bundleIdentifier: "com.nordvpn.osx-apple", displayName: "NordVPN IKE", keywords: ["vpn", "privacy", "nordvpn"]),
        KnownApp(bundleIdentifier: "com.expressvpn.ExpressVPN", displayName: "ExpressVPN", keywords: ["vpn", "privacy", "expressvpn"]),
        KnownApp(bundleIdentifier: "com.cloudflare.1dot1dot1dot1.macos", displayName: "Cloudflare WARP", keywords: ["vpn", "dns", "cloudflare"]),

        // Utilities
        KnownApp(bundleIdentifier: "com.knollsoft.Rectangle", displayName: "Rectangle", keywords: ["window", "management", "rectangle", "tiling"]),
        KnownApp(bundleIdentifier: "com.hegenberg.BetterTouchTool", displayName: "BetterTouchTool", keywords: ["trackpad", "gestures", "automation", "touch"]),
        KnownApp(bundleIdentifier: "com.hegenberg.BetterSnapTool", displayName: "BetterSnapTool", keywords: ["window", "management", "snap", "tiling"]),
        KnownApp(bundleIdentifier: "com.surteesstudios.Bartender", displayName: "Bartender", keywords: ["menu bar", "organize", "bartender"]),
        KnownApp(bundleIdentifier: "com.macpaw.CleanMyMac4", displayName: "CleanMyMac", keywords: ["cleaner", "maintenance", "cleanmymac"]),
        KnownApp(bundleIdentifier: "com.objective-see.lulu.app", displayName: "LuLu", keywords: ["firewall", "security", "lulu"]),
        KnownApp(bundleIdentifier: "com.txhaflern.hand-mirror", displayName: "Hand Mirror", keywords: ["camera", "mirror", "utility"]),
        KnownApp(bundleIdentifier: "com.sindresorhus.Lungo", displayName: "Lungo", keywords: ["caffeine", "sleep", "awake"]),
        KnownApp(bundleIdentifier: "com.if.Amphetamine", displayName: "Amphetamine", keywords: ["caffeine", "sleep", "awake"]),
        KnownApp(bundleIdentifier: "com.bjango.istatmenus", displayName: "iStat Menus", keywords: ["system", "monitor", "cpu", "memory", "istat"]),
        KnownApp(bundleIdentifier: "com.apphousekitchen.aldente-pro", displayName: "AlDente", keywords: ["battery", "charge", "limit", "aldente"]),
        KnownApp(bundleIdentifier: "com.p5sys.jump.mac.viewer", displayName: "Jump Desktop", keywords: ["remote", "desktop", "vnc"]),
        KnownApp(bundleIdentifier: "com.lwouis.alt-tab-macos", displayName: "AltTab", keywords: ["window", "switcher", "alt-tab"]),
        KnownApp(bundleIdentifier: "com.mowglii.ItsycalApp", displayName: "Itsycal", keywords: ["calendar", "menu bar", "itsycal"]),

        // Media
        KnownApp(bundleIdentifier: "com.spotify.client", displayName: "Spotify", keywords: ["music", "streaming", "spotify"]),
        KnownApp(bundleIdentifier: "org.videolan.vlc", displayName: "VLC", keywords: ["video", "media", "player", "vlc"]),
        KnownApp(bundleIdentifier: "com.colliderli.iina", displayName: "IINA", keywords: ["video", "media", "player", "iina"]),
        KnownApp(bundleIdentifier: "com.rogueamoeba.audiohijack", displayName: "Audio Hijack", keywords: ["audio", "recording", "hijack"]),
        KnownApp(bundleIdentifier: "com.plexapp.plexmediaplayer", displayName: "Plex", keywords: ["media", "streaming", "server", "plex"]),
        KnownApp(bundleIdentifier: "com.apple.Music", displayName: "Music", keywords: ["music", "apple music", "itunes"]),
        KnownApp(bundleIdentifier: "com.apple.TV", displayName: "Apple TV", keywords: ["video", "streaming", "apple tv"]),
        KnownApp(bundleIdentifier: "com.apple.podcasts", displayName: "Podcasts", keywords: ["podcast", "audio", "apple"]),

        // Gaming
        KnownApp(bundleIdentifier: "com.valvesoftware.steam", displayName: "Steam", keywords: ["games", "gaming", "steam"]),
        KnownApp(bundleIdentifier: "com.epicgames.EpicGamesLauncher", displayName: "Epic Games", keywords: ["games", "gaming", "epic"]),
        KnownApp(bundleIdentifier: "com.battle.net", displayName: "Battle.net", keywords: ["games", "gaming", "blizzard"]),
        KnownApp(bundleIdentifier: "com.gog.galaxy", displayName: "GOG Galaxy", keywords: ["games", "gaming", "gog"]),
        KnownApp(bundleIdentifier: "org.openemu.OpenEmu", displayName: "OpenEmu", keywords: ["games", "emulator", "retro", "openemu"]),

        // Virtualization & Emulation
        KnownApp(bundleIdentifier: "com.parallels.desktop.console", displayName: "Parallels Desktop", keywords: ["virtual", "machine", "windows", "parallels"]),
        KnownApp(bundleIdentifier: "com.utmapp.UTM", displayName: "UTM", keywords: ["virtual", "machine", "emulator", "utm"]),
        KnownApp(bundleIdentifier: "com.codeweavers.CrossOver", displayName: "CrossOver", keywords: ["wine", "windows", "crossover"]),

        // AI & Machine Learning
        KnownApp(bundleIdentifier: "ai.elementlabs.lmstudio", displayName: "LM Studio", keywords: ["ai", "llm", "machine learning", "local"]),
        KnownApp(bundleIdentifier: "com.electron.ollama", displayName: "Ollama", keywords: ["ai", "llm", "local", "ollama"]),
        KnownApp(bundleIdentifier: "com.openai.codex", displayName: "Codex", keywords: ["ai", "code", "openai", "codex"]),
        KnownApp(bundleIdentifier: "ai.perplexity.comet", displayName: "Comet", keywords: ["ai", "search", "perplexity"]),

        // System Tools & Utilities (additional)
        KnownApp(bundleIdentifier: "net.freemacsoft.AppCleaner", displayName: "AppCleaner", keywords: ["uninstall", "cleaner", "utility"]),
        KnownApp(bundleIdentifier: "cx.c3.theunarchiver", displayName: "The Unarchiver", keywords: ["archive", "zip", "extract"]),
        KnownApp(bundleIdentifier: "org.m0k.transmission", displayName: "Transmission", keywords: ["torrent", "download", "transmission"]),
        KnownApp(bundleIdentifier: "ch.sudo.cyberduck", displayName: "Cyberduck", keywords: ["ftp", "sftp", "cloud", "transfer"]),
        KnownApp(bundleIdentifier: "org.filezilla-project.filezilla", displayName: "FileZilla", keywords: ["ftp", "sftp", "transfer"]),
        KnownApp(bundleIdentifier: "io.balena.etcher", displayName: "balenaEtcher", keywords: ["usb", "flash", "bootable", "image"]),
        KnownApp(bundleIdentifier: "com.mactrackerapp.Mactracker", displayName: "Mactracker", keywords: ["hardware", "specs", "apple", "mactracker"]),
        KnownApp(bundleIdentifier: "at.obdev.MicroSnitch", displayName: "Micro Snitch", keywords: ["camera", "microphone", "privacy", "monitor"]),
        KnownApp(bundleIdentifier: "com.resilio.Sync", displayName: "Resilio Sync", keywords: ["sync", "files", "p2p", "resilio"]),
        KnownApp(bundleIdentifier: "com.Replacicon.Replacicon", displayName: "Replacicon", keywords: ["icon", "customization", "replacicon"]),
        KnownApp(bundleIdentifier: "com.ninxsoft.mist", displayName: "Mist", keywords: ["installer", "macos", "download"]),

        // Apple System Apps (additional)
        KnownApp(bundleIdentifier: "com.apple.iWork.Keynote", displayName: "Keynote", keywords: ["presentation", "slides", "apple", "keynote"]),
        KnownApp(bundleIdentifier: "com.apple.iMovieApp", displayName: "iMovie", keywords: ["video", "editing", "imovie", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Compressor", displayName: "Compressor", keywords: ["video", "encoding", "apple", "compressor"]),
        KnownApp(bundleIdentifier: "com.apple.mail", displayName: "Mail", keywords: ["email", "mail", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.iCal", displayName: "Calendar", keywords: ["calendar", "schedule", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Notes", displayName: "Notes", keywords: ["notes", "writing", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.reminders", displayName: "Reminders", keywords: ["tasks", "todo", "apple", "reminders"]),
        KnownApp(bundleIdentifier: "com.apple.MobileSMS", displayName: "Messages", keywords: ["chat", "messaging", "imessage", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.FaceTime", displayName: "FaceTime", keywords: ["video", "call", "apple", "facetime"]),
        KnownApp(bundleIdentifier: "com.apple.Photos", displayName: "Photos", keywords: ["photo", "library", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Maps", displayName: "Maps", keywords: ["maps", "navigation", "directions", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.weather", displayName: "Weather", keywords: ["weather", "forecast", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.news", displayName: "News", keywords: ["news", "reading", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.stocks", displayName: "Stocks", keywords: ["stocks", "finance", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.freeform", displayName: "Freeform", keywords: ["whiteboard", "drawing", "collaboration", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.shortcuts", displayName: "Shortcuts", keywords: ["automation", "shortcuts", "workflow", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Preview", displayName: "Preview", keywords: ["pdf", "image", "viewer", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.TextEdit", displayName: "TextEdit", keywords: ["text", "editor", "rtf", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.FontBook", displayName: "Font Book", keywords: ["fonts", "typography", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Dictionary", displayName: "Dictionary", keywords: ["dictionary", "thesaurus", "reference", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.calculator", displayName: "Calculator", keywords: ["calculator", "math", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.QuickTimePlayerX", displayName: "QuickTime Player", keywords: ["video", "player", "recording", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Image_Capture", displayName: "Image Capture", keywords: ["scanner", "camera", "import", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.SystemProfiler", displayName: "System Information", keywords: ["hardware", "system", "profiler", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.RemoteDesktop", displayName: "Remote Desktop", keywords: ["remote", "vnc", "screen sharing", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.iBooksX", displayName: "Books", keywords: ["books", "ebooks", "reading", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.AppStore", displayName: "App Store", keywords: ["apps", "store", "download", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.findmy", displayName: "Find My", keywords: ["location", "find", "tracking", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Home", displayName: "Home", keywords: ["homekit", "smart home", "automation", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.VoiceMemos", displayName: "Voice Memos", keywords: ["recording", "audio", "voice", "apple"]),
        KnownApp(bundleIdentifier: "com.apple.Passwords", displayName: "Passwords", keywords: ["password", "keychain", "security", "apple"]),

        // Office Suites (additional)
        KnownApp(bundleIdentifier: "org.libreoffice.script", displayName: "LibreOffice", keywords: ["office", "document", "spreadsheet", "libre"]),

        // Creative (additional)
        KnownApp(bundleIdentifier: "com.pixelmatorteam.pixelmator.touch.x.photo", displayName: "Photomator", keywords: ["photo", "editing", "ai", "pixelmator"]),
        KnownApp(bundleIdentifier: "com.rogueamoeba.Airfoil", displayName: "Airfoil", keywords: ["audio", "streaming", "airplay", "rogue amoeba"]),

        // Networking & File Transfer
        KnownApp(bundleIdentifier: "com.edovia.screens.5", displayName: "Screens 5", keywords: ["remote", "vnc", "screen sharing"]),
        KnownApp(bundleIdentifier: "com.rpatechnology.mobilemouse", displayName: "Mobile Mouse Server", keywords: ["remote", "mouse", "control"]),
    ]

    /// Bundle IDs to skip — system launchers, helpers, and installers that don't have
    /// meaningful preferences or don't make sense in the "Other" section.
    private static let excludedBundleIDs: Set<String> = [
        // System Preferences / Settings
        "com.apple.systempreferences",
        // Launchers & Helpers (not real apps with preferences)
        "com.apple.loginwindow",
        "com.apple.exposelauncher",        // Mission Control launcher
        "com.apple.screenshot.launcher",   // Screenshot launcher
        "com.apple.siri.launcher",         // Siri launcher
        "com.apple.apps.launcher",         // Apps launcher
        "com.apple.backup.launcher",       // Time Machine launcher
        "com.apple.AboutThisMacLauncher",  // About This Mac launcher
        // Installers & Migration
        "com.apple.Installer",
        "com.apple.MigrateAssistant",
        "com.apple.bootcampassistant",
        "com.apple.IPAInstaller",
        "com.installaware.miaxstub",       // Game Porting Toolkit installer
        "com.adobe.HDInstall",             // Adobe installer stub
        // System Utilities with no user-facing preferences
        "com.apple.archiveutility",
        "com.apple.printcenter",
        "com.apple.FolderActionsSetup",
        "com.apple.Ticket-Viewer",
        "com.apple.ExpansionSlotUtility",
        "com.apple.DirectoryUtility",
        "com.apple.wifi.diagnostics",
        "com.apple.DeskCam",              // Desk View
        "com.apple.ScreenContinuity",     // iPhone Mirroring
        "com.apple.mobilephone",          // Phone (requires iPhone)
        "com.apple.clock",                // Clock
        "com.apple.appleseed.FeedbackAssistant",
        "com.apple.helpviewer",           // Tips
        "com.apple.Magnifier",
    ]

    /// Scans for installed apps and returns PreferenceItems for the "Other" category.
    /// First checks the known apps list (which provides nice display names and search keywords),
    /// then dynamically scans /Applications for any remaining apps not in the known list.
    static func detectInstalledApps() -> [PreferenceItem] {
        var items: [PreferenceItem] = []
        // Track which bundle IDs we've already added to avoid duplicates
        var addedBundleIDs: Set<String> = []

        // Step 1: Check known apps — these have curated display names and keywords
        for app in knownApps {
            guard !excludedBundleIDs.contains(app.bundleIdentifier) else { continue }
            guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
                continue
            }
            // Skip if we already added this bundle ID (handles duplicate entries like v1/v2 Affinity)
            guard !addedBundleIDs.contains(app.bundleIdentifier) else { continue }
            addedBundleIDs.insert(app.bundleIdentifier)

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

        // Step 2: Dynamically scan /Applications for any apps not already in the known list.
        // This catches every installed app without needing a perfect hardcoded list.
        let dynamicApps = scanApplicationsDirectory()
        for app in dynamicApps {
            guard !addedBundleIDs.contains(app.bundleIdentifier) else { continue }
            guard !excludedBundleIDs.contains(app.bundleIdentifier) else { continue }
            addedBundleIDs.insert(app.bundleIdentifier)

            items.append(PreferenceItem(
                id: "app_\(app.bundleIdentifier)",
                title: app.displayName,
                appBundleIdentifier: app.bundleIdentifier,
                appIcon: app.icon,
                category: .other,
                keywords: app.keywords
            ))
        }

        // Sort alphabetically by display name
        items.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        return items
    }

    /// Represents an app discovered by scanning the filesystem.
    private struct DiscoveredApp {
        let bundleIdentifier: String
        let displayName: String
        let icon: NSImage
        let keywords: [String]
    }

    /// Scans /Applications (including Utilities) and /System/Applications for .app bundles.
    /// Returns basic info for each discovered app.
    private static func scanApplicationsDirectory() -> [DiscoveredApp] {
        var discovered: [DiscoveredApp] = []

        // Directories to scan for apps
        let scanPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices/Applications",
        ]

        let fileManager = FileManager.default

        for scanPath in scanPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: scanPath) else { continue }

            for item in contents {
                guard item.hasSuffix(".app") else { continue }
                let fullPath = (scanPath as NSString).appendingPathComponent(item)

                // Read the bundle identifier from the app's Info.plist
                let plistPath = (fullPath as NSString).appendingPathComponent("Contents/Info.plist")
                guard let plist = NSDictionary(contentsOfFile: plistPath),
                      let bundleID = plist["CFBundleIdentifier"] as? String else {
                    continue
                }

                // Get display name — prefer CFBundleDisplayName, fall back to CFBundleName, then filename
                let displayName = (plist["CFBundleDisplayName"] as? String)
                    ?? (plist["CFBundleName"] as? String)
                    ?? item.replacingOccurrences(of: ".app", with: "")

                // Get the app's icon from the workspace
                let icon = NSWorkspace.shared.icon(forFile: fullPath)
                icon.size = NSSize(width: 64, height: 64)

                // Generate basic search keywords from the display name
                let nameWords = displayName.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { !$0.isEmpty }

                discovered.append(DiscoveredApp(
                    bundleIdentifier: bundleID,
                    displayName: displayName,
                    icon: icon,
                    keywords: nameWords
                ))
            }
        }

        return discovered
    }

    /// Opens an app's preferences. If the app is already running, activates it and sends Cmd+,.
    /// If not running, launches it first, waits briefly, then sends the shortcut.
    static func openAppPreferences(bundleIdentifier: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }

        // Check if the app is already running — if so, just activate and send Cmd+,
        if let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            runningApp.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sendPreferencesShortcut()
            }
            return
        }

        // App not running — launch it, then send the shortcut after a delay
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                sendPreferencesShortcut()
            }
        }
    }

    /// Sends Cmd+, keystroke via AppleScript to open the frontmost app's preferences.
    private static func sendPreferencesShortcut() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "," using command down
            end tell
        """)
        var errorInfo: NSDictionary?
        script?.executeAndReturnError(&errorInfo)
    }
}
