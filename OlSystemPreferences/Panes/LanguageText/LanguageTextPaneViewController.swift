// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import Cocoa

// MARK: - Language & Text Pane View Controller
//
// Recreates the Snow Leopard "Language & Text" preference pane with four tabs:
//   1. Language   — preferred language list read from system defaults
//   2. Text       — smart quotes, spelling correction, word break options
//   3. Formats    — regional date/time/number/currency format examples
//   4. Input Sources — active keyboard layouts read from HIToolbox defaults
//
// Data is read from real system preferences wherever possible using
// DefaultsService, NSSpellChecker, Locale, and the `defaults` CLI tool.

class LanguageTextPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol Properties

    var paneIdentifier: String { "languagetext" }
    var paneTitle: String { "Language & Text" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "character.book.closed.fill",
                accessibilityDescription: "Language & Text") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] {
        ["language", "region", "text", "input source", "format",
         "international", "locale"]
    }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Keyboard-Settings.extension" }

    // MARK: - Services

    /// Shared helper for reading / writing user defaults and CFPreferences.
    private let defaults = DefaultsService.shared

    // MARK: - Tab View

    /// The four-tab Aqua-styled tab bar that lives below the pane header.
    private let tabView = AquaTabView()

    // ---- Language tab data ----
    /// The ordered list of preferred language display names (e.g. "English", "Japanese").
    private var preferredLanguages: [String] = []
    /// NSTableView showing the language list on the Language tab.
    private let languageTableView = NSTableView()

    // ---- Text tab controls ----
    /// "Word Break:" popup — Standard, Japanese, etc.
    private let wordBreakPopup = AquaPopUpButton(items: ["Standard", "Japanese", "Thai"], selectedIndex: 0)
    /// "Use smart quotes and dashes" checkbox.
    private let smartQuotesCheck = AquaCheckbox(title: "Use smart quotes and dashes", isChecked: true)
    /// Read-only label showing current smart quote style, e.g.  \u{201C}abc\u{201D} and \u{2018}abc\u{2019}.
    private let smartQuotesStyleLabel = NSTextField(labelWithString: "\u{201C}abc\u{201D} and \u{2018}abc\u{2019}")
    /// "Correct spelling automatically" checkbox.
    private let autoSpellingCheck = AquaCheckbox(title: "Correct spelling automatically", isChecked: false)
    /// "Spelling:" popup listing available spell-check languages.
    private let spellingPopup = AquaPopUpButton(items: [], selectedIndex: 0)

    // ---- Formats tab controls ----
    /// "Region:" popup showing the current locale / region.
    private let regionPopup = AquaPopUpButton(items: [], selectedIndex: 0)
    /// Static labels showing formatted date, time, number, currency, and measurement examples.
    private let dateFormatLabel = NSTextField(labelWithString: "")
    private let timeFormatLabel = NSTextField(labelWithString: "")
    private let numberFormatLabel = NSTextField(labelWithString: "")
    private let currencyFormatLabel = NSTextField(labelWithString: "")
    private let measurementLabel = NSTextField(labelWithString: "")

    // ---- Input Sources tab data ----
    /// Array of (name, kind) tuples parsed from HIToolbox's AppleEnabledInputSources.
    private var inputSources: [(name: String, kind: String)] = []
    /// NSTableView listing active input sources.
    private let inputSourcesTableView = NSTableView()
    /// "Show Input menu in menu bar" checkbox.
    private let showInputMenuCheck = AquaCheckbox(title: "Show Input menu in menu bar", isChecked: false)

    // MARK: - Load View
    //
    // Builds the entire view hierarchy programmatically (no XIB / SwiftUI).
    // The layout follows the same pattern as every other pane in the project:
    //   root view → outer vertical stack → [header, tab view]

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Outer stack provides consistent margins and spacing used by all panes.
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 12
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header (icon + title + "Open in System Settings..." button) ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // --- Tab View (Language | Text | Formats | Input Sources) ---
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.addTab(title: "Language", view: buildLanguageTab())
        tabView.addTab(title: "Text", view: buildTextTab())
        tabView.addTab(title: "Formats", view: buildFormatsTab())
        tabView.addTab(title: "Input Sources", view: buildInputSourcesTab())
        tabView.selectTab(at: 0)

        outerStack.addArrangedSubview(tabView)
        tabView.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true
        tabView.heightAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true

        root.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: root.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor),
        ])
    }

    // MARK: - Language Tab
    //
    // Displays the user's preferred languages in ranked order.
    // The list is read from `defaults read -g AppleLanguages`, which returns
    // an array of locale codes (e.g. ["en", "ja", "fr"]).  We convert each
    // code into a human-readable name using Foundation's Locale.

    private func buildLanguageTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // Section header
        let headerLabel = SnowLeopardPaneHelper.makeLabel("Languages:", size: 11, bold: true)
        stack.addArrangedSubview(headerLabel)

        // Explanatory text — matches Snow Leopard's descriptive paragraph.
        let descLabel = SnowLeopardPaneHelper.makeLabel(
            "Drag languages into the order you prefer. Applications will use the first "
            + "language in this list that they support.",
            size: 10
        )
        descLabel.textColor = .secondaryLabelColor
        descLabel.maximumNumberOfLines = 3
        descLabel.preferredMaxLayoutWidth = 560
        stack.addArrangedSubview(descLabel)

        // --- Language table inside a scroll view ---
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // Single column: language name
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("LanguageName"))
        nameColumn.title = "Language"
        nameColumn.width = 520
        languageTableView.addTableColumn(nameColumn)
        languageTableView.headerView = nil
        languageTableView.delegate = self
        languageTableView.dataSource = self
        languageTableView.tag = 1     // tag 1 = language table
        languageTableView.rowHeight = 22
        languageTableView.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = languageTableView
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        stack.addArrangedSubview(scrollView)

        // "Edit List..." button — opens System Settings since we can't add
        // languages natively without private APIs.
        let editButton = SnowLeopardPaneHelper.makeAquaButton(
            title: "Edit List...",
            target: self,
            action: #selector(editLanguageList(_:))
        )
        stack.addArrangedSubview(editButton)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Text Tab
    //
    // Controls for word-break style, smart quotes, and automatic spell correction.
    // These map to real NSUserDefaults keys that macOS respects system-wide.

    private func buildTextTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // --- Word Break section ---
        let wordBreakBox = SnowLeopardPaneHelper.makeSectionBox(title: "Word Break")
        let wordBreakStack = NSStackView()
        wordBreakStack.translatesAutoresizingMaskIntoConstraints = false
        wordBreakStack.orientation = .vertical
        wordBreakStack.alignment = .leading
        wordBreakStack.spacing = 8
        wordBreakStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        wordBreakPopup.target = self
        wordBreakPopup.action = #selector(wordBreakChanged(_:))

        let wordBreakRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Word Break:"),
            controls: [wordBreakPopup]
        )
        wordBreakStack.addArrangedSubview(wordBreakRow)
        wordBreakBox.contentView = wordBreakStack
        stack.addArrangedSubview(wordBreakBox)
        wordBreakBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        // --- Smart Quotes & Spelling section ---
        let textBox = SnowLeopardPaneHelper.makeSectionBox(title: "Smart Quotes & Spelling")
        let textStack = NSStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 8
        textStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Smart quotes checkbox
        smartQuotesCheck.target = self
        smartQuotesCheck.action = #selector(smartQuotesChanged(_:))
        let smartQuotesRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [smartQuotesCheck]
        )
        textStack.addArrangedSubview(smartQuotesRow)

        // Smart quotes style preview label — shows the actual quote characters.
        smartQuotesStyleLabel.font = SnowLeopardFonts.label(size: 11)
        smartQuotesStyleLabel.textColor = .secondaryLabelColor
        let styleRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [smartQuotesStyleLabel]
        )
        textStack.addArrangedSubview(styleRow)

        textStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 500))

        // Correct spelling automatically checkbox
        autoSpellingCheck.target = self
        autoSpellingCheck.action = #selector(autoSpellingChanged(_:))
        let spellingCheckRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [autoSpellingCheck]
        )
        textStack.addArrangedSubview(spellingCheckRow)

        // Spelling language popup — populated from NSSpellChecker.
        spellingPopup.target = self
        spellingPopup.action = #selector(spellingLanguageChanged(_:))
        let spellingRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Spelling:"),
            controls: [spellingPopup]
        )
        textStack.addArrangedSubview(spellingRow)

        textBox.contentView = textStack
        stack.addArrangedSubview(textBox)
        textBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Formats Tab
    //
    // Displays region-specific formatting examples: dates, times, numbers,
    // currency, and measurement system.  All values are derived from the
    // user's current locale (AppleLocale) using Foundation formatters.

    private func buildFormatsTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // --- Region popup ---
        regionPopup.target = self
        regionPopup.action = #selector(regionChanged(_:))
        let regionRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Region:"),
            controls: [regionPopup]
        )
        stack.addArrangedSubview(regionRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // --- Format examples inside a section box ---
        let formatsBox = SnowLeopardPaneHelper.makeSectionBox(title: "Formats")
        let formatsStack = NSStackView()
        formatsStack.translatesAutoresizingMaskIntoConstraints = false
        formatsStack.orientation = .vertical
        formatsStack.alignment = .leading
        formatsStack.spacing = 10
        formatsStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Style each example label
        let exampleLabels = [dateFormatLabel, timeFormatLabel, numberFormatLabel,
                             currencyFormatLabel, measurementLabel]
        for label in exampleLabels {
            label.font = SnowLeopardFonts.label(size: 11)
            label.textColor = NSColor(white: 0.15, alpha: 1.0)
        }

        // Date row
        let dateRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Dates:"),
            controls: [dateFormatLabel]
        )
        formatsStack.addArrangedSubview(dateRow)

        // Time row
        let timeRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Times:"),
            controls: [timeFormatLabel]
        )
        formatsStack.addArrangedSubview(timeRow)

        // Number row
        let numberRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Numbers:"),
            controls: [numberFormatLabel]
        )
        formatsStack.addArrangedSubview(numberRow)

        // Currency row
        let currencyRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Currency:"),
            controls: [currencyFormatLabel]
        )
        formatsStack.addArrangedSubview(currencyRow)

        formatsStack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 480))

        // Measurement system row
        let measureRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Measurement system:"),
            controls: [measurementLabel]
        )
        formatsStack.addArrangedSubview(measureRow)

        formatsBox.contentView = formatsStack
        stack.addArrangedSubview(formatsBox)
        formatsBox.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Input Sources Tab
    //
    // Lists active keyboard input sources read from the HIToolbox domain.
    // Each entry shows the input source name and its type (Keyboard Layout,
    // Input Mode, etc.).

    private func buildInputSourcesTab() -> NSView {
        let container = NSView()
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)

        // Header label
        let headerLabel = SnowLeopardPaneHelper.makeLabel("Active Input Sources:", size: 11, bold: true)
        stack.addArrangedSubview(headerLabel)

        // --- Input sources table ---
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        // Name column
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("InputSourceName"))
        nameColumn.title = "Name"
        nameColumn.width = 340
        inputSourcesTableView.addTableColumn(nameColumn)

        // Type column (Keyboard Layout, Input Mode, etc.)
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("InputSourceType"))
        typeColumn.title = "Type"
        typeColumn.width = 180
        inputSourcesTableView.addTableColumn(typeColumn)

        inputSourcesTableView.delegate = self
        inputSourcesTableView.dataSource = self
        inputSourcesTableView.tag = 2    // tag 2 = input sources table
        inputSourcesTableView.rowHeight = 22
        inputSourcesTableView.usesAlternatingRowBackgroundColors = true

        scrollView.documentView = inputSourcesTableView
        scrollView.widthAnchor.constraint(equalToConstant: 560).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 180).isActive = true
        stack.addArrangedSubview(scrollView)

        // --- "Show Input menu in menu bar" checkbox ---
        showInputMenuCheck.target = self
        showInputMenuCheck.action = #selector(showInputMenuChanged(_:))
        let inputMenuRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [showInputMenuCheck]
        )
        stack.addArrangedSubview(inputMenuRow)

        stack.addArrangedSubview(SnowLeopardPaneHelper.makeSeparator(width: 540))

        // "Keyboard Shortcuts..." button — deep-links into System Settings.
        let shortcutsButton = SnowLeopardPaneHelper.makeAquaButton(
            title: "Keyboard Shortcuts...",
            target: self,
            action: #selector(openKeyboardShortcuts(_:))
        )
        stack.addArrangedSubview(shortcutsButton)

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
    }

    func paneWillAppear() {
        reloadFromSystem()
    }

    // MARK: - PaneProtocol — Reload
    //
    // Reads live system values and populates every tab's controls.

    func reloadFromSystem() {
        loadPreferredLanguages()
        loadTextSettings()
        loadFormatSettings()
        loadInputSources()
    }

    // MARK: - Language Loading
    //
    // Reads `defaults read -g AppleLanguages` via Process, which returns a
    // plist array of locale codes.  We parse each code and convert it to a
    // human-readable display name (e.g. "en" → "English").

    private func loadPreferredLanguages() {
        preferredLanguages.removeAll()

        // Try reading the AppleLanguages array from global defaults.
        // CFPreferences can return this, but `defaults read` gives us the
        // raw plist text which is sometimes more reliable for arrays.
        if let output = runCommand("/usr/bin/defaults", arguments: ["read", "-g", "AppleLanguages"]) {
            // The output looks like a plist array:
            //   (
            //       "en-US",
            //       "ja",
            //       "fr"
            //   )
            // We strip parentheses, commas, and quotes to get clean locale codes.
            let lines = output.components(separatedBy: "\n")
            for line in lines {
                let cleaned = line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "(", with: "")
                    .replacingOccurrences(of: ")", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Skip empty lines or the array delimiters
                guard !cleaned.isEmpty else { continue }

                // Convert the locale code to a display name.
                // Locale.current gives us the name in the user's own language.
                let displayName = Locale.current.localizedString(forIdentifier: cleaned)
                    ?? cleaned
                preferredLanguages.append(displayName)
            }
        }

        // Fallback: if defaults read failed or returned nothing, use
        // Locale.preferredLanguages which is always available.
        if preferredLanguages.isEmpty {
            for code in Locale.preferredLanguages {
                let displayName = Locale.current.localizedString(forIdentifier: code) ?? code
                preferredLanguages.append(displayName)
            }
        }

        languageTableView.reloadData()

        // Highlight the primary (first) language.
        if !preferredLanguages.isEmpty {
            languageTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - Text Settings Loading
    //
    // Reads the NSAutomaticQuoteSubstitutionEnabled and
    // NSAutomaticSpellingCorrectionEnabled keys from global user defaults,
    // and populates the spelling language popup from NSSpellChecker.

    private func loadTextSettings() {
        // Smart quotes preference
        let smartQuotes = defaults.bool(forKey: "NSAutomaticQuoteSubstitutionEnabled") ?? true
        smartQuotesCheck.isChecked = smartQuotes

        // Automatic spelling correction preference
        let autoSpelling = defaults.bool(forKey: "NSAutomaticSpellingCorrectionEnabled") ?? false
        autoSpellingCheck.isChecked = autoSpelling

        // Populate the spelling language popup from NSSpellChecker.
        // availableLanguages gives us all languages the spell checker supports.
        let checker = NSSpellChecker.shared
        let availableLanguages = checker.availableLanguages
        let currentSpellingLang = checker.language()

        // Build the spelling language list with "Automatic" as the first option.
        var spellingItems = ["Automatic"]
        var spellingSelectedIdx = 0
        for (index, langCode) in availableLanguages.enumerated() {
            // Convert code to a readable name, falling back to the raw code.
            let displayName = Locale.current.localizedString(forIdentifier: langCode) ?? langCode
            spellingItems.append(displayName)

            // Check if this matches the current spelling language.
            if langCode == currentSpellingLang {
                // +1 because index 0 is "Automatic"
                spellingSelectedIdx = index + 1
            }
        }
        spellingPopup.items = spellingItems
        spellingPopup.selectedIndex = spellingSelectedIdx
    }

    // MARK: - Format Settings Loading
    //
    // Reads AppleLocale and AppleMeasurementUnits from global defaults,
    // then generates formatted examples using Foundation formatters configured
    // with the user's actual locale.

    private func loadFormatSettings() {
        // Read the current locale identifier (e.g. "en_US", "ja_JP").
        let localeID = defaults.string(forKey: "AppleLocale") ?? Locale.current.identifier
        let locale = Locale(identifier: localeID)

        // Populate the region popup with a readable name for the current locale.
        // We show the full locale display name (e.g. "English (United States)").
        let regionName = Locale.current.localizedString(forIdentifier: localeID) ?? localeID
        regionPopup.items = [regionName]
        regionPopup.selectedIndex = 0

        // --- Date format example ---
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        let dateExample = dateFormatter.string(from: Date())
        dateFormatLabel.stringValue = dateExample

        // --- Time format example ---
        let timeFormatter = DateFormatter()
        timeFormatter.locale = locale
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        let timeExample = timeFormatter.string(from: Date())
        timeFormatLabel.stringValue = timeExample

        // --- Number format example ---
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .decimal
        let numberExample = numberFormatter.string(from: NSNumber(value: 1234567.89)) ?? "1,234,567.89"
        numberFormatLabel.stringValue = numberExample

        // --- Currency format example ---
        let currencyFormatter = NumberFormatter()
        currencyFormatter.locale = locale
        currencyFormatter.numberStyle = .currency
        let currencyExample = currencyFormatter.string(from: NSNumber(value: 1234.56)) ?? "$1,234.56"
        currencyFormatLabel.stringValue = currencyExample

        // --- Measurement system ---
        // AppleMeasurementUnits stores "Centimeters" (Metric) or "Inches" (US).
        let measureUnits = defaults.string(forKey: "AppleMeasurementUnits") ?? "Centimeters"
        if measureUnits.lowercased().contains("inch") {
            measurementLabel.stringValue = "US"
        } else {
            measurementLabel.stringValue = "Metric"
        }
    }

    // MARK: - Input Sources Loading
    //
    // Reads `defaults read com.apple.HIToolbox AppleEnabledInputSources`,
    // which returns an array of dictionaries.  Each dictionary contains
    // keys like "InputSourceKind" and "KeyboardLayout Name" or
    // "Input Mode" describing the input method.

    private func loadInputSources() {
        inputSources.removeAll()

        if let output = runCommand("/usr/bin/defaults",
                                   arguments: ["read", "com.apple.HIToolbox", "AppleEnabledInputSources"]) {
            // The output is a plist-style array of dicts.  We parse it
            // line-by-line looking for name and kind keys.
            //
            // Example entry:
            //   {
            //       "InputSourceKind" = "Keyboard Layout";
            //       "KeyboardLayout ID" = 0;
            //       "KeyboardLayout Name" = "U.S.";
            //   }
            var currentName = ""
            var currentKind = ""

            let lines = output.components(separatedBy: "\n")
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // Detect the "KeyboardLayout Name" or "Input Mode" key
                // to get a display name for this input source.
                if trimmed.contains("\"KeyboardLayout Name\"") {
                    currentName = extractPlistValue(from: trimmed)
                } else if trimmed.contains("\"Input Mode\"") && currentName.isEmpty {
                    // Use Input Mode as fallback name if no KeyboardLayout Name
                    currentName = extractPlistValue(from: trimmed)
                } else if trimmed.contains("\"InputSourceKind\"") {
                    currentKind = extractPlistValue(from: trimmed)
                }

                // When we hit a closing brace, save the entry if we found a name.
                if trimmed.hasPrefix("}") || trimmed.hasPrefix("),") {
                    if !currentName.isEmpty {
                        // Make the kind string more readable
                        let friendlyKind = currentKind.isEmpty ? "Keyboard Layout" : currentKind
                        inputSources.append((name: currentName, kind: friendlyKind))
                    }
                    currentName = ""
                    currentKind = ""
                }
            }
        }

        // Fallback: if parsing failed, show at least a U.S. keyboard entry
        // so the tab isn't completely empty.
        if inputSources.isEmpty {
            inputSources.append((name: "U.S.", kind: "Keyboard Layout"))
        }

        inputSourcesTableView.reloadData()

        // Read "Show Input menu in menu bar" setting.
        // This is stored under com.apple.TextInputMenu as "visible".
        let showMenu = defaults.bool(forKey: "visible", domain: "com.apple.TextInputMenu") ?? false
        showInputMenuCheck.isChecked = showMenu
    }

    // MARK: - Plist Value Extraction Helper
    //
    // Parses a single key-value line from the `defaults read` plist output.
    // Lines look like:   "KeyboardLayout Name" = "U.S.";
    // We want the value part after the "=" sign, cleaned of quotes and semicolons.

    private func extractPlistValue(from line: String) -> String {
        // Split on "=" and take the right side
        guard let equalsIndex = line.firstIndex(of: "=") else { return "" }
        let valuePart = String(line[line.index(after: equalsIndex)...])
        return valuePart
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ";", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Shell Command Helper
    //
    // Runs a command-line tool and returns its standard output as a String.
    // Used to call `defaults read` for preferences that are easier to access
    // through the shell than through CFPreferences (e.g. arrays of dicts).

    private func runCommand(_ path: String, arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Actions

    /// Opens System Settings to the Language & Region pane so the user can
    /// add or remove languages (requires private APIs we don't have).
    @objc private func editLanguageList(_ sender: Any) {
        SystemSettingsLauncher.open(url: settingsURL)
    }

    /// Called when the user changes the Word Break popup selection.
    @objc private func wordBreakChanged(_ sender: AquaPopUpButton) {
        // Word break style is informational in Snow Leopard's UI.
        // The actual system setting is rarely changed by end users, so we
        // just keep track of the selection for display purposes.
    }

    /// Toggles the "Use smart quotes and dashes" system preference.
    @objc private func smartQuotesChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        // Also toggle smart dashes, which Snow Leopard bundled together.
        defaults.setBool(sender.isChecked, forKey: "NSAutomaticDashSubstitutionEnabled")
    }

    /// Toggles the "Correct spelling automatically" system preference.
    @objc private func autoSpellingChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "NSAutomaticSpellingCorrectionEnabled")
    }

    /// Called when the user picks a different spelling language from the popup.
    @objc private func spellingLanguageChanged(_ sender: AquaPopUpButton) {
        let selectedTitle = sender.selectedTitle
        if selectedTitle == "Automatic" {
            // Reset to automatic language detection
            NSSpellChecker.shared.setLanguage("en")
        } else {
            // Find the matching language code from NSSpellChecker's available list.
            let checker = NSSpellChecker.shared
            for langCode in checker.availableLanguages {
                let displayName = Locale.current.localizedString(forIdentifier: langCode) ?? langCode
                if displayName == selectedTitle {
                    checker.setLanguage(langCode)
                    break
                }
            }
        }
    }

    /// Called when the region popup changes (informational — the real region
    /// setting requires System Settings to modify).
    @objc private func regionChanged(_ sender: AquaPopUpButton) {
        // Region changes require System Settings; refresh format examples.
        loadFormatSettings()
    }

    /// Toggles the "Show Input menu in menu bar" preference.
    @objc private func showInputMenuChanged(_ sender: AquaCheckbox) {
        defaults.setBool(sender.isChecked, forKey: "visible", domain: "com.apple.TextInputMenu")
    }

    /// Opens System Settings to the Keyboard Shortcuts section.
    @objc private func openKeyboardShortcuts(_ sender: Any) {
        SystemSettingsLauncher.open(url: settingsURL)
    }
}

