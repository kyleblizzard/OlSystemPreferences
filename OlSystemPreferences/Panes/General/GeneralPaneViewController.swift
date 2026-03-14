import Cocoa

class GeneralPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "general" }
    var paneTitle: String { "Appearance" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: "Appearance") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] { ["appearance", "dark mode", "light mode", "accent", "highlight", "scroll", "sidebar"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.systempreferences.GeneralSettings" }

    private let defaults = DefaultsService.shared

    // MARK: - UI Elements

    // Appearance (maps to Light / Dark / Auto)
    private let appearanceLabel = NSTextField(labelWithString: "Appearance:")
    private let blueButton = NSButton(radioButtonWithTitle: "Blue", target: nil, action: nil)
    private let graphiteButton = NSButton(radioButtonWithTitle: "Graphite", target: nil, action: nil)

    // Modern mapping: Blue = Light, Graphite = Dark, plus Auto
    private let lightButton = AquaRadioButton(title: "Light", isSelected: false)
    private let darkButton = AquaRadioButton(title: "Dark", isSelected: false)
    private let autoButton = AquaRadioButton(title: "Auto", isSelected: false)

    // Accent color (Highlight color in Snow Leopard)
    private let highlightColorLabel = NSTextField(labelWithString: "Highlight color:")
    private let accentColorButtons: [NSButton] = {
        let colors: [(String, NSColor)] = [
            ("Blue", .systemBlue),
            ("Purple", .systemPurple),
            ("Pink", .systemPink),
            ("Red", .systemRed),
            ("Orange", .systemOrange),
            ("Yellow", .systemYellow),
            ("Green", .systemGreen),
            ("Graphite", .systemGray),
        ]
        return colors.map { name, color in
            let btn = NSButton()
            btn.bezelStyle = .circular
            btn.title = ""
            btn.wantsLayer = true
            btn.layer?.backgroundColor = color.cgColor
            btn.layer?.cornerRadius = 10
            btn.widthAnchor.constraint(equalToConstant: 20).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 20).isActive = true
            btn.toolTip = name
            return btn
        }
    }()

    // Scroll arrows placement (Snow Leopard: Together / At top and bottom)
    // Maps to modern: Show scroll bars popup
    private let scrollBarsLabel = NSTextField(labelWithString: "Place scroll arrows:")
    private let scrollBarsPopup = AquaPopUpButton(items: [
        "Automatically based on mouse or trackpad",
        "When scrolling",
        "Always"
    ], selectedIndex: 0)

    // Click in scroll bar
    private let scrollClickLabel = NSTextField(labelWithString: "Click in the scroll bar to:")
    private let jumpToPageButton = AquaRadioButton(title: "Jump to the next page", isSelected: false)
    private let jumpToSpotButton = AquaRadioButton(title: "Jump to the spot that's clicked", isSelected: false)

    // Use smooth scrolling (Snow Leopard checkbox)
    private let smoothScrollingCheck = AquaCheckbox(title: "Use smooth scrolling", isChecked: false)

    // Minimize when double-clicking title bar
    private let doubleClickTitleBarCheck = AquaCheckbox(title: "Minimize when double clicking a window title bar", isChecked: false)

    // Sidebar icon size (Number of Recent Items equivalent)
    private let sidebarSizeLabel = NSTextField(labelWithString: "Sidebar icon size:")
    private let sidebarSizePopup = AquaPopUpButton(items: ["Small", "Medium", "Large"], selectedIndex: 0)

    // Number of Recent Items
    private let recentItemsLabel = NSTextField(labelWithString: "Number of recent items:")
    private let recentAppsPopup = AquaPopUpButton(items: [], selectedIndex: 0)
    private let recentDocsPopup = AquaPopUpButton(items: [], selectedIndex: 0)
    private let recentServersPopup = AquaPopUpButton(items: [], selectedIndex: 0)
    private let recentItemValues = ["0", "5", "10", "15", "20", "30", "50"]

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        // Main vertical stack
        let mainStack = NSStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 0
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 20, right: 20)

        // --- Pane Header ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        mainStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
        mainStack.setCustomSpacing(12, after: header)

        // --- Separator after header ---
        let headerSep = SnowLeopardPaneHelper.makeSeparator(width: 620)
        mainStack.addArrangedSubview(headerSep)
        mainStack.setCustomSpacing(16, after: headerSep)

        // ===== Section 1: Appearance =====
        let appearanceBox = SnowLeopardPaneHelper.makeSectionBox()
        let appearanceContent = NSStackView()
        appearanceContent.translatesAutoresizingMaskIntoConstraints = false
        appearanceContent.orientation = .vertical
        appearanceContent.alignment = .leading
        appearanceContent.spacing = 10

        // Appearance row (Light / Dark / Auto)
        styleAllLabels()
        lightButton.groupTag = 1
        darkButton.groupTag = 1
        autoButton.groupTag = 1
        lightButton.target = self; lightButton.action = #selector(appearanceChanged(_:))
        darkButton.target = self; darkButton.action = #selector(appearanceChanged(_:))
        autoButton.target = self; autoButton.action = #selector(appearanceChanged(_:))
        let appearanceRow = SnowLeopardPaneHelper.makeRow(
            label: appearanceLabel,
            controls: [lightButton, darkButton, autoButton]
        )
        appearanceContent.addArrangedSubview(appearanceRow)

        // Highlight (Accent) color row
        let accentRow = SnowLeopardPaneHelper.makeRow(
            label: highlightColorLabel,
            controls: accentColorButtons,
            spacing: 6
        )
        for (index, btn) in accentColorButtons.enumerated() {
            btn.tag = index
            btn.target = self
            btn.action = #selector(accentColorChanged(_:))
        }
        appearanceContent.addArrangedSubview(accentRow)

        appearanceBox.contentView = appearanceContent
        mainStack.addArrangedSubview(appearanceBox)
        appearanceBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
        mainStack.setCustomSpacing(12, after: appearanceBox)

        // ===== Section 2: Scroll Bars =====
        let scrollBox = SnowLeopardPaneHelper.makeSectionBox()
        let scrollContent = NSStackView()
        scrollContent.translatesAutoresizingMaskIntoConstraints = false
        scrollContent.orientation = .vertical
        scrollContent.alignment = .leading
        scrollContent.spacing = 10

        // Show scroll bars popup
        scrollBarsPopup.target = self
        scrollBarsPopup.action = #selector(scrollBarsChanged(_:))
        let scrollRow = SnowLeopardPaneHelper.makeRow(
            label: scrollBarsLabel,
            controls: [scrollBarsPopup]
        )
        scrollContent.addArrangedSubview(scrollRow)

        // Separator within scroll section
        let scrollInnerSep = SnowLeopardPaneHelper.makeSeparator(width: 560)
        scrollContent.addArrangedSubview(scrollInnerSep)

        // Click in scroll bar
        let scrollClickColumn = NSStackView()
        scrollClickColumn.orientation = .vertical
        scrollClickColumn.alignment = .leading
        scrollClickColumn.spacing = 4
        jumpToPageButton.groupTag = 2
        jumpToSpotButton.groupTag = 2
        scrollClickColumn.addArrangedSubview(jumpToPageButton)
        scrollClickColumn.addArrangedSubview(jumpToSpotButton)
        jumpToPageButton.target = self; jumpToPageButton.action = #selector(scrollClickChanged(_:))
        jumpToSpotButton.target = self; jumpToSpotButton.action = #selector(scrollClickChanged(_:))

        let scrollClickRow = SnowLeopardPaneHelper.makeRow(
            label: scrollClickLabel,
            controls: [scrollClickColumn]
        )
        scrollContent.addArrangedSubview(scrollClickRow)

        // Separator
        let scrollInnerSep2 = SnowLeopardPaneHelper.makeSeparator(width: 560)
        scrollContent.addArrangedSubview(scrollInnerSep2)

        // Smooth scrolling checkbox
        smoothScrollingCheck.target = self
        smoothScrollingCheck.action = #selector(smoothScrollingChanged(_:))
        let smoothRow = SnowLeopardPaneHelper.makeRow(
            label: NSTextField(labelWithString: ""),
            controls: [smoothScrollingCheck]
        )
        scrollContent.addArrangedSubview(smoothRow)

        scrollBox.contentView = scrollContent
        mainStack.addArrangedSubview(scrollBox)
        scrollBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
        mainStack.setCustomSpacing(12, after: scrollBox)

        // ===== Section 3: Window Behavior =====
        let windowBox = SnowLeopardPaneHelper.makeSectionBox()
        let windowContent = NSStackView()
        windowContent.translatesAutoresizingMaskIntoConstraints = false
        windowContent.orientation = .vertical
        windowContent.alignment = .leading
        windowContent.spacing = 10

        // Double-click title bar checkbox
        doubleClickTitleBarCheck.target = self
        doubleClickTitleBarCheck.action = #selector(doubleClickTitleBarChanged(_:))
        let dblClickRow = SnowLeopardPaneHelper.makeRow(
            label: NSTextField(labelWithString: ""),
            controls: [doubleClickTitleBarCheck]
        )
        windowContent.addArrangedSubview(dblClickRow)

        // Separator
        let windowSep = SnowLeopardPaneHelper.makeSeparator(width: 560)
        windowContent.addArrangedSubview(windowSep)

        // Sidebar icon size
        sidebarSizePopup.target = self
        sidebarSizePopup.action = #selector(sidebarSizeChanged(_:))
        let sidebarRow = SnowLeopardPaneHelper.makeRow(
            label: sidebarSizeLabel,
            controls: [sidebarSizePopup]
        )
        windowContent.addArrangedSubview(sidebarRow)

        windowBox.contentView = windowContent
        mainStack.addArrangedSubview(windowBox)
        windowBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true
        mainStack.setCustomSpacing(12, after: windowBox)

        // ===== Section 4: Number of Recent Items =====
        let recentBox = SnowLeopardPaneHelper.makeSectionBox()
        let recentContent = NSStackView()
        recentContent.translatesAutoresizingMaskIntoConstraints = false
        recentContent.orientation = .vertical
        recentContent.alignment = .leading
        recentContent.spacing = 8

        let recentPopups: [(AquaPopUpButton, String)] = [
            (recentAppsPopup, "Applications"),
            (recentDocsPopup, "Documents"),
            (recentServersPopup, "Servers"),
        ]
        for (popup, suffix) in recentPopups {
            popup.items = recentItemValues.map { "\($0) \(suffix)" }
            popup.target = self
            popup.action = #selector(recentItemsChanged(_:))
        }

        let recentRow = SnowLeopardPaneHelper.makeRow(
            label: recentItemsLabel,
            controls: [recentAppsPopup, recentDocsPopup, recentServersPopup],
            spacing: 8
        )
        recentContent.addArrangedSubview(recentRow)

        recentBox.contentView = recentContent
        mainStack.addArrangedSubview(recentBox)
        recentBox.widthAnchor.constraint(equalTo: mainStack.widthAnchor, constant: -40).isActive = true

        view.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        // Appearance (Light / Dark / Auto)
        let style = defaults.string(forKey: "AppleInterfaceStyle")
        let autoSwitch = defaults.bool(forKey: "AppleInterfaceStyleSwitchesAutomatically") ?? false

        lightButton.isSelected = false
        darkButton.isSelected = false
        autoButton.isSelected = false

        if autoSwitch {
            autoButton.isSelected = true
        } else if style == "Dark" {
            darkButton.isSelected = true
        } else {
            lightButton.isSelected = true
        }

        // Accent color
        let accent = defaults.integer(forKey: "AppleAccentColor") ?? 4 // blue default
        for btn in accentColorButtons {
            btn.layer?.borderWidth = 0
        }
        // Map: Blue=4, Purple=5, Pink=6, Red=0, Orange=1, Yellow=2, Green=3, Graphite=-1
        let accentToIndex = [4: 0, 5: 1, 6: 2, 0: 3, 1: 4, 2: 5, 3: 6, -1: 7]
        if let idx = accentToIndex[accent], idx < accentColorButtons.count {
            accentColorButtons[idx].layer?.borderWidth = 2
            accentColorButtons[idx].layer?.borderColor = NSColor.white.cgColor
        }

        // Scroll bars
        let scrollMode = defaults.string(forKey: "AppleShowScrollBars") ?? "Automatic"
        switch scrollMode {
        case "Automatic": scrollBarsPopup.selectedIndex = 0
        case "WhenScrolling": scrollBarsPopup.selectedIndex = 1
        case "Always": scrollBarsPopup.selectedIndex = 2
        default: scrollBarsPopup.selectedIndex = 0
        }

        // Scroll click behavior
        let pagingBehavior = defaults.bool(forKey: "AppleScrollerPagingBehavior") ?? true
        jumpToSpotButton.isSelected = pagingBehavior ? false : true
        jumpToPageButton.isSelected = pagingBehavior ? true : false

        // Smooth scrolling
        let smoothScrolling = defaults.bool(forKey: "NSScrollAnimationEnabled") ?? true
        smoothScrollingCheck.isChecked = smoothScrolling

        // Double-click title bar to minimize
        let doubleClickMinimize = defaults.string(forKey: "AppleActionOnDoubleClick") ?? "Maximize"
        doubleClickTitleBarCheck.isChecked = (doubleClickMinimize == "Minimize")

        // Sidebar size
        let sidebarSize = defaults.integer(forKey: "NSTableViewDefaultSizeMode") ?? 2
        sidebarSizePopup.selectedIndex = max(0, sidebarSize - 1)

        // Recent items — read from com.apple.recentitems domain
        loadRecentItemsCount()
    }

    private func loadRecentItemsCount() {
        // These values are stored in a nested plist structure; use defaults command for reliability
        let categories: [(AquaPopUpButton, String)] = [
            (recentAppsPopup, "RecentApplications"),
            (recentDocsPopup, "RecentDocuments"),
            (recentServersPopup, "RecentServers"),
        ]
        for (popup, key) in categories {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = ["read", "com.apple.recentitems", key]
            process.standardOutput = pipe
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let match = output.range(of: "MaxAmount = (\\d+)", options: .regularExpression) {
                let numStr = output[match].components(separatedBy: " ").last ?? "10"
                if let idx = recentItemValues.firstIndex(of: numStr) {
                    popup.selectedIndex = idx
                    continue
                }
            }
            // Default to 10
            popup.selectedIndex = 2
        }
    }

    // MARK: - Actions

    @objc private func appearanceChanged(_ sender: AquaRadioButton) {
        if sender === lightButton {
            defaults.set(nil, forKey: "AppleInterfaceStyle")
            defaults.setBool(false, forKey: "AppleInterfaceStyleSwitchesAutomatically")
            darkButton.isSelected = false; autoButton.isSelected = false
        } else if sender === darkButton {
            defaults.setString("Dark", forKey: "AppleInterfaceStyle")
            defaults.setBool(false, forKey: "AppleInterfaceStyleSwitchesAutomatically")
            lightButton.isSelected = false; autoButton.isSelected = false
        } else if sender === autoButton {
            defaults.setBool(true, forKey: "AppleInterfaceStyleSwitchesAutomatically")
            lightButton.isSelected = false; darkButton.isSelected = false
        }
        DistributedNotificationCenter.default().post(
            name: .init("AppleInterfaceThemeChangedNotification"), object: nil
        )
    }

    @objc private func accentColorChanged(_ sender: NSButton) {
        let indexToAccent = [0: 4, 1: 5, 2: 6, 3: 0, 4: 1, 5: 2, 6: 3, 7: -1]
        guard let accent = indexToAccent[sender.tag] else { return }
        defaults.setInteger(accent, forKey: "AppleAccentColor")

        for btn in accentColorButtons { btn.layer?.borderWidth = 0 }
        sender.layer?.borderWidth = 2
        sender.layer?.borderColor = NSColor.white.cgColor

        DistributedNotificationCenter.default().post(
            name: .init("AppleColorPreferencesChangedNotification"), object: nil
        )
    }

    @objc private func scrollBarsChanged(_ sender: AquaPopUpButton) {
        let values = ["Automatic", "WhenScrolling", "Always"]
        defaults.setString(values[sender.selectedIndex], forKey: "AppleShowScrollBars")
    }

    @objc private func scrollClickChanged(_ sender: AquaRadioButton) {
        if sender === jumpToSpotButton {
            defaults.setBool(false, forKey: "AppleScrollerPagingBehavior")
            jumpToPageButton.isSelected = false
        } else {
            defaults.setBool(true, forKey: "AppleScrollerPagingBehavior")
            jumpToSpotButton.isSelected = false
        }
    }

    @objc private func smoothScrollingChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "NSScrollAnimationEnabled")
    }

    @objc private func doubleClickTitleBarChanged(_ sender: AquaCheckbox) {
        let value = sender.isChecked ? "Minimize" : "Maximize"
        defaults.setString(value, forKey: "AppleActionOnDoubleClick")
    }

    @objc private func sidebarSizeChanged(_ sender: AquaPopUpButton) {
        defaults.setInteger(sender.selectedIndex + 1, forKey: "NSTableViewDefaultSizeMode")
    }

    @objc private func recentItemsChanged(_ sender: AquaPopUpButton) {
        let value = recentItemValues[sender.selectedIndex]
        let key: String
        if sender === recentAppsPopup {
            key = "RecentApplications"
        } else if sender === recentDocsPopup {
            key = "RecentDocuments"
        } else {
            key = "RecentServers"
        }
        // Write via defaults command since it's a nested plist structure
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.apple.recentitems", key, "-dict", "MaxAmount", "-int", value]
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    // MARK: - Helpers

    private func styleAllLabels() {
        let labels = [appearanceLabel, highlightColorLabel, scrollBarsLabel, scrollClickLabel, sidebarSizeLabel, recentItemsLabel]
        for label in labels {
            label.font = SnowLeopardFonts.label(size: 11)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
            label.alignment = .right
        }
    }
}
