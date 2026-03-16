import Cocoa

class RedirectPaneViewController: NSViewController, PaneProtocol {

    private let _paneIdentifier: String
    private let _paneTitle: String
    private let _paneIcon: NSImage
    private let _paneCategory: PaneCategory
    private let _settingsURL: String
    private let _searchKeywords: [String]
    private let _description: String

    var paneIdentifier: String { _paneIdentifier }
    var paneTitle: String { _paneTitle }
    var paneIcon: NSImage { _paneIcon }
    var paneCategory: PaneCategory { _paneCategory }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 340) }
    var searchKeywords: [String] { _searchKeywords }
    var viewController: NSViewController { self }
    var settingsURL: String { _settingsURL }

    init(identifier: String, title: String, sfSymbol: String, category: PaneCategory, settingsURL: String, keywords: [String], description: String) {
        self._paneIdentifier = identifier
        self._paneTitle = title
        self._paneIcon = NSImage(systemSymbolName: sfSymbol, accessibilityDescription: title) ?? NSImage()
        self._paneCategory = category
        self._settingsURL = settingsURL
        self._searchKeywords = keywords
        self._description = description
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()

        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .centerX
        outerStack.spacing = 20
        outerStack.edgeInsets = NSEdgeInsets(top: 40, left: 40, bottom: 40, right: 40)

        // Large icon (64x64)
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = _paneIcon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        // Tint the icon
        if let img = NSImage(systemSymbolName: _paneIcon.name() ?? "gearshape", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 48, weight: .regular)
            iconView.image = img.withSymbolConfiguration(config) ?? img
        }
        iconView.contentTintColor = .systemBlue
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
        ])

        // Title
        let titleLabel = NSTextField(labelWithString: _paneTitle)
        titleLabel.font = SnowLeopardFonts.boldLabel(size: 16)
        titleLabel.textColor = NSColor(white: 0.15, alpha: 1.0)
        titleLabel.alignment = .center

        // Description
        let descLabel = NSTextField(wrappingLabelWithString: _description)
        descLabel.font = SnowLeopardFonts.label(size: 12)
        descLabel.textColor = NSColor(white: 0.35, alpha: 1.0)
        descLabel.alignment = .center
        descLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 400).isActive = true

        // Open button (prominent)
        let openButton = NSButton()
        openButton.title = "Open in System Settings..."
        openButton.bezelStyle = .rounded
        openButton.font = SnowLeopardFonts.label(size: 13)
        openButton.target = self
        openButton.action = #selector(openSystemSettings)
        openButton.keyEquivalent = "\r"  // Default button

        // Info text
        let infoLabel = NSTextField(labelWithString: "This preference pane requires System Settings to configure.")
        infoLabel.font = SnowLeopardFonts.label(size: 10)
        infoLabel.textColor = NSColor(white: 0.55, alpha: 1.0)
        infoLabel.alignment = .center

        outerStack.addArrangedSubview(iconView)
        outerStack.addArrangedSubview(titleLabel)
        outerStack.addArrangedSubview(descLabel)
        outerStack.addArrangedSubview(openButton)
        outerStack.addArrangedSubview(infoLabel)

        view.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: view.topAnchor),
            outerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    func reloadFromSystem() {}

    @objc private func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:\(_settingsURL)") else { return }
        NSWorkspace.shared.open(url)
    }
}
