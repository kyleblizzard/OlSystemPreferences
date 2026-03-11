import Cocoa

class MouseTrackpadPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "mousetrackpad" }
    var paneTitle: String { "Mouse & Trackpad" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mouse & Trackpad") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 480) }
    var searchKeywords: [String] { ["mouse", "trackpad", "scroll", "tracking speed", "tap", "click", "gesture", "natural"] }
    var viewController: NSViewController { self }

    private let defaults = DefaultsService.shared
    private let trackpadDomain = "com.apple.AppleMultitouchTrackpad"

    private let tabView = NSTabView()

    // MARK: - Mouse controls
    private let mouseSpeedSlider = NSSlider(value: 1, minValue: 0, maxValue: 3, target: nil, action: nil)
    private let mouseScrollCheck = NSButton(checkboxWithTitle: "Natural scrolling", target: nil, action: nil)

    // MARK: - Trackpad controls
    private let trackpadSpeedSlider = NSSlider(value: 1, minValue: 0, maxValue: 3, target: nil, action: nil)
    private let tapToClickCheck = NSButton(checkboxWithTitle: "Tap to click", target: nil, action: nil)
    private let naturalScrollCheck = NSButton(checkboxWithTitle: "Natural scrolling", target: nil, action: nil)
    private let forceClickCheck = NSButton(checkboxWithTitle: "Force Click and haptic feedback", target: nil, action: nil)
    private let secondaryClickCheck = NSButton(checkboxWithTitle: "Secondary click (two-finger click)", target: nil, action: nil)

    override func loadView() {
        view = NSView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        // Mouse tab
        let mouseTab = NSTabViewItem(identifier: "mouse")
        mouseTab.label = "Mouse"
        mouseTab.view = createMouseTab()

        // Trackpad tab
        let trackpadTab = NSTabViewItem(identifier: "trackpad")
        trackpadTab.label = "Trackpad"
        trackpadTab.view = createTrackpadTab()

        tabView.addTabViewItem(mouseTab)
        tabView.addTabViewItem(trackpadTab)

        view.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])
    }

    private func createMouseTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let speedLabel = NSTextField(labelWithString: "Tracking speed:")
        mouseSpeedSlider.target = self; mouseSpeedSlider.action = #selector(mouseSpeedChanged(_:))
        mouseSpeedSlider.isContinuous = false
        mouseSpeedSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let slowLabel = NSTextField(labelWithString: "Slow")
        slowLabel.font = NSFont.systemFont(ofSize: 10)
        let fastLabel = NSTextField(labelWithString: "Fast")
        fastLabel.font = NSFont.systemFont(ofSize: 10)
        let speedRow = NSStackView(views: [speedLabel, slowLabel, mouseSpeedSlider, fastLabel])
        speedRow.spacing = 8

        mouseScrollCheck.target = self; mouseScrollCheck.action = #selector(mouseScrollChanged(_:))

        stack.addArrangedSubview(speedRow)
        stack.addArrangedSubview(mouseScrollCheck)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    private func createTrackpadTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let speedLabel = NSTextField(labelWithString: "Tracking speed:")
        trackpadSpeedSlider.target = self; trackpadSpeedSlider.action = #selector(trackpadSpeedChanged(_:))
        trackpadSpeedSlider.isContinuous = false
        trackpadSpeedSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let slowLabel = NSTextField(labelWithString: "Slow")
        slowLabel.font = NSFont.systemFont(ofSize: 10)
        let fastLabel = NSTextField(labelWithString: "Fast")
        fastLabel.font = NSFont.systemFont(ofSize: 10)
        let speedRow = NSStackView(views: [speedLabel, slowLabel, trackpadSpeedSlider, fastLabel])
        speedRow.spacing = 8

        let sep = NSBox()
        sep.boxType = .separator
        sep.widthAnchor.constraint(equalToConstant: 540).isActive = true

        let gesturesLabel = NSTextField(labelWithString: "Point & Click:")
        gesturesLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        tapToClickCheck.target = self; tapToClickCheck.action = #selector(trackpadOptionChanged(_:))
        naturalScrollCheck.target = self; naturalScrollCheck.action = #selector(trackpadOptionChanged(_:))
        forceClickCheck.target = self; forceClickCheck.action = #selector(trackpadOptionChanged(_:))
        secondaryClickCheck.target = self; secondaryClickCheck.action = #selector(trackpadOptionChanged(_:))

        stack.addArrangedSubview(speedRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(gesturesLabel)
        stack.addArrangedSubview(tapToClickCheck)
        stack.addArrangedSubview(secondaryClickCheck)
        stack.addArrangedSubview(forceClickCheck)
        stack.addArrangedSubview(naturalScrollCheck)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    func reloadFromSystem() {
        // Mouse
        if let speed = defaults.double(forKey: "com.apple.mouse.scaling") {
            mouseSpeedSlider.doubleValue = speed
        }
        let naturalScroll = defaults.bool(forKey: "com.apple.swipescrolldirection") ?? true
        mouseScrollCheck.state = naturalScroll ? .on : .off
        naturalScrollCheck.state = naturalScroll ? .on : .off

        // Trackpad
        if let speed = defaults.double(forKey: "com.apple.trackpad.scaling") {
            trackpadSpeedSlider.doubleValue = speed
        }
        let tapClick = defaults.bool(forKey: "Clicking", domain: trackpadDomain) ?? false
        tapToClickCheck.state = tapClick ? .on : .off

        let secondaryClick = defaults.bool(forKey: "TrackpadRightClick", domain: trackpadDomain) ?? true
        secondaryClickCheck.state = secondaryClick ? .on : .off

        let forceClick = defaults.bool(forKey: "com.apple.trackpad.forceClick") ?? true
        forceClickCheck.state = forceClick ? .on : .off
    }

    // MARK: - Actions

    @objc private func mouseSpeedChanged(_ sender: NSSlider) {
        defaults.setDouble(sender.doubleValue, forKey: "com.apple.mouse.scaling")
    }

    @objc private func mouseScrollChanged(_ sender: NSButton) {
        defaults.setBool(sender.state == .on, forKey: "com.apple.swipescrolldirection")
    }

    @objc private func trackpadSpeedChanged(_ sender: NSSlider) {
        defaults.setDouble(sender.doubleValue, forKey: "com.apple.trackpad.scaling")
    }

    @objc private func trackpadOptionChanged(_ sender: NSButton) {
        let on = sender.state == .on
        switch sender {
        case tapToClickCheck:
            defaults.setBool(on, forKey: "Clicking", domain: trackpadDomain)
            defaults.setBool(on, forKey: "Clicking", domain: "com.apple.driver.AppleBluetoothMultitouch.trackpad")
        case secondaryClickCheck:
            defaults.setBool(on, forKey: "TrackpadRightClick", domain: trackpadDomain)
            defaults.setBool(on, forKey: "TrackpadRightClick", domain: "com.apple.driver.AppleBluetoothMultitouch.trackpad")
        case forceClickCheck:
            defaults.setBool(on, forKey: "com.apple.trackpad.forceClick")
        case naturalScrollCheck:
            defaults.setBool(on, forKey: "com.apple.swipescrolldirection")
            mouseScrollCheck.state = sender.state
        default: break
        }
    }
}
