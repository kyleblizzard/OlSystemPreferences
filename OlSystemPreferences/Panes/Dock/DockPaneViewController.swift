import Cocoa

class DockPaneViewController: NSViewController, PaneProtocol {

    var paneIdentifier: String { "dock" }
    var paneTitle: String { "Dock & Menu Bar" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Dock") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 480) }
    var searchKeywords: [String] { ["dock", "menu bar", "size", "magnification", "autohide", "minimize", "position", "recent"] }
    var viewController: NSViewController { self }

    private let dock = DockService.shared

    // MARK: - Controls

    private let sizeSlider = NSSlider(value: 48, minValue: 16, maxValue: 128, target: nil, action: nil)
    private let sizeLabel = NSTextField(labelWithString: "Size:")
    private let smallLabel = NSTextField(labelWithString: "Small")
    private let largeLabel = NSTextField(labelWithString: "Large")

    private let magnificationCheck = NSButton(checkboxWithTitle: "Magnification", target: nil, action: nil)
    private let magSlider = NSSlider(value: 64, minValue: 16, maxValue: 128, target: nil, action: nil)

    private let positionLabel = NSTextField(labelWithString: "Position on screen:")
    private let leftButton = NSButton(radioButtonWithTitle: "Left", target: nil, action: nil)
    private let bottomButton = NSButton(radioButtonWithTitle: "Bottom", target: nil, action: nil)
    private let rightButton = NSButton(radioButtonWithTitle: "Right", target: nil, action: nil)

    private let effectLabel = NSTextField(labelWithString: "Minimize windows using:")
    private let effectPopup = NSPopUpButton()

    private let minimizeToAppCheck = NSButton(checkboxWithTitle: "Minimize windows into application icon", target: nil, action: nil)
    private let animateCheck = NSButton(checkboxWithTitle: "Animate opening applications", target: nil, action: nil)
    private let autohideCheck = NSButton(checkboxWithTitle: "Automatically hide and show the Dock", target: nil, action: nil)
    private let indicatorsCheck = NSButton(checkboxWithTitle: "Show indicators for open applications", target: nil, action: nil)
    private let showRecentsCheck = NSButton(checkboxWithTitle: "Show recent applications in Dock", target: nil, action: nil)

    override func loadView() {
        view = NSView()

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 12
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 40, bottom: 20, right: 40)

        // Size row
        sizeSlider.target = self; sizeSlider.action = #selector(sizeChanged(_:))
        sizeSlider.isContinuous = true
        smallLabel.font = NSFont.systemFont(ofSize: 10)
        largeLabel.font = NSFont.systemFont(ofSize: 10)

        let sizeRow = NSStackView(views: [sizeLabel, smallLabel, sizeSlider, largeLabel])
        sizeRow.spacing = 8
        sizeSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true

        // Magnification row
        magnificationCheck.target = self; magnificationCheck.action = #selector(magnificationToggled(_:))
        magSlider.target = self; magSlider.action = #selector(magSizeChanged(_:))
        magSlider.isContinuous = true
        let magSmall = NSTextField(labelWithString: "Small")
        magSmall.font = NSFont.systemFont(ofSize: 10)
        let magLarge = NSTextField(labelWithString: "Large")
        magLarge.font = NSFont.systemFont(ofSize: 10)
        let magRow = NSStackView(views: [magnificationCheck, magSmall, magSlider, magLarge])
        magRow.spacing = 8
        magSlider.widthAnchor.constraint(equalToConstant: 250).isActive = true

        // Position row
        leftButton.target = self; leftButton.action = #selector(positionChanged(_:))
        bottomButton.target = self; bottomButton.action = #selector(positionChanged(_:))
        rightButton.target = self; rightButton.action = #selector(positionChanged(_:))
        let posRow = NSStackView(views: [positionLabel, leftButton, bottomButton, rightButton])
        posRow.spacing = 12

        // Effect row
        effectPopup.addItems(withTitles: ["Genie effect", "Scale effect"])
        effectPopup.target = self; effectPopup.action = #selector(effectChanged(_:))
        let effectRow = NSStackView(views: [effectLabel, effectPopup])
        effectRow.spacing = 12

        // Checkboxes
        minimizeToAppCheck.target = self; minimizeToAppCheck.action = #selector(checkboxChanged(_:))
        animateCheck.target = self; animateCheck.action = #selector(checkboxChanged(_:))
        autohideCheck.target = self; autohideCheck.action = #selector(checkboxChanged(_:))
        indicatorsCheck.target = self; indicatorsCheck.action = #selector(checkboxChanged(_:))
        showRecentsCheck.target = self; showRecentsCheck.action = #selector(checkboxChanged(_:))

        let separator = NSBox()
        separator.boxType = .separator
        separator.widthAnchor.constraint(equalToConstant: 580).isActive = true

        stackView.addArrangedSubview(sizeRow)
        stackView.addArrangedSubview(magRow)
        stackView.addArrangedSubview(separator)
        stackView.addArrangedSubview(posRow)
        stackView.addArrangedSubview(effectRow)
        stackView.addArrangedSubview(makeSeparator())
        stackView.addArrangedSubview(minimizeToAppCheck)
        stackView.addArrangedSubview(animateCheck)
        stackView.addArrangedSubview(autohideCheck)
        stackView.addArrangedSubview(indicatorsCheck)
        stackView.addArrangedSubview(showRecentsCheck)

        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        sizeSlider.integerValue = dock.tileSize
        magnificationCheck.state = dock.magnification ? .on : .off
        magSlider.integerValue = dock.largeSize
        magSlider.isEnabled = dock.magnification

        switch dock.orientation {
        case "left":
            leftButton.state = .on; bottomButton.state = .off; rightButton.state = .off
        case "right":
            leftButton.state = .off; bottomButton.state = .off; rightButton.state = .on
        default:
            leftButton.state = .off; bottomButton.state = .on; rightButton.state = .off
        }

        effectPopup.selectItem(at: dock.minimizeEffect == "scale" ? 1 : 0)
        minimizeToAppCheck.state = dock.minimizeToApplication ? .on : .off
        animateCheck.state = dock.launchAnimation ? .on : .off
        autohideCheck.state = dock.autohide ? .on : .off
        indicatorsCheck.state = dock.showProcessIndicators ? .on : .off
        showRecentsCheck.state = dock.showRecents ? .on : .off
    }