// MARK: - NSTableViewDataSource & NSTableViewDelegate
//
// Two tables share this controller as their data source / delegate:
//   tag 1 = Language table (Language tab)
//   tag 2 = Input Sources table (Input Sources tab)

extension LanguageTextPaneViewController: NSTableViewDataSource, NSTableViewDelegate {

    /// Returns the number of rows for the requesting table.
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.tag {
        case 1:
            // Language table: one row per preferred language.
            return preferredLanguages.count
        case 2:
            // Input sources table: one row per active input source.
            return inputSources.count
        default:
            return 0
        }
    }

    /// Creates and configures the cell view for each row and column.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let columnID = tableColumn?.identifier.rawValue ?? ""

        switch tableView.tag {

        case 1:
            // --- Language table ---
            // Single column showing the display name of each preferred language.
            let cellID = NSUserInterfaceItemIdentifier("LanguageCell")
            let cell: NSTextField
            if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                cell = existing
            } else {
                cell = NSTextField(labelWithString: "")
                cell.identifier = cellID
                cell.font = SnowLeopardFonts.label(size: 12)
                cell.lineBreakMode = .byTruncatingTail
            }
            guard row < preferredLanguages.count else { return cell }

            let langName = preferredLanguages[row]
            // The primary language (row 0) gets bold styling and a note.
            if row == 0 {
                cell.font = SnowLeopardFonts.boldLabel(size: 12)
                cell.stringValue = "\(langName) — primary"
            } else {
                cell.font = SnowLeopardFonts.label(size: 12)
                cell.stringValue = langName
            }
            cell.textColor = NSColor(white: 0.15, alpha: 1.0)
            return cell

        case 2:
            // --- Input Sources table ---
            // Two columns: name and type.
            if columnID == "InputSourceName" {
                let cellID = NSUserInterfaceItemIdentifier("InputNameCell")
                let cell: NSTextField
                if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                    cell = existing
                } else {
                    cell = NSTextField(labelWithString: "")
                    cell.identifier = cellID
                    cell.font = SnowLeopardFonts.label(size: 12)
                    cell.lineBreakMode = .byTruncatingTail
                }
                guard row < inputSources.count else { return cell }
                cell.stringValue = inputSources[row].name
                cell.textColor = NSColor(white: 0.15, alpha: 1.0)
                return cell

            } else if columnID == "InputSourceType" {
                let cellID = NSUserInterfaceItemIdentifier("InputTypeCell")
                let cell: NSTextField
                if let existing = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTextField {
                    cell = existing
                } else {
                    cell = NSTextField(labelWithString: "")
                    cell.identifier = cellID
                    cell.font = SnowLeopardFonts.label(size: 12)
                    cell.lineBreakMode = .byTruncatingTail
                }
                guard row < inputSources.count else { return cell }
                cell.stringValue = inputSources[row].kind
                cell.textColor = .secondaryLabelColor
                return cell
            }

        default:
            break
        }

        return nil
    }
}
