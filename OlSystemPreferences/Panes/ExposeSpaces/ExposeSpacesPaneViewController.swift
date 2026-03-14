import Cocoa

class ExposeSpacesPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "exposespaces" }
    var paneTitle: String { "Expose\u{0301} & Spaces" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Expose & Spaces") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 520) }
    var searchKeywords: [String] { ["expose", "spaces", "hot corner", "mission control", "desktop", "screen saver", "lock screen"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Desktop-Settings.extension" }

    // MARK: - Services

    private let defaults = DefaultsService.shared
    private let dockDomain = "com.apple.dock"

    // MARK: - Corner popup buttons

    private let topLeftPopup = NSPopUpButton()
    private let topRightPopup = NSPopUpButton()
    private let bottomLeftPopup = NSPopUpButton()
    private let bottomRightPopup = NSPopUpButton()

    // MARK: - Corner action definitions

    private let cornerActions: [(title: String, code: Int)] = [
        ("\u{2014}", 0),                  // em dash = none
        ("Mission Control", 2),
        ("Application Windows", 3),
        ("Desktop", 4),
        ("Start Screen Saver", 5),
        ("Disable Screen Saver", 6),
        ("Dashboard", 7),
        ("Launchpad", 11),
        ("Notification Center", 12),
        ("Lock Screen", 13),
        ("Put Display to Sleep", 10),
    ]

    // MARK: - Monitor bezel view (local, drawn inline)

    private let monitorView = MonitorFrameView()

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

        // Section box for hot corners
        let hotCornersBox = SnowLeopardPaneHelper.makeSectionBox(title: "Active Screen Corners")
        hotCornersBox.widthAnchor.constraint(equalToConstant: 620).isActive = true

        let hotCornersContent = createHotCornersContent()
        hotCornersBox.contentView = hotCornersContent

        outerStack.addArrangedSubview(hotCornersBox)

        // Description text
        let descLabel = SnowLeopardPaneHelper.makeLabel(
            "Move your pointer to a corner of the screen to start an action. You can also hold modifier keys to require them for activation.",
            size: 11
        )
        descLabel.preferredMaxLayoutWidth = 600
        descLabel.lineBreakMode = .byWordWrapping
        descLabel.maximumNumberOfLines = 3
        descLabel.textColor = NSColor(white: 0.40, alpha: 1.0)
        outerStack.addArrangedSubview(descLabel)

        view.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            outerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            outerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            outerStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -16),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - Hot Corners Content

    private func createHotCornersContent() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Monitor in center
        monitorView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(monitorView)

        // Setup all four corner popups
        for popup in [topLeftPopup, topRightPopup, bottomLeftPopup, bottomRightPopup] {
            setupCornerPopup(popup)
            popup.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(popup)
            popup.widthAnchor.constraint(equalToConstant: 170).isActive = true
        }

        // Corner labels
        let tlLabel = makeCornerLabel("Top Left:")
        let trLabel = makeCornerLabel("Top Right:")
        let blLabel = makeCornerLabel("Bottom Left:")
        let brLabel = makeCornerLabel("Bottom Right:")
        container.addSubview(tlLabel)
        container.addSubview(trLabel)
        container.addSubview(blLabel)
        container.addSubview(brLabel)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 340),

            // Monitor centered
            monitorView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            monitorView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            monitorView.widthAnchor.constraint(equalToConstant: 240),
            monitorView.heightAnchor.constraint(equalToConstant: 180),

            // Top-left label + popup
            tlLabel.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            tlLabel.bottomAnchor.constraint(equalTo: topLeftPopup.topAnchor, constant: -2),

            topLeftPopup.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            topLeftPopup.centerYAnchor.constraint(equalTo: monitorView.topAnchor, constant: 20),

            // Top-right label + popup
            trLabel.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            trLabel.bottomAnchor.constraint(equalTo: topRightPopup.topAnchor, constant: -2),

            topRightPopup.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            topRightPopup.centerYAnchor.constraint(equalTo: monitorView.topAnchor, constant: 20),

            // Bottom-left label + popup
            blLabel.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            blLabel.bottomAnchor.constraint(equalTo: bottomLeftPopup.topAnchor, constant: -2),

            bottomLeftPopup.trailingAnchor.constraint(equalTo: monitorView.leadingAnchor, constant: -12),
            bottomLeftPopup.centerYAnchor.constraint(equalTo: monitorView.bottomAnchor, constant: -40),

            // Bottom-right label + popup
            brLabel.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            brLabel.bottomAnchor.constraint(equalTo: bottomRightPopup.topAnchor, constant: -2),

            bottomRightPopup.leadingAnchor.constraint(equalTo: monitorView.trailingAnchor, constant: 12),
            bottomRightPopup.centerYAnchor.constraint(equalTo: monitorView.bottomAnchor, constant: -40),
        ])

        return container
    }

    // MARK: - Helpers

    private func makeCornerLabel(_ text: String) -> NSTextField {
        let label = SnowLeopardPaneHelper.makeLabel(text, size: 10, bold: true)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func setupCornerPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for action in cornerActions {
            popup.addItem(withTitle: action.title)
            popup.lastItem?.tag = action.code
        }
        popup.font = SnowLeopardFonts.label(size: 11)
        popup.controlSize = .small
        popup.target = self
        popup.action = #selector(cornerChanged(_:))
    }

    // MARK: - Reload

    func reloadFromSystem() {
        loadCorner("wvous-tl-corner", popup: topLeftPopup)
        loadCorner("wvous-tr-corner", popup: topRightPopup)
        loadCorner("wvous-bl-corner", popup: bottomLeftPopup)
        loadCorner("wvous-br-corner", popup: bottomRightPopup)
    }

    private func loadCorner(_ key: String, popup: NSPopUpButton) {
        let code = defaults.integer(forKey: key, domain: dockDomain) ?? 0
        for i in 0..<popup.numberOfItems {
            if popup.item(at: i)?.tag == code {
                popup.selectItem(at: i)
                return
            }
        }
        popup.selectItem(at: 0)
    }

    // MARK: - Actions

    @objc private func cornerChanged(_ sender: NSPopUpButton) {
        guard let code = sender.selectedItem?.tag else { return }

        let key: String
        switch sender {
        case topLeftPopup:
            key = "wvous-tl-corner"
        case topRightPopup:
            key = "wvous-tr-corner"
        case bottomLeftPopup:
            key = "wvous-bl-corner"
        case bottomRightPopup:
            key = "wvous-br-corner"
        default:
            return
        }

        defaults.setInteger(code, forKey: key, domain: dockDomain)
        DockService.shared.applyChanges()
    }
}
