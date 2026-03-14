import Cocoa

// MARK: - Analog Clock View

private class AnalogClockView: NSView {

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let size = min(bounds.width, bounds.height)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = size / 2 - 4

        // Clock face
        let facePath = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        NSColor.white.setFill()
        facePath.fill()
        NSColor(white: 0.2, alpha: 1.0).setStroke()
        facePath.lineWidth = 2
        facePath.stroke()

        // Tick marks
        for i in 0..<60 {
            let angle = CGFloat(i) * .pi / 30 - .pi / 2
            let isMajor = (i % 5 == 0)
            let innerRadius = isMajor ? radius * 0.82 : radius * 0.90
            let outerRadius = radius * 0.95
            let innerPoint = NSPoint(
                x: center.x + innerRadius * cos(angle),
                y: center.y - innerRadius * sin(angle)
            )
            let outerPoint = NSPoint(
                x: center.x + outerRadius * cos(angle),
                y: center.y - outerRadius * sin(angle)
            )
            let tick = NSBezierPath()
            tick.move(to: innerPoint)
            tick.line(to: outerPoint)
            tick.lineWidth = isMajor ? 2.0 : 0.5
            NSColor(white: 0.2, alpha: 1.0).setStroke()
            tick.stroke()
        }

        // Current time
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        let hour = CGFloat(comps.hour ?? 0)
        let minute = CGFloat(comps.minute ?? 0)
        let second = CGFloat(comps.second ?? 0)

        // Hour hand
        let hourAngle = (hour.truncatingRemainder(dividingBy: 12) + minute / 60) * .pi / 6 - .pi / 2
        drawHand(center: center, angle: hourAngle, length: radius * 0.5, width: 4.0, color: NSColor(white: 0.15, alpha: 1.0))

        // Minute hand
        let minuteAngle = minute * .pi / 30 - .pi / 2
        drawHand(center: center, angle: minuteAngle, length: radius * 0.7, width: 2.5, color: NSColor(white: 0.15, alpha: 1.0))

        // Second hand
        let secondAngle = second * .pi / 30 - .pi / 2
        drawHand(center: center, angle: secondAngle, length: radius * 0.75, width: 1.0, color: .systemRed)

        // Center dot
        let dotSize: CGFloat = 6
        let dotRect = NSRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2, width: dotSize, height: dotSize)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    private func drawHand(center: NSPoint, angle: CGFloat, length: CGFloat, width: CGFloat, color: NSColor) {
        let endPoint = NSPoint(
            x: center.x + length * cos(angle),
            y: center.y - length * sin(angle)
        )
        let hand = NSBezierPath()
        hand.move(to: center)
        hand.line(to: endPoint)
        hand.lineWidth = width
        hand.lineCapStyle = .round
        color.setStroke()
        hand.stroke()
    }
}

class DateTimePaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "datetime" }
    var paneTitle: String { "Date & Time" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "Date & Time") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 420) }
    var searchKeywords: [String] { ["date", "time", "timezone", "clock", "24-hour", "ntp", "seconds", "menu bar"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Date-Time-Settings.extension" }

    // MARK: - Services

    private let defaults = DefaultsService.shared

    // MARK: - Tabs

    private let tabView = NSTabView()

    // Date & Time tab
    private let analogClock = AnalogClockView()
    private let currentDateLabel = NSTextField(labelWithString: "")
    private let currentTimeLabel = NSTextField(labelWithString: "")
    private let autoTimeCheck = NSButton(checkboxWithTitle: "Set date and time automatically", target: nil, action: nil)
    private let ntpServerField = NSTextField()
    private var dateTimer: Timer?

    // Time Zone tab
    private let timezoneLabel = NSTextField(labelWithString: "")
    private let timezoneDetailLabel = NSTextField(labelWithString: "")

    // Clock tab
    private let showClockCheck = NSButton(checkboxWithTitle: "Show date and time in menu bar", target: nil, action: nil)
    private let use24HourCheck = NSButton(checkboxWithTitle: "Use a 24-hour clock", target: nil, action: nil)
    private let showSecondsCheck = NSButton(checkboxWithTitle: "Display the time with seconds", target: nil, action: nil)
    private let flashSeparatorsCheck = NSButton(checkboxWithTitle: "Flash the time separators", target: nil, action: nil)
    private let showAMPMCheck = NSButton(checkboxWithTitle: "Show AM/PM", target: nil, action: nil)
    private let showDayCheck = NSButton(checkboxWithTitle: "Show the day of the week", target: nil, action: nil)
    private let showDateCheck = NSButton(checkboxWithTitle: "Show date", target: nil, action: nil)

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Tab View ---
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder
        tabView.font = SnowLeopardFonts.label(size: 11)

        let dateTimeTab = NSTabViewItem(identifier: "datetime")
        dateTimeTab.label = "Date & Time"
        dateTimeTab.view = buildDateTimeTab()

        let timezoneTab = NSTabViewItem(identifier: "timezone")
        timezoneTab.label = "Time Zone"
        timezoneTab.view = buildTimeZoneTab()

        let clockTab = NSTabViewItem(identifier: "clock")
        clockTab.label = "Clock"
        clockTab.view = buildClockTab()

        tabView.addTabViewItem(dateTimeTab)
        tabView.addTabViewItem(timezoneTab)
        tabView.addTabViewItem(clockTab)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true

        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Date & Time Tab

    private func buildDateTimeTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // Analog clock
        analogClock.translatesAutoresizingMaskIntoConstraints = false
        analogClock.widthAnchor.constraint(equalToConstant: 120).isActive = true
        analogClock.heightAnchor.constraint(equalToConstant: 120).isActive = true

        // Digital time display
        currentDateLabel.font = SnowLeopardFonts.boldLabel(size: 13)
        currentDateLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        currentDateLabel.alignment = .center

        currentTimeLabel.font = SnowLeopardFonts.label(size: 28)
        currentTimeLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        currentTimeLabel.alignment = .center

        let timeColumn = NSStackView(views: [currentTimeLabel, currentDateLabel])
        timeColumn.orientation = .vertical
        timeColumn.alignment = .centerX
        timeColumn.spacing = 4

        let clockRow = NSStackView(views: [analogClock, timeColumn])
        clockRow.orientation = .horizontal
        clockRow.alignment = .centerY
        clockRow.spacing = 20

        let clockWrapper = NSStackView(views: [clockRow])
        clockWrapper.alignment = .centerX
        stack.addArrangedSubview(clockWrapper)
        clockWrapper.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 560))

        // Auto time setting
        autoTimeCheck.target = self
        autoTimeCheck.action = #selector(autoTimeChanged(_:))
        SnowLeopardPaneHelper.styleControl(autoTimeCheck)
        let autoRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [autoTimeCheck]
        )
        stack.addArrangedSubview(autoRow)

        // NTP Server
        ntpServerField.translatesAutoresizingMaskIntoConstraints = false
        ntpServerField.font = SnowLeopardFonts.label(size: 11)
        ntpServerField.placeholderString = "time.apple.com"
        ntpServerField.widthAnchor.constraint(equalToConstant: 250).isActive = true
        ntpServerField.isEditable = false
        ntpServerField.stringValue = "time.apple.com"

        let ntpRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("NTP Server:"),
            controls: [ntpServerField]
        )
        stack.addArrangedSubview(ntpRow)

        // Info
        let infoLabel = SnowLeopardPaneHelper.makeLabel(
            "Changing date and time requires administrator privileges.\nUse Open in System Settings to modify.",
            size: 10
        )
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(infoLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Time Zone Tab

    private func buildTimeZoneTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // Time zone info box
        let tzBox = SnowLeopardPaneHelper.makeSectionBox(title: "Current Time Zone")
        let tzStack = NSStackView()
        tzStack.translatesAutoresizingMaskIntoConstraints = false
        tzStack.orientation = .vertical
        tzStack.alignment = .leading
        tzStack.spacing = 10
        tzStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        timezoneLabel.font = SnowLeopardFonts.boldLabel(size: 13)
        timezoneLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        tzStack.addArrangedSubview(timezoneLabel)

        timezoneDetailLabel.font = SnowLeopardFonts.label(size: 11)
        timezoneDetailLabel.textColor = .secondaryLabelColor
        timezoneDetailLabel.maximumNumberOfLines = 3
        tzStack.addArrangedSubview(timezoneDetailLabel)

        tzBox.contentView = tzStack
        stack.addArrangedSubview(tzBox)
        tzBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        // Closest city info
        let cityLabel = SnowLeopardPaneHelper.makeLabel(
            "To change the time zone, use Open in System Settings.",
            size: 10
        )
        cityLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(cityLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Clock Tab

    private func buildClockTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        let clockBox = SnowLeopardPaneHelper.makeSectionBox(title: "Menu Bar Clock")
        let clockStack = NSStackView()
        clockStack.translatesAutoresizingMaskIntoConstraints = false
        clockStack.orientation = .vertical
        clockStack.alignment = .leading
        clockStack.spacing = 6
        clockStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let allClockChecks: [NSButton] = [
            showClockCheck, use24HourCheck, showSecondsCheck,
            flashSeparatorsCheck, showAMPMCheck, showDayCheck, showDateCheck,
        ]
        for check in allClockChecks {
            check.target = self
            check.action = #selector(clockOptionChanged(_:))
            SnowLeopardPaneHelper.styleControl(check)

            let row = SnowLeopardPaneHelper.makeRow(
                label: SnowLeopardPaneHelper.makeLabel(""),
                controls: [check]
            )
            clockStack.addArrangedSubview(row)
        }

        clockBox.contentView = clockStack
        stack.addArrangedSubview(clockBox)
        clockBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        // Info
        let infoLabel = SnowLeopardPaneHelper.makeLabel(
            "Some clock settings may require logging out and back in to take effect.",
            size: 10
        )
        infoLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(infoLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
        startDateTimer()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        dateTimer?.invalidate()
        dateTimer = nil
    }

    func paneWillAppear() {
        startDateTimer()
        reloadFromSystem()
    }

    func paneWillDisappear() {
        dateTimer?.invalidate()
        dateTimer = nil
    }

    // MARK: - Timer

    private func startDateTimer() {
        dateTimer?.invalidate()
        updateDateTimeDisplay()
        dateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDateTimeDisplay()
        }
    }

    private func updateDateTimeDisplay() {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .full
        dateFmt.timeStyle = .none
        currentDateLabel.stringValue = dateFmt.string(from: Date())

        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .medium
        currentTimeLabel.stringValue = timeFmt.string(from: Date())

        analogClock.needsDisplay = true
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        // Auto time
        autoTimeCheck.state = .on // macOS typically has this on by default

        // Time zone
        let tz = TimeZone.current
        timezoneLabel.stringValue = tz.localizedName(for: .standard, locale: .current) ?? tz.identifier
        let offset = tz.secondsFromGMT()
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        let gmtString = String(format: "GMT%+d:%02d", hours, minutes)
        timezoneDetailLabel.stringValue = "Identifier: \(tz.identifier)\nOffset: \(gmtString)\nDaylight Saving Time: \(tz.isDaylightSavingTime() ? "Yes" : "No")"

        // Clock settings from com.apple.menuextra.clock domain
        let clockDomain = "com.apple.menuextra.clock"

        let show24Hour = defaults.bool(forKey: "AppleICUForce24HourTime") ?? false
        use24HourCheck.state = show24Hour ? .on : .off

        let showSecs = defaults.bool(forKey: "ShowSeconds", domain: clockDomain) ?? false
        showSecondsCheck.state = showSecs ? .on : .off

        let flashSep = defaults.bool(forKey: "FlashDateSeparators", domain: clockDomain) ?? false
        flashSeparatorsCheck.state = flashSep ? .on : .off

        showClockCheck.state = .on // Menu bar clock is typically always on
        showAMPMCheck.state = show24Hour ? .off : .on

        let showDay = defaults.bool(forKey: "ShowDayOfWeek", domain: clockDomain) ?? true
        showDayCheck.state = showDay ? .on : .off

        let showDt = defaults.bool(forKey: "ShowDate", domain: clockDomain) ?? true
        showDateCheck.state = showDt ? .on : .off

        updateDateTimeDisplay()
    }

    // MARK: - Actions

    @objc private func autoTimeChanged(_ sender: NSButton) {
        // Changing auto time requires admin — just show current state
    }

    @objc private func clockOptionChanged(_ sender: NSButton) {
        let on = sender.state == .on
        let clockDomain = "com.apple.menuextra.clock"

        switch sender {
        case use24HourCheck:
            defaults.setBool(on, forKey: "AppleICUForce24HourTime")
            showAMPMCheck.state = on ? .off : .on
        case showSecondsCheck:
            defaults.setBool(on, forKey: "ShowSeconds", domain: clockDomain)
        case flashSeparatorsCheck:
            defaults.setBool(on, forKey: "FlashDateSeparators", domain: clockDomain)
        case showAMPMCheck:
            // AM/PM is inverse of 24-hour
            defaults.setBool(!on, forKey: "AppleICUForce24HourTime")
            use24HourCheck.state = on ? .off : .on
        case showDayCheck:
            defaults.setBool(on, forKey: "ShowDayOfWeek", domain: clockDomain)
        case showDateCheck:
            defaults.setBool(on, forKey: "ShowDate", domain: clockDomain)
        default:
            break
        }
    }
}
