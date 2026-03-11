import Cocoa

class KeyboardPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "keyboard" }
    var paneTitle: String { "Keyboard" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyboard") ?? NSImage()
    }
    var paneCategory: PaneCategory { .hardware }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 460) }
    var searchKeywords: [String] { ["keyboard", "key repeat", "delay", "autocorrect", "capitalize", "smart quotes"] }
    var viewController: NSViewController { self }

    private let defaults = DefaultsService.shared

    // MARK: - Controls

    private let keyRepeatLabel = NSTextField(labelWithString: "Key Repeat Rate:")
    private let keyRepeatSlider = NSSlider(value: 2, minValue: 1, maxValue: 120, target: nil, action: nil)
    private let repeatSlowLabel = NSTextField(labelWithString: "Slow")
    private let repeatFastLabel = NSTextField(labelWithString: "Fast")

    private let delayLabel = NSTextField(labelWithString: "Delay Until Repeat:")
    private let delaySlider = NSSlider(value: 25, minValue: 10, maxValue: 120, target: nil, action: nil)
    private let delayShortLabel = NSTextField(labelWithString: "Short")
    private let delayLongLabel = NSTextField(labelWithString: "Long")

    private let autocorrectCheck = NSButton(checkboxWithTitle: "Correct spelling automatically", target: nil, action: nil)
    private let capitalizeCheck = NSButton(checkboxWithTitle: "Capitalize words automatically", target: nil, action: nil)
    private let periodCheck = NSButton(checkboxWithTitle: "Add period with double-space", target: nil, action: nil)
    private let smartQuotesCheck = NSButton(checkboxWithTitle: "Use smart quotes and dashes", target: nil, action: nil)

    override func loadView() {
        view = NSView()

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)

        // Key repeat
        keyRepeatSlider.target = self; keyRepeatSlider.action = #selector(keyRepeatChanged(_:))
        keyRepeatSlider.isContinuous = false
        keyRepeatSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        repeatSlowLabel.font = NSFont.systemFont(ofSize: 10)
        repeatFastLabel.font = NSFont.systemFont(ofSize: 10)
        let repeatRow = NSStackView(views: [keyRepeatLabel, repeatSlowLabel, keyRepeatSlider, repeatFastLabel])
        repeatRow.spacing = 8

        // Delay until repeat
        delaySlider.target = self; delaySlider.action = #selector(delayChanged(_:))
        delaySlider.isContinuous = false
        delaySlider.widthAnchor.constraint(equalToConstant: 300).isActive = true
        delayShortLabel.font = NSFont.systemFont(ofSize: 10)
        delayLongLabel.font = NSFont.systemFont(ofSize: 10)
        let delayRow = NSStackView(views: [delayLabel, delayShortLabel, delaySlider, delayLongLabel])
        delayRow.spacing = 8

        // Separator
        let sep = NSBox()
        sep.boxType = .separator
        sep.widthAnchor.constraint(equalToConstant: 580).isActive = true

        // Text corrections
        let textLabel = NSTextField(labelWithString: "Text Input:")
        textLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)

        autocorrectCheck.target = self; autocorrectCheck.action = #selector(textOptionChanged(_:))
        capitalizeCheck.target = self; capitalizeCheck.action = #selector(textOptionChanged(_:))
        periodCheck.target = self; periodCheck.action = #selector(textOptionChanged(_:))
        smartQuotesCheck.target = self; smartQuotesCheck.action = #selector(textOptionChanged(_:))

        stack.addArrangedSubview(repeatRow)
        stack.addArrangedSubview(delayRow)
        stack.addArrangedSubview(sep)
        stack.addArrangedSubview(textLabel)
        stack.addArrangedSubview(autocorrectCheck)
        stack.addArrangedSubview(capitalizeCheck)
        stack.addArrangedSubview(periodCheck)
        stack.addArrangedSubview(smartQuotesCheck)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    func reloadFromSystem() {
        // Key repeat: lower value = faster. Invert for slider so right = fast
        let repeatRate = defaults.integer(forKey: "KeyRepeat") ?? 2
        keyRepeatSlider.integerValue = 121 - repeatRate // invert

        let initialRepeat = defaults.integer(forKey: "InitialKeyRepeat") ?? 25
        delaySlider.integerValue = 121 - initialRepeat // invert so right = short

        autocorrectCheck.state = (defaults.bool(forKey: "NSAutomaticSpellingCorrectionEnabled") ?? false) ? .on : .off
        capitalizeCheck.state = (defaults.bool(forKey: "NSAutomaticCapitalizationEnabled") ?? true) ? .on : .off
        periodCheck.state = (defaults.bool(forKey: "NSAutomaticPeriodSubstitutionEnabled") ?? true) ? .on : .off
        smartQuotesCheck.state = (defaults.bool(forKey: "NSAutomaticQuoteSubstitutionEnabled") ?? true) ? .on : .off
    }

    // MARK: - Actions

    @objc private func keyRepeatChanged(_ sender: NSSlider) {
        let value = 121 - sender.integerValue
        defaults.setInteger(max(1, value), forKey: "KeyRepeat")
    }

    @objc private func delayChanged(_ sender: NSSlider) {
        let value = 121 - sender.integerValue
        defaults.setInteger(max(10, value), forKey: "InitialKeyRepeat")
    }

    @objc private func textOptionChanged(_ sender: NSButton) {
        let on = sender.state == .on
        switch sender {
        case autocorrectCheck: defaults.setBool(on, forKey: "NSAutomaticSpellingCorrectionEnabled")
        case capitalizeCheck: defaults.setBool(on, forKey: "NSAutomaticCapitalizationEnabled")
        case periodCheck: defaults.setBool(on, forKey: "NSAutomaticPeriodSubstitutionEnabled")
        case smartQuotesCheck:
            defaults.setBool(on, forKey: "NSAutomaticQuoteSubstitutionEnabled")
            defaults.setBool(on, forKey: "NSAutomaticDashSubstitutionEnabled")
        default: break
        }
    }
}
