import Cocoa

class SoundPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "sound" }
    var paneTitle: String { "Sound" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Sound") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] { ["sound", "volume", "audio", "speaker", "microphone", "input", "output", "mute", "alert"] }
    var viewController: NSViewController { self }

    private let audio = AudioService.shared
    private let defaults = DefaultsService.shared

    // MARK: - UI

    private let tabView = NSTabView()

    // Output tab
    private let outputDeviceTable = NSTableView()
    private let outputVolumeSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let muteCheck = NSButton(checkboxWithTitle: "Mute", target: nil, action: nil)

    // Input tab
    private let inputDeviceTable = NSTableView()

    // Sound Effects tab
    private let alertVolumeSlider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let playSoundsCheck = NSButton(checkboxWithTitle: "Play user interface sound effects", target: nil, action: nil)
    private let volumeFeedbackCheck = NSButton(checkboxWithTitle: "Play feedback when volume is changed", target: nil, action: nil)

    private var outputDevices: [AudioService.AudioDevice] = []
    private var inputDevices: [AudioService.AudioDevice] = []

    override func loadView() {
        view = NSView()

        tabView.translatesAutoresizingMaskIntoConstraints = false

        // Output Tab
        let outputTab = NSTabViewItem(identifier: "output")
        outputTab.label = "Sound Effects"
        outputTab.view = createOutputTab()

        // Input Tab
        let inputTab = NSTabViewItem(identifier: "input")
        inputTab.label = "Output"
        inputTab.view = createOutputDeviceTab()

        // Effects Tab
        let effectsTab = NSTabViewItem(identifier: "effects")
        effectsTab.label = "Input"
        effectsTab.view = createInputTab()

        tabView.addTabViewItem(outputTab)
        tabView.addTabViewItem(inputTab)
        tabView.addTabViewItem(effectsTab)

        view.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
        ])
    }

    private func createOutputTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // Alert volume
        let alertLabel = NSTextField(labelWithString: "Alert volume:")
        alertVolumeSlider.target = self
        alertVolumeSlider.action = #selector(alertVolumeChanged(_:))
        alertVolumeSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let alertRow = NSStackView(views: [alertLabel, alertVolumeSlider])
        alertRow.spacing = 12

        // Sound effects
        playSoundsCheck.target = self; playSoundsCheck.action = #selector(soundEffectsChanged(_:))
        volumeFeedbackCheck.target = self; volumeFeedbackCheck.action = #selector(volumeFeedbackChanged(_:))

        // Output volume
        let volLabel = NSTextField(labelWithString: "Output volume:")
        outputVolumeSlider.target = self
        outputVolumeSlider.action = #selector(outputVolumeChanged(_:))
        outputVolumeSlider.isContinuous = true
        outputVolumeSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        muteCheck.target = self; muteCheck.action = #selector(muteToggled(_:))
        let volRow = NSStackView(views: [volLabel, outputVolumeSlider, muteCheck])
        volRow.spacing = 12

        stack.addArrangedSubview(alertRow)
        stack.addArrangedSubview(playSoundsCheck)
        stack.addArrangedSubview(volumeFeedbackCheck)
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(volRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    private func createOutputDeviceTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        let label = NSTextField(labelWithString: "Select a device for sound output:")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = outputDeviceTable

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        column.width = 400
        outputDeviceTable.addTableColumn(column)
        outputDeviceTable.headerView = nil
        outputDeviceTable.delegate = self
        outputDeviceTable.dataSource = self
        outputDeviceTable.tag = 1
        outputDeviceTable.rowHeight = 24

        scrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(scrollView)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    private func createInputTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        let label = NSTextField(labelWithString: "Select a device for sound input:")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = inputDeviceTable

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Name"
        column.width = 400
        inputDeviceTable.addTableColumn(column)
        inputDeviceTable.headerView = nil
        inputDeviceTable.delegate = self
        inputDeviceTable.dataSource = self
        inputDeviceTable.tag = 2
        inputDeviceTable.rowHeight = 24

        scrollView.widthAnchor.constraint(equalToConstant: 580).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(scrollView)

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
        // Volume
        if let vol = audio.getOutputVolume() {
            outputVolumeSlider.floatValue = vol
        }
        muteCheck.state = (audio.isMuted() ?? false) ? .on : .off

        // Devices
        outputDevices = audio.getOutputDevices()
        inputDevices = audio.getInputDevices()
        outputDeviceTable.reloadData()
        inputDeviceTable.reloadData()

        // Select current devices
        if let currentOutput = audio.getDefaultOutputDeviceID() {
            if let idx = outputDevices.firstIndex(where: { $0.id == currentOutput }) {
                outputDeviceTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            }
        }
        if let currentInput = audio.getDefaultInputDeviceID() {
            if let idx = inputDevices.firstIndex(where: { $0.id == currentInput }) {
                inputDeviceTable.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
            }
        }

        // Sound effects
        let uiSounds = defaults.bool(forKey: "com.apple.sound.uiaudio.enabled") ?? true
        playSoundsCheck.state = uiSounds ? .on : .off
        let feedback = defaults.bool(forKey: "com.apple.sound.beep.feedback") ?? true
        volumeFeedbackCheck.state = feedback ? .on : .off

        let alertVol = defaults.float(forKey: "com.apple.sound.beep.volume") ?? 0.5
        alertVolumeSlider.floatValue = alertVol
    }

    // MARK: - Actions

    @objc private func outputVolumeChanged(_ sender: NSSlider) {
        audio.setOutputVolume(sender.floatValue)
    }

    @objc private func muteToggled(_ sender: NSButton) {
        audio.setMuted(sender.state == .on)
    }

    @objc private func alertVolumeChanged(_ sender: NSSlider) {
        defaults.setFloat(sender.floatValue, forKey: "com.apple.sound.beep.volume")
    }

    @objc private func soundEffectsChanged(_ sender: NSButton) {
        defaults.setBool(sender.state == .on, forKey: "com.apple.sound.uiaudio.enabled")
    }

    @objc private func volumeFeedbackChanged(_ sender: NSButton) {
        defaults.setBool(sender.state == .on, forKey: "com.apple.sound.beep.feedback")
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        sep.widthAnchor.constraint(equalToConstant: 560).isActive = true
        return sep
    }
}

// MARK: - NSTableViewDataSource & Delegate

extension SoundPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableView.tag == 1 ? outputDevices.count : inputDevices.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let device = tableView.tag == 1 ? outputDevices[row] : inputDevices[row]
        let cell = NSTextField(labelWithString: device.name)
        cell.font = NSFont.systemFont(ofSize: 13)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let table = notification.object as? NSTableView else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }

        if table.tag == 1 {
            audio.setDefaultOutputDevice(outputDevices[row].id)
        } else {
            audio.setDefaultInputDevice(inputDevices[row].id)
        }
    }
}