    // MARK: - Actions

    @objc private func sizeChanged(_ sender: NSSlider) {
        dock.tileSize = sender.integerValue
    }

    @objc private func magnificationToggled(_ sender: NSButton) {
        dock.magnification = sender.state == .on
        magSlider.isEnabled = sender.state == .on
    }

    @objc private func magSizeChanged(_ sender: NSSlider) {
        dock.largeSize = sender.integerValue
    }

    @objc private func positionChanged(_ sender: NSButton) {
        if sender === leftButton {
            dock.orientation = "left"
            bottomButton.state = .off; rightButton.state = .off
        } else if sender === bottomButton {
            dock.orientation = "bottom"
            leftButton.state = .off; rightButton.state = .off
        } else {
            dock.orientation = "right"
            leftButton.state = .off; bottomButton.state = .off
        }
    }

    @objc private func effectChanged(_ sender: NSPopUpButton) {
        dock.minimizeEffect = sender.indexOfSelectedItem == 1 ? "scale" : "genie"
    }

    @objc private func checkboxChanged(_ sender: NSButton) {
        let on = sender.state == .on
        switch sender {
        case minimizeToAppCheck: dock.minimizeToApplication = on
        case animateCheck: dock.launchAnimation = on
        case autohideCheck: dock.autohide = on
        case indicatorsCheck: dock.showProcessIndicators = on
        case showRecentsCheck: dock.showRecents = on
        default: break
        }
    }

    private func makeSeparator() -> NSView {
        let sep = NSBox()
        sep.boxType = .separator
        sep.widthAnchor.constraint(equalToConstant: 580).isActive = true
        return sep
    }
}
