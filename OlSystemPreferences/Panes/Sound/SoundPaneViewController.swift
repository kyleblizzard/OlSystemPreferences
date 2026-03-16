import Cocoa
import CoreAudio

class SoundPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "sound" }
    var paneTitle: String { "Sound" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Sound") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 560) }
    var searchKeywords: [String] { ["sound", "volume", "audio", "speaker", "microphone", "input", "output", "mute", "alert"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Sound-Settings.extension" }

    // MARK: - Services

    private let audio = AudioService.shared
    private let defaults = DefaultsService.shared

    // MARK: - Tabs

    private let tabView = AquaTabView()

    // Sound Effects tab controls
    private let alertSoundTable = NSTableView()
    private let alertVolumeSlider = AquaSlider(minValue: 0, maxValue: 1, value: 0.5)
    private let playSoundsCheck = AquaCheckbox(title: "Play user interface sound effects", isChecked: true)
    private let volumeFeedbackCheck = AquaCheckbox(title: "Play feedback when volume is changed", isChecked: true)
    private let effectsOutputVolumeSlider = AquaSlider(minValue: 0, maxValue: 1, value: 0.5)
    private let effectsMuteCheck = AquaCheckbox(title: "Mute", isChecked: false)

    // Output tab controls
    private let outputDeviceTable = NSTableView()

    // Input tab controls
    private let inputDeviceTable = NSTableView()
    private let inputLevelIndicator = NSLevelIndicator()

    // Data
    private var outputDevices: [AudioService.AudioDevice] = []
    private var inputDevices: [AudioService.AudioDevice] = []
    private var inputLevelTimer: Timer?

    private let alertSounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Outer stack with header + tab view
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

        // Sound Effects tab
        tabView.addTab(title: "Sound Effects", view: buildSoundEffectsTab())

        // Output tab
        tabView.addTab(title: "Output", view: buildOutputTab())

        // Input tab
        tabView.addTab(title: "Input", view: buildInputTab())

        tabView.selectTab(at: 0)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 420).isActive = true

        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Sound Effects Tab

    private func buildSoundEffectsTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // Alert sound list
        let alertLabel = SnowLeopardPaneHelper.makeLabel("Choose an alert sound:", size: 11, bold: true)
        stack.addArrangedSubview(alertLabel)

        let alertScroll = NSScrollView()
        alertScroll.translatesAutoresizingMaskIntoConstraints = false
        alertScroll.hasVerticalScroller = true
        alertScroll.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 480
        alertSoundTable.addTableColumn(nameCol)
        alertSoundTable.headerView = nil
        alertSoundTable.delegate = self
        alertSoundTable.dataSource = self
        alertSoundTable.tag = 3
        alertSoundTable.rowHeight = 20
        alertSoundTable.usesAlternatingRowBackgroundColors = true

        alertScroll.documentView = alertSoundTable
        alertScroll.widthAnchor.constraint(equalToConstant: 560).isActive = true
        alertScroll.heightAnchor.constraint(equalToConstant: 140).isActive = true
        stack.addArrangedSubview(alertScroll)

        // Alert volume slider
        alertVolumeSlider.target = self
        alertVolumeSlider.action = #selector(alertVolumeChanged(_:))
        alertVolumeSlider.isContinuous = true
        alertVolumeSlider.showsFillColor = true
        alertVolumeSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let alertVolRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Alert volume:"),
            controls: [alertVolumeSlider]
        )
        stack.addArrangedSubview(alertVolRow)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Checkboxes
        playSoundsCheck.target = self
        playSoundsCheck.action = #selector(soundEffectsChanged(_:))

        volumeFeedbackCheck.target = self
        volumeFeedbackCheck.action = #selector(volumeFeedbackChanged(_:))

        let checkRow1 = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [playSoundsCheck]
        )
        let checkRow2 = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [volumeFeedbackCheck]
        )
        stack.addArrangedSubview(checkRow1)
        stack.addArrangedSubview(checkRow2)

        // Separator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // Output volume + mute
        effectsOutputVolumeSlider.target = self
        effectsOutputVolumeSlider.action = #selector(outputVolumeChanged(_:))
        effectsOutputVolumeSlider.isContinuous = true
        effectsOutputVolumeSlider.showsFillColor = true
        effectsOutputVolumeSlider.widthAnchor.constraint(equalToConstant: 260).isActive = true

        effectsMuteCheck.target = self
        effectsMuteCheck.action = #selector(muteToggled(_:))

        let volRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Output volume:"),
            controls: [effectsOutputVolumeSlider, effectsMuteCheck]
        )
        stack.addArrangedSubview(volRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    /// Builds the output volume + mute row used on all three tabs (Snow Leopard style)
    private func buildOutputVolumeRow() -> NSView {
        let volSlider = AquaSlider(minValue: 0, maxValue: 1, value: 0.5)
        volSlider.target = self
        volSlider.action = #selector(outputVolumeChanged(_:))
        volSlider.isContinuous = true
        volSlider.showsFillColor = true
        volSlider.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let muteCheck = AquaCheckbox(title: "Mute", isChecked: false)
        muteCheck.target = self
        muteCheck.action = #selector(muteToggled(_:))

        // Read current values
        if let vol = audio.getOutputVolume() {
            volSlider.doubleValue = Double(vol)
        }
        muteCheck.isChecked = audio.isMuted() ?? false

        return SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Output volume:"),
            controls: [volSlider, muteCheck]
        )
    }

    // MARK: - Output Tab

    private func buildOutputTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let label = SnowLeopardPaneHelper.makeLabel("Select a device for sound output:", size: 11, bold: true)
        stack.addArrangedSubview(label)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 360
        outputDeviceTable.addTableColumn(nameCol)

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        typeCol.width = 180
        outputDeviceTable.addTableColumn(typeCol)

        outputDeviceTable.delegate = self
        outputDeviceTable.dataSource = self
        outputDeviceTable.tag = 1
        outputDeviceTable.rowHeight = 22
        outputDeviceTable.usesAlternatingRowBackgroundColors = true
        outputDeviceTable.headerView?.tableView?.font = SnowLeopardFonts.label(size: 11)

        scrollView.documentView = outputDeviceTable
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        stack.addArrangedSubview(scrollView)

        // Output volume + mute (Snow Leopard showed this on all tabs)
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))
        stack.addArrangedSubview(buildOutputVolumeRow())

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Input Tab

    private func buildInputTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let label = SnowLeopardPaneHelper.makeLabel("Select a device for sound input:", size: 11, bold: true)
        stack.addArrangedSubview(label)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 360
        inputDeviceTable.addTableColumn(nameCol)

        let typeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeCol.title = "Type"
        typeCol.width = 180
        inputDeviceTable.addTableColumn(typeCol)

        inputDeviceTable.delegate = self
        inputDeviceTable.dataSource = self
        inputDeviceTable.tag = 2
        inputDeviceTable.rowHeight = 22
        inputDeviceTable.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = inputDeviceTable
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 220).isActive = true
        stack.addArrangedSubview(scrollView)

        // Input level indicator
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        inputLevelIndicator.minValue = 0
        inputLevelIndicator.maxValue = 1.0
        inputLevelIndicator.warningValue = 0.8
        inputLevelIndicator.criticalValue = 0.95
        inputLevelIndicator.levelIndicatorStyle = .continuousCapacity
        inputLevelIndicator.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let levelRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Input level:"),
            controls: [inputLevelIndicator]
        )
        stack.addArrangedSubview(levelRow)

        // Output volume + mute (Snow Leopard showed this on all tabs)
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))
        stack.addArrangedSubview(buildOutputVolumeRow())

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
        startInputLevelTimer()
    }

    func paneWillAppear() {
        reloadFromSystem()
        startInputLevelTimer()
    }

    func paneWillDisappear() {
        inputLevelTimer?.invalidate()
        inputLevelTimer = nil
    }

    private func startInputLevelTimer() {
        inputLevelTimer?.invalidate()
        inputLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Read input level from the default input device via HAL
            guard let inputID = self.audio.getDefaultInputDeviceID() else { return }
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var level: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(inputID, &address, 0, nil, &size, &level)
            if status == noErr {
                self.inputLevelIndicator.doubleValue = Double(level)
            }
        }
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        // Volume
        if let vol = audio.getOutputVolume() {
            effectsOutputVolumeSlider.doubleValue = Double(vol)
        }
        effectsMuteCheck.isChecked = audio.isMuted() ?? false

        // Devices
        outputDevices = audio.getOutputDevices()
        inputDevices = audio.getInputDevices()
        outputDeviceTable.reloadData()
        inputDeviceTable.reloadData()

        // Select current output device
        if let currentOutput = audio.getDefaultOutputDeviceID() {
            if let idx = outputDevices.firstIndex(where: { $0.id == currentOutput }) {
                outputDeviceTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            }
        }
        // Select current input device
        if let currentInput = audio.getDefaultInputDeviceID() {
            if let idx = inputDevices.firstIndex(where: { $0.id == currentInput }) {
                inputDeviceTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            }
        }

        // Sound effects prefs
        let uiSounds = defaults.bool(forKey: "com.apple.sound.uiaudio.enabled") ?? true
        playSoundsCheck.isChecked = uiSounds
        let feedback = defaults.bool(forKey: "com.apple.sound.beep.feedback") ?? true
        volumeFeedbackCheck.isChecked = feedback

        let alertVol = defaults.float(forKey: "com.apple.sound.beep.volume") ?? 0.5
        alertVolumeSlider.doubleValue = Double(alertVol)
    }

    // MARK: - Actions

    @objc private func outputVolumeChanged(_ sender: AquaSlider) {
        audio.setOutputVolume(Float(sender.doubleValue))
    }

    @objc private func muteToggled(_ sender: AquaCheckbox) {
        audio.setMuted(sender.isChecked)
    }

    @objc private func alertVolumeChanged(_ sender: AquaSlider) {
        defaults.setFloat(Float(sender.doubleValue), forKey: "com.apple.sound.beep.volume")
    }

    @objc private func soundEffectsChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "com.apple.sound.uiaudio.enabled")
    }

    @objc private func volumeFeedbackChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "com.apple.sound.beep.feedback")
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension SoundPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.tag {
        case 1: return outputDevices.count
        case 2: return inputDevices.count
        case 3: return alertSounds.count
        default: return 0
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let colID = tableColumn?.identifier.rawValue ?? ""

        switch tableView.tag {
        case 1:
            // Output devices
            let device = outputDevices[row]
            if colID == "name" {
                let cell = NSTextField(labelWithString: device.name)
                cell.font = SnowLeopardFonts.label(size: 12)
                return cell
            } else {
                let typeStr = device.hasOutput && device.hasInput ? "Built-in" : "Built-in"
                let cell = NSTextField(labelWithString: typeStr)
                cell.font = SnowLeopardFonts.label(size: 12)
                cell.textColor = .secondaryLabelColor
                return cell
            }

        case 2:
            // Input devices
            let device = inputDevices[row]
            if colID == "name" {
                let cell = NSTextField(labelWithString: device.name)
                cell.font = SnowLeopardFonts.label(size: 12)
                return cell
            } else {
                let cell = NSTextField(labelWithString: "Built-in")
                cell.font = SnowLeopardFonts.label(size: 12)
                cell.textColor = .secondaryLabelColor
                return cell
            }

        case 3:
            // Alert sounds
            let cell = NSTextField(labelWithString: alertSounds[row])
            cell.font = SnowLeopardFonts.label(size: 12)
            return cell

        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }

        switch table.tag {
        case 1:
            audio.setDefaultOutputDevice(outputDevices[row].id)
        case 2:
            audio.setDefaultInputDevice(inputDevices[row].id)
        case 3:
            // Play alert sound preview
            let soundName = alertSounds[row]
            if let sound = NSSound(named: NSSound.Name(soundName)) {
                sound.play()
            }
        default:
            break
        }
    }
}
