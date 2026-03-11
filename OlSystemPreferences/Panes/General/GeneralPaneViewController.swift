import Cocoa

class GeneralPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "general" }
    var paneTitle: String { "General" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 500) }
    var searchKeywords: [String] { ["appearance", "dark mode", "light mode", "accent", "highlight", "scroll", "sidebar"] }
    var viewController: NSViewController { self }

    private let defaults = DefaultsService.shared

    // MARK: - UI Elements

    private let appearanceLabel = NSTextField(labelWithString: "Appearance:")
    private let lightButton = NSButton(radioButtonWithTitle: "Light", target: nil, action: nil)
    private let darkButton = NSButton(radioButtonWithTitle: "Dark", target: nil, action: nil)
    private let autoButton = NSButton(radioButtonWithTitle: "Auto", target: nil, action: nil)

    private let accentColorLabel = NSTextField(labelWithString: "Accent color:")
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

    private let scrollBarsLabel = NSTextField(labelWithString: "Show scroll bars:")
    private let scrollBarsPopup = NSPopUpButton()

    private let scrollClickLabel = NSTextField(labelWithString: "Click in the scroll bar to:")
    private let jumpToSpotButton = NSButton(radioButtonWithTitle: "Jump to the spot that's clicked", target: nil, action: nil)
    private let jumpToPageButton = NSButton(radioButtonWithTitle: "Jump to the next page", target: nil, action: nil)

    private let sidebarSizeLabel = NSTextField(labelWithString: "Sidebar icon size:")
    private let sidebarSizePopup = NSPopUpButton()

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 16
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)

        // Appearance row
        let appearanceRow = makeRow(label: appearanceLabel, controls: [lightButton, darkButton, autoButton])
        lightButton.target = self; lightButton.action = #selector(appearanceChanged(_:))
        darkButton.target = self; darkButton.action = #selector(appearanceChanged(_:))
        autoButton.target = self; autoButton.action = #selector(appearanceChanged(_:))

        // Accent color row
        let accentRow = NSStackView()
        accentRow.orientation = .horizontal
        accentRow.spacing = 8
        accentRow.addArrangedSubview(accentColorLabel)
        for (index, btn) in accentColorButtons.enumerated() {
            btn.tag = index
            btn.target = self
            btn.action = #selector(accentColorChanged(_:))
            accentRow.addArrangedSubview(btn)
        }

        // Scroll bars
        scrollBarsPopup.addItems(withTitles: ["Automatically based on mouse or trackpad", "When scrolling", "Always"])
        scrollBarsPopup.target = self
        scrollBarsPopup.action = #selector(scrollBarsChanged(_:))
        let scrollRow = makeRow(label: scrollBarsLabel, controls: [scrollBarsPopup])

        // Scroll click
        jumpToSpotButton.target = self; jumpToSpotButton.action = #selector(scrollClickChanged(_:))
        jumpToPageButton.target = self; jumpToPageButton.action = #selector(scrollClickChanged(_:))
        let scrollClickRow = makeRow(label: scrollClickLabel, controls: [jumpToSpotButton, jumpToPageButton])

        // Sidebar size
        sidebarSizePopup.addItems(withTitles: ["Small", "Medium", "Large"])
        sidebarSizePopup.target = self
        sidebarSizePopup.action = #selector(sidebarSizeChanged(_:))
        let sidebarRow = makeRow(label: sidebarSizeLabel, controls: [sidebarSizePopup])

        stackView.addArrangedSubview(appearanceRow)
        stackView.addArrangedSubview(accentRow)
        stackView.addArrangedSubview(makeSeparator())
        stackView.addArrangedSubview(scrollRow)
        stackView.addArrangedSubview(scrollClickRow)
        stackView.addArrangedSubview(makeSeparator())
        stackView.addArrangedSubview(sidebarRow)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        // Appearance
        let style = defaults.string(forKey: "AppleInterfaceStyle")
        if style == "Dark" {
            darkButton.state = .on
        } else {
            lightButton.state = .on
        }
        // Auto detection: if AppleInterfaceStyleSwitchesAutomatically is true
        if defaults.bool(forKey: "AppleInterfaceStyleSwitchesAutomatically") == true {
            autoButton.state = .on
            lightButton.state = .off
            darkButton.state = .off
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
        case "Automatic": scrollBarsPopup.selectItem(at: 0)
        case "WhenScrolling": scrollBarsPopup.selectItem(at: 1)
        case "Always": scrollBarsPopup.selectItem(at: 2)
        default: scrollBarsPopup.selectItem(at: 0)
        }

        // Scroll click behavior
        let pagingBehavior = defaults.bool(forKey: "AppleScrollerPagingBehavior") ?? true
        jumpToSpotButton.state = pagingBehavior ? .off : .on
        jumpToPageButton.state = pagingBehavior ? .on : .off

        // Sidebar size
        let sidebarSize = defaults.integer(forKey: "NSTableViewDefaultSizeMode") ?? 2
        sidebarSizePopup.selectItem(at: max(0, sidebarSize - 1))
    }

    // MARK: - Actions

    @objc private func appearanceChanged(_ sender: NSButton) {
        if sender === lightButton {
            defaults.set(nil, forKey: "AppleInterfaceStyle")
            defaults.setBool(false, forKey: "AppleInterfaceStyleSwitchesAutomatically")
            darkButton.state = .off; autoButton.state = .off
        } else if sender === darkButton {
            defaults.setString("Dark", forKey: "AppleInterfaceStyle")
            defaults.setBool(false, forKey: "AppleInterfaceStyleSwitchesAutomatically")
            lightButton.state = .off; autoButton.state = .off
        } else if sender === autoButton {
            defaults.setBool(true, forKey: "AppleInterfaceStyleSwitchesAutomatically")
            lightButton.state = .off; darkButton.state = .off
        }
        DistributedNotificationCenter.default().post(name: .init("AppleInterfaceThemeChangedNotification"), object: nil)
    }

    @objc private func accentColorChanged(_ sender: NSButton) {
        let indexToAccent = [0: 4, 1: 5, 2: 6, 3: 0, 4: 1, 5: 2, 6: 3, 7: -1]
        guard let accent = indexToAccent[sender.tag] else { return }
        defaults.setInteger(accent, forKey: "AppleAccentColor")

        for btn in accentColorButtons { btn.layer?.borderWidth = 0 }
        sender.layer?.borderWidth = 2
        sender.layer?.borderColor = NSColor.white.cgColor

        DistributedNotificationCenter.default().post(name: .init("AppleColorPreferencesChangedNotification"), object: nil)
    }

    @objc private func scrollBarsChanged(_ sender: NSPopUpButton) {
        let values = ["Automatic", "WhenScrolling", "Always"]
        defaults.setString(values[sender.indexOfSelectedItem], forKey: "AppleShowScrollBars")
    }

    @objc private func scrollClickChanged(_ sender: NSButton) {
        if sender === jumpToSpotButton {
            defaults.setBool(false, forKey: "AppleScrollerPagingBehavior")
            jumpToPageButton.state = .off
        } else {
            defaults.setBool(true, forKey: "AppleScrollerPagingBehavior")
            jumpToSpotButton.state = .off
        }
    }

    @objc private func sidebarSizeChanged(_ sender: NSPopUpButton) {
        defaults.setInteger(sender.indexOfSelectedItem + 1, forKey: "NSTableViewDefaultSizeMode")
    }

    // MARK: - Helpers

    private func makeRow(label: NSTextField, controls: [NSView]) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .firstBaseline
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        row.addArrangedSubview(label)
        for control in controls {
            row.addArrangedSubview(control)
        }
        return row
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.widthAnchor.constraint(equalToConstant: 580).isActive = true
        return sep
    }
}
