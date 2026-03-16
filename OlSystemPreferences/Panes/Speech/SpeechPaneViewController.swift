// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

/// SpeechPaneViewController recreates the Snow Leopard "Speech" preference pane.
///
/// Snow Leopard's Speech pane had two tabs:
///   1. Text to Speech — lets you pick a system voice, adjust speaking rate, preview speech,
///      and toggle alert announcement options.
///   2. Speech Recognition (Dictation) — shows dictation on/off status, the configured
///      shortcut key, microphone info, and a link to open System Settings for deeper config.
///
/// This controller uses NSSpeechSynthesizer (the same API that powered Snow Leopard's speech)
/// to enumerate available voices, display their friendly names, and speak sample text on demand.
/// Dictation status is read from the `com.apple.assistant.support` defaults domain.
class SpeechPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol
    // These computed properties tell the main window controller everything it needs
    // to display this pane in the grid, search results, and toolbar.

    var paneIdentifier: String { "speech" }
    var paneTitle: String { "Speech" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "waveform", accessibilityDescription: "Speech") ?? NSImage()
    }
    var paneCategory: PaneCategory { .system }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 480) }
    var searchKeywords: [String] { ["speech", "text to speech", "voiceover", "recognition", "dictation", "voice"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Accessibility-Settings.extension" }

    // MARK: - Services

    /// DefaultsService wraps UserDefaults and CFPreferences for reading/writing system prefs.
    private let defaults = DefaultsService.shared

    /// NSSpeechSynthesizer is the macOS text-to-speech engine. We keep one instance alive
    /// so we can start/stop speech and change voices without recreating it each time.
    private var synthesizer = NSSpeechSynthesizer()

    // MARK: - Tab View

    /// AquaTabView is our custom Snow Leopard-styled tab control with the classic pill tabs.
    private let tabView = AquaTabView()

    // MARK: - Text to Speech Tab Controls

    /// Popup button listing all available system voices by their display name.
    private let voicePopup = AquaPopUpButton(items: [], selectedIndex: 0)

    /// Slider controlling how fast the synthesizer speaks (words per minute).
    /// Snow Leopard's range was roughly 100 (very slow) to 400 (very fast).
    private let rateSlider = AquaSlider(minValue: 100, maxValue: 400, value: 200)

    /// Editable text field containing the sample text the user can preview with the Play button.
    private let sampleTextField = NSTextField()

    /// Button that triggers the synthesizer to speak the sample text.
    private let playButton = AquaButton(title: "Play", isDefault: false)

    /// Checkbox: "Announce when alerts are displayed"
    private let announceAlertsCheck = AquaCheckbox(title: "Announce when alerts are displayed", isChecked: false)

    /// Checkbox: "Announce when an application requires your attention"
    private let announceAttentionCheck = AquaCheckbox(
        title: "Announce when an application requires your attention",
        isChecked: false
    )

    // MARK: - Speech Recognition Tab Controls

    /// Small colored dot indicating whether dictation is on (green) or off (red).
    private let dictationDot = NSView()

    /// Label showing "On" or "Off" next to the dictation status dot.
    private let dictationStatusLabel = NSTextField(labelWithString: "Off")

    /// Label displaying the current dictation shortcut key (e.g., "Press Fn Key Twice").
    private let shortcutLabel = NSTextField(labelWithString: "Press Fn (Function) Key Twice")

    /// Label showing the name of the currently selected microphone.
    private let microphoneLabel = NSTextField(labelWithString: "Internal Microphone")

    // MARK: - Voice Data

    /// Array of NSSpeechSynthesizer.VoiceName identifiers (e.g., "com.apple.speech.synthesis.voice.Alex").
    /// We store these so we can map the popup's selected index back to the actual voice identifier.
    private var voiceIdentifiers: [NSSpeechSynthesizer.VoiceName] = []

    // MARK: - Load View

    override func loadView() {
        // Create the root view that holds everything
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Outer vertical stack: header on top, tab view below
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        // The standard pane header shows the icon, title, and "Open in System Settings..." button
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Tab View ---
        // AquaTabView gives us the Snow Leopard pill-shaped tab buttons
        tabView.translatesAutoresizingMaskIntoConstraints = false

        // Add our two tabs: "Text to Speech" and "Speech Recognition"
        tabView.addTab(title: "Text to Speech", view: buildTextToSpeechTab())
        tabView.addTab(title: "Speech Recognition", view: buildSpeechRecognitionTab())
        tabView.selectTab(at: 0)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true

        // Pin the outer stack to the root view edges
        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Text to Speech Tab

    /// Builds the "Text to Speech" tab content, which includes:
    /// - A voice picker popup
    /// - A speaking rate slider
    /// - A sample text field with a Play button to preview the voice
    /// - Checkboxes for alert announcement preferences
    private func buildTextToSpeechTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // --- System Voice popup ---
        // Populate the popup with all available TTS voices from the system.
        // NSSpeechSynthesizer.availableVoices returns identifier strings like
        // "com.apple.speech.synthesis.voice.Alex" — we convert them to display names.
        populateVoicePopup()

        voicePopup.target = self
        voicePopup.action = #selector(voiceChanged(_:))
        voicePopup.widthAnchor.constraint(equalToConstant: 250).isActive = true

        let voiceRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("System Voice:"),
            controls: [voicePopup]
        )
        stack.addArrangedSubview(voiceRow)

        // --- Speaking Rate slider ---
        // The slider goes from 100 (slow) to 400 (fast) words per minute.
        // Labels on each end help the user understand the range.
        rateSlider.target = self
        rateSlider.action = #selector(rateChanged(_:))
        rateSlider.isContinuous = true
        rateSlider.showsFillColor = true
        rateSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let slowLabel = SnowLeopardPaneHelper.makeLabel("Slow", size: 10)
        let fastLabel = SnowLeopardPaneHelper.makeLabel("Fast", size: 10)

        let rateRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Speaking Rate:"),
            controls: [slowLabel, rateSlider, fastLabel],
            spacing: 6
        )
        stack.addArrangedSubview(rateRow)

        // --- Sample text + Play button ---
        // The user can edit the sample text and press Play to hear the selected voice.
        sampleTextField.translatesAutoresizingMaskIntoConstraints = false
        sampleTextField.font = SnowLeopardFonts.label(size: 12)
        sampleTextField.stringValue = "Most people recognize me by my voice."
        sampleTextField.isBordered = true
        sampleTextField.isBezeled = true
        sampleTextField.bezelStyle = .roundedBezel
        sampleTextField.isEditable = true
        sampleTextField.widthAnchor.constraint(equalToConstant: 320).isActive = true

        playButton.target = self
        playButton.action = #selector(playPressed(_:))

        let sampleRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [sampleTextField, playButton]
        )
        stack.addArrangedSubview(sampleRow)

        // --- Separator ---
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Alert announcement checkboxes ---
        // These match the Snow Leopard options for having the system speak alert text aloud.
        announceAlertsCheck.target = self
        announceAlertsCheck.action = #selector(announceAlertsChanged(_:))

        let alertCheckRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [announceAlertsCheck]
        )
        stack.addArrangedSubview(alertCheckRow)

        announceAttentionCheck.target = self
        announceAttentionCheck.action = #selector(announceAttentionChanged(_:))

        let attentionCheckRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [announceAttentionCheck]
        )
        stack.addArrangedSubview(attentionCheckRow)

        // --- Separator ---
        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Informational note ---
        let infoLabel = SnowLeopardPaneHelper.makeLabel(
            "Additional voice options and language downloads can be configured in System Settings.",
            size: 10
        )
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.maximumNumberOfLines = 2
        infoLabel.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(infoLabel)

        // Pin the stack inside the container
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Speech Recognition Tab

    /// Builds the "Speech Recognition" tab content, which includes:
    /// - Dictation on/off status with a colored indicator dot
    /// - The configured shortcut key for activating dictation
    /// - A button to jump to the full Dictation preferences in System Settings
    /// - Microphone selection info
    /// - A privacy note about speech data
    private func buildSpeechRecognitionTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        // --- Dictation status section ---
        let dictationTitle = SnowLeopardPaneHelper.makeLabel("Dictation:", size: 11, bold: true)
        stack.addArrangedSubview(dictationTitle)

        // Status dot — a small circle that is green (on) or red (off)
        dictationDot.translatesAutoresizingMaskIntoConstraints = false
        dictationDot.wantsLayer = true
        dictationDot.layer?.cornerRadius = 5
        dictationDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        dictationDot.widthAnchor.constraint(equalToConstant: 10).isActive = true
        dictationDot.heightAnchor.constraint(equalToConstant: 10).isActive = true

        // Status label — shows "On" or "Off"
        dictationStatusLabel.font = SnowLeopardFonts.label(size: 11)
        dictationStatusLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let statusRow = NSStackView(views: [dictationDot, dictationStatusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 6
        statusRow.alignment = .centerY

        let dictationStatusRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Status:"),
            controls: [statusRow]
        )
        stack.addArrangedSubview(dictationStatusRow)

        // --- Shortcut key display ---
        // Shows the keyboard shortcut for activating dictation.
        // The default on most Macs is pressing the Fn key twice.
        shortcutLabel.font = SnowLeopardFonts.label(size: 11)
        shortcutLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let shortcutRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Shortcut:"),
            controls: [shortcutLabel]
        )
        stack.addArrangedSubview(shortcutRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Microphone section ---
        let micTitle = SnowLeopardPaneHelper.makeLabel("Microphone:", size: 11, bold: true)
        stack.addArrangedSubview(micTitle)

        // Display the currently selected microphone name
        microphoneLabel.font = SnowLeopardFonts.label(size: 11)
        microphoneLabel.textColor = NSColor(white: 0.15, alpha: 1.0)

        let micRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Selected:"),
            controls: [microphoneLabel]
        )
        stack.addArrangedSubview(micRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Open Dictation Preferences button ---
        // Since dictation configuration requires full System Settings access,
        // we provide a convenient button to jump directly there.
        let openDictationButton = SnowLeopardPaneHelper.makeAquaButton(
            title: "Open Dictation Preferences...",
            target: self,
            action: #selector(openDictationPreferences)
        )

        let buttonRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [openDictationButton]
        )
        stack.addArrangedSubview(buttonRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Privacy note ---
        // Apple's Speech Recognition sends audio to Apple servers for processing.
        // Snow Leopard included a similar disclosure about speech data.
        let privacyNote = SnowLeopardPaneHelper.makeLabel(
            "When you use Dictation, the things you dictate and certain other information, "
            + "such as your first name, may be sent to Apple to process your requests. "
            + "Dictation data is not linked to other data that Apple may have.",
            size: 10
        )
        privacyNote.textColor = .secondaryLabelColor
        privacyNote.maximumNumberOfLines = 5
        privacyNote.preferredMaxLayoutWidth = 540
        stack.addArrangedSubview(privacyNote)

        // Pin the stack inside the container
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Voice Popup Helpers

    /// Queries NSSpeechSynthesizer for every available voice on the system and populates
    /// the voice popup button with their display names. Also stores the voice identifiers
    /// so we can map the selected popup index back to the correct voice.
    private func populateVoicePopup() {
        // Get all voice identifiers installed on this Mac
        let voices = NSSpeechSynthesizer.availableVoices
        voiceIdentifiers = voices

        // Convert each voice identifier into its user-friendly display name
        // (e.g., "com.apple.speech.synthesis.voice.Alex" -> "Alex")
        var names: [String] = []
        for voice in voices {
            let attrs = NSSpeechSynthesizer.attributes(forVoice: voice)
            let name = attrs[.name] as? String ?? voice.rawValue
            names.append(name)
        }

        // Set the items array directly — AquaPopUpButton uses an `items` property,
        // not the NSPopUpButton API, since it's a custom Snow Leopard-styled control.
        voicePopup.items = names

        // Select the current default voice in the popup
        let defaultVoice = NSSpeechSynthesizer.defaultVoice
        if let defaultIndex = voiceIdentifiers.firstIndex(of: defaultVoice) {
            voicePopup.selectedIndex = defaultIndex
        }
    }

    /// Returns the display name for a given voice identifier by reading its attributes.
    private func voiceName(for identifier: NSSpeechSynthesizer.VoiceName) -> String {
        let attrs = NSSpeechSynthesizer.attributes(forVoice: identifier)
        return attrs[.name] as? String ?? identifier.rawValue
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    func paneWillAppear() {
        reloadFromSystem()
    }

    func paneWillDisappear() {
        // Stop any speech in progress when the user navigates away
        synthesizer.stopSpeaking()
    }

    // MARK: - PaneProtocol — Reload

    /// Reads current system state and updates all controls to reflect it.
    /// Called on viewDidLoad and whenever the pane reappears.
    func reloadFromSystem() {
        // --- Text to Speech state ---

        // Re-populate voices in case the user installed new ones
        populateVoicePopup()

        // Set the speaking rate slider to the synthesizer's current rate.
        // NSSpeechSynthesizer.rate is in words per minute (WPM).
        // Default rate is typically around 175-200 WPM.
        let currentRate = synthesizer.rate
        if currentRate > 0 {
            rateSlider.doubleValue = Double(currentRate)
        } else {
            // If rate returns 0, use a sensible default
            rateSlider.doubleValue = 200
        }

        // Read alert announcement preferences from the speech domain
        let announceAlerts = defaults.bool(
            forKey: "SpokenUIUseSpeakingHotKeyFlag",
            domain: "com.apple.speech.synthesis.general.prefs"
        ) ?? false
        announceAlertsCheck.isChecked = announceAlerts

        let announceAttention = defaults.bool(
            forKey: "SpokenNotificationFlag",
            domain: "com.apple.speech.synthesis.general.prefs"
        ) ?? false
        announceAttentionCheck.isChecked = announceAttention

        // --- Speech Recognition (Dictation) state ---

        // Check if dictation is enabled by reading from the assistant support domain.
        // This is where macOS stores the on/off toggle for Dictation.
        let dictationEnabled = defaults.bool(
            forKey: "Dictation Enabled",
            domain: "com.apple.assistant.support"
        ) ?? false

        if dictationEnabled {
            dictationDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            dictationStatusLabel.stringValue = "On"
        } else {
            dictationDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            dictationStatusLabel.stringValue = "Off"
        }

        // Shortcut key — the default on modern Macs is "Press Fn Key Twice".
        // We show this as a static label since reading the actual symbolic hotkey
        // configuration is complex and fragile across OS versions.
        shortcutLabel.stringValue = "Press Fn (Function) Key Twice"

        // Microphone — try to read the selected microphone name.
        // If we can't read it, fall back to "Internal Microphone" which is the
        // default on all MacBooks and iMacs.
        let micName = readSelectedMicrophoneName()
        microphoneLabel.stringValue = micName
    }

    // MARK: - Microphone Name Helper

    /// Attempts to read the user's selected microphone name from system defaults.
    /// Falls back to "Internal Microphone" if the preference isn't set or readable.
    private func readSelectedMicrophoneName() -> String {
        // Try reading from the speech recognition domain
        if let name = defaults.string(
            forKey: "SelectedMicrophonePortName",
            domain: "com.apple.speech.recognition.AppleSpeechRecognition"
        ) {
            return name
        }
        // Default fallback — the most common built-in microphone name
        return "Internal Microphone"
    }

    // MARK: - Actions — Text to Speech

    /// Called when the user picks a different voice from the popup.
    /// Updates the synthesizer to use the newly selected voice.
    @objc private func voiceChanged(_ sender: AquaPopUpButton) {
        let index = sender.selectedIndex
        guard index >= 0, index < voiceIdentifiers.count else { return }

        // Set the synthesizer's voice to the selected one
        let selectedVoice = voiceIdentifiers[index]
        synthesizer.setVoice(selectedVoice)
    }

    /// Called when the user drags the speaking rate slider.
    /// Updates the synthesizer's words-per-minute rate in real time.
    @objc private func rateChanged(_ sender: AquaSlider) {
        let newRate = Float(sender.doubleValue)
        synthesizer.rate = newRate
    }

    /// Called when the user presses the "Play" button.
    /// Speaks the sample text field's contents using the currently selected voice and rate.
    @objc private func playPressed(_ sender: AquaButton) {
        // If already speaking, stop first so we don't overlap
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking()
            return
        }

        // Make sure the selected voice is applied to the synthesizer
        let index = voicePopup.selectedIndex
        if index >= 0, index < voiceIdentifiers.count {
            synthesizer.setVoice(voiceIdentifiers[index])
        }

        // Apply the current rate from the slider
        synthesizer.rate = Float(rateSlider.doubleValue)

        // Get the text to speak — use the sample field's content
        let text = sampleTextField.stringValue
        guard !text.isEmpty else { return }

        // Start speaking
        synthesizer.startSpeaking(text)
    }

    /// Called when the "Announce when alerts are displayed" checkbox changes.
    @objc private func announceAlertsChanged(_ sender: AquaCheckbox) {
        defaults.setBool(
            sender.isChecked,
            forKey: "SpokenUIUseSpeakingHotKeyFlag",
            domain: "com.apple.speech.synthesis.general.prefs"
        )
    }

    /// Called when the "Announce when an application requires your attention" checkbox changes.
    @objc private func announceAttentionChanged(_ sender: AquaCheckbox) {
        defaults.setBool(
            sender.isChecked,
            forKey: "SpokenNotificationFlag",
            domain: "com.apple.speech.synthesis.general.prefs"
        )
    }

    // MARK: - Actions — Speech Recognition

    /// Opens the Dictation section of System Settings.
    /// Since dictation configuration requires deeper system access than we can provide
    /// natively, we redirect the user to the real System Settings pane.
    @objc private func openDictationPreferences() {
        SystemSettingsLauncher.open(url: "com.apple.Keyboard-Settings.extension")
    }
}
