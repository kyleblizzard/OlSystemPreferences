import Cocoa

class MouseTrackpadPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "mousetrackpad" }
    var paneTitle: String { "Mouse & Trackpad" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Mouse & Trackpad") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 500) }
    var searchKeywords: [String] { ["mouse", "trackpad", "scroll", "tracking speed", "tap", "click", "gesture", "natural", "double-click", "dragging"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Mouse-Settings.extension" }

    // MARK: - Services

    private let defaults = DefaultsService.shared
    private let trackpadDomain = "com.apple.AppleMultitouchTrackpad"
    private let btTrackpadDomain = "com.apple.driver.AppleBluetoothMultitouch.trackpad"

    // MARK: - Tab view

    private let tabView = AquaTabView()

    // MARK: - Mouse tab controls

    private let mouseTrackingSlider = AquaSlider(minValue: 0, maxValue: 3, value: 1)
    private let mouseDoubleClickSlider = AquaSlider(minValue: 0, maxValue: 1.5, value: 0.5)
    private let mouseScrollSpeedSlider = AquaSlider(minValue: 0, maxValue: 3, value: 1)
    private let primaryButtonLeftRadio = AquaRadioButton(title: "Left", isSelected: true)
    private let primaryButtonRightRadio = AquaRadioButton(title: "Right", isSelected: false)

    // MARK: - Trackpad tab controls

    private let trackpadTrackingSlider = AquaSlider(minValue: 0, maxValue: 3, value: 1)
    private let clickingCheck = AquaCheckbox(title: "Clicking (tap to click)", isChecked: false)
    private let draggingCheck = AquaCheckbox(title: "Dragging (three-finger drag)", isChecked: false)
    private let secondaryClickCheck = AquaCheckbox(title: "Secondary Click (two-finger click or tap)", isChecked: false)
    private let naturalScrollCheck = AquaCheckbox(title: "Scroll direction: natural", isChecked: true)

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12

        // Pane header
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        header.widthAnchor.constraint(equalToConstant: 620).isActive = true
        outerStack.addArrangedSubview(header)

        // Separator below header
        outerStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 620))

        // Tab view
        tabView.translatesAutoresizingMaskIntoConstraints = false

        tabView.addTab(title: "Mouse", view: createMouseTab())
        tabView.addTab(title: "Trackpad", view: createTrackpadTab())
        tabView.selectTab(at: 0)

        outerStack.addArrangedSubview(tabView)

        view.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            outerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            outerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.widthAnchor.constraint(equalToConstant: 620),
            tabView.heightAnchor.constraint(equalToConstant: 380),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - Mouse Tab

    private func createMouseTab() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)

        // Tracking Speed
        let trackingBox = SnowLeopardPaneHelper.makeSectionBox(title: "Tracking Speed")
        let trackingContent = makeSliderRow(
            slider: mouseTrackingSlider,
            leftLabel: "Slow",
            rightLabel: "Fast",
            action: #selector(mouseTrackingChanged(_:))
        )
        trackingBox.contentView = trackingContent
        trackingBox.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(trackingBox)

        // Double-Click Speed
        let doubleClickBox = SnowLeopardPaneHelper.makeSectionBox(title: "Double-Click Speed")
        let doubleClickContent = makeSliderRow(
            slider: mouseDoubleClickSlider,
            leftLabel: "Slow",
            rightLabel: "Fast",
            action: #selector(mouseDoubleClickChanged(_:))
        )
        doubleClickBox.contentView = doubleClickContent
        doubleClickBox.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(doubleClickBox)

        // Scrolling Speed
        let scrollBox = SnowLeopardPaneHelper.makeSectionBox(title: "Scrolling Speed")
        let scrollContent = makeSliderRow(
            slider: mouseScrollSpeedSlider,
            leftLabel: "Slow",
            rightLabel: "Fast",
            action: #selector(mouseScrollSpeedChanged(_:))
        )
        scrollBox.contentView = scrollContent
        scrollBox.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(scrollBox)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Primary mouse button
        let primaryLabel = SnowLeopardPaneHelper.makeLabel("Primary mouse button:", size: 11, bold: true)

        primaryButtonLeftRadio.groupTag = 1
        primaryButtonLeftRadio.target = self
        primaryButtonLeftRadio.action = #selector(primaryButtonChanged(_:))

        primaryButtonRightRadio.groupTag = 1
        primaryButtonRightRadio.target = self
        primaryButtonRightRadio.action = #selector(primaryButtonChanged(_:))

        let radioRow = NSStackView(views: [primaryButtonLeftRadio, primaryButtonRightRadio])
        radioRow.spacing = 20

        let primaryRow = SnowLeopardPaneHelper.makeRow(
            label: primaryLabel,
            controls: [radioRow],
            spacing: 12
        )
        stack.addArrangedSubview(primaryRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Trackpad Tab

    private func createTrackpadTab() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 24, bottom: 16, right: 24)

        // Tracking Speed
        let trackingBox = SnowLeopardPaneHelper.makeSectionBox(title: "Tracking Speed")
        let trackingContent = makeSliderRow(
            slider: trackpadTrackingSlider,
            leftLabel: "Slow",
            rightLabel: "Fast",
            action: #selector(trackpadTrackingChanged(_:))
        )
        trackingBox.contentView = trackingContent
        trackingBox.widthAnchor.constraint(equalToConstant: 560).isActive = true
        stack.addArrangedSubview(trackingBox)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Checkboxes section
        let gesturesLabel = SnowLeopardPaneHelper.makeLabel("Point & Click", size: 11, bold: true)
        stack.addArrangedSubview(gesturesLabel)

        clickingCheck.target = self
        clickingCheck.action = #selector(trackpadOptionChanged(_:))
        stack.addArrangedSubview(clickingCheck)

        draggingCheck.target = self
        draggingCheck.action = #selector(trackpadOptionChanged(_:))
        stack.addArrangedSubview(draggingCheck)

        secondaryClickCheck.target = self
        secondaryClickCheck.action = #selector(trackpadOptionChanged(_:))
        stack.addArrangedSubview(secondaryClickCheck)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Scroll direction
        let scrollLabel = SnowLeopardPaneHelper.makeLabel("Scrolling", size: 11, bold: true)
        stack.addArrangedSubview(scrollLabel)

        naturalScrollCheck.target = self
        naturalScrollCheck.action = #selector(trackpadOptionChanged(_:))
        stack.addArrangedSubview(naturalScrollCheck)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Slider Row Helper

    private func makeSliderRow(slider: AquaSlider, leftLabel: String, rightLabel: String, action: Selector) -> NSView {
        let content = NSView()
        content.translatesAutoresizingMaskIntoConstraints = false

        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.numberOfTickMarks = 10
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = false
        slider.target = self
        slider.action = action

        let slow = SnowLeopardPaneHelper.makeLabel(leftLabel, size: 10)
        slow.translatesAutoresizingMaskIntoConstraints = false
        let fast = SnowLeopardPaneHelper.makeLabel(rightLabel, size: 10)
        fast.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(slow)
        content.addSubview(slider)
        content.addSubview(fast)

        NSLayoutConstraint.activate([
            content.heightAnchor.constraint(equalToConstant: 36),

            slow.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            slow.centerYAnchor.constraint(equalTo: content.centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: slow.trailingAnchor, constant: 8),
            slider.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            slider.widthAnchor.constraint(equalToConstant: 380),

            fast.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 8),
            fast.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            fast.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
        ])

        return content
    }

    // MARK: - Reload

    func reloadFromSystem() {
        // Mouse tracking speed
        if let speed = defaults.double(forKey: "com.apple.mouse.scaling") {
            mouseTrackingSlider.doubleValue = speed
        }

        // Mouse double-click threshold
        if let threshold = defaults.double(forKey: "com.apple.mouse.doubleClickThreshold") {
            mouseDoubleClickSlider.doubleValue = threshold
        }

        // Natural scroll (shared between mouse and trackpad)
        let naturalScroll = defaults.bool(forKey: "com.apple.swipescrolldirection") ?? true
        naturalScrollCheck.isChecked = naturalScroll

        // Primary mouse button (left = false, right = true for com.apple.mouse.swapLeftRightButton)
        // Default is left
        primaryButtonLeftRadio.isSelected = true
        primaryButtonRightRadio.isSelected = false

        // Trackpad tracking speed
        if let speed = defaults.double(forKey: "com.apple.trackpad.scaling") {
            trackpadTrackingSlider.doubleValue = speed
        }

        // Tap to click
        let tapClick = defaults.bool(forKey: "Clicking", domain: trackpadDomain) ?? false
        clickingCheck.isChecked = tapClick

        // Three-finger drag
        let threeDrag = defaults.bool(forKey: "TrackpadThreeFingerDrag", domain: trackpadDomain) ?? false
        draggingCheck.isChecked = threeDrag

        // Secondary click (two-finger)
        let secondaryClick = defaults.bool(forKey: "TrackpadRightClick", domain: trackpadDomain) ?? true
        secondaryClickCheck.isChecked = secondaryClick
    }

    // MARK: - Mouse Actions

    @objc private func mouseTrackingChanged(_ sender: AquaSlider) {
        defaults.setDouble(sender.doubleValue, forKey: "com.apple.mouse.scaling")
    }

    @objc private func mouseDoubleClickChanged(_ sender: AquaSlider) {
        defaults.setDouble(sender.doubleValue, forKey: "com.apple.mouse.doubleClickThreshold")
    }

    @objc private func mouseScrollSpeedChanged(_ sender: AquaSlider) {
        // Scroll speed is tied to the tracking speed scaling on modern macOS
        defaults.setDouble(sender.doubleValue, forKey: "com.apple.mouse.scaling")
    }

    @objc private func primaryButtonChanged(_ sender: AquaRadioButton) {
        if sender === primaryButtonLeftRadio {
            primaryButtonLeftRadio.isSelected = true
            primaryButtonRightRadio.isSelected = false
        } else {
            primaryButtonLeftRadio.isSelected = false
            primaryButtonRightRadio.isSelected = true
        }
    }

    // MARK: - Trackpad Actions

    @objc private func trackpadTrackingChanged(_ sender: AquaSlider) {
        defaults.setDouble(sender.doubleValue, forKey: "com.apple.trackpad.scaling")
    }

    @objc private func trackpadOptionChanged(_ sender: AquaCheckbox) {
        let on = sender.isChecked
        switch sender {
        case clickingCheck:
            defaults.setBool(on, forKey: "Clicking", domain: trackpadDomain)
            defaults.setBool(on, forKey: "Clicking", domain: btTrackpadDomain)
        case draggingCheck:
            defaults.setBool(on, forKey: "TrackpadThreeFingerDrag", domain: trackpadDomain)
            defaults.setBool(on, forKey: "TrackpadThreeFingerDrag", domain: btTrackpadDomain)
        case secondaryClickCheck:
            defaults.setBool(on, forKey: "TrackpadRightClick", domain: trackpadDomain)
            defaults.setBool(on, forKey: "TrackpadRightClick", domain: btTrackpadDomain)
        case naturalScrollCheck:
            defaults.setBool(on, forKey: "com.apple.swipescrolldirection")
        default:
            break
        }
    }
}
