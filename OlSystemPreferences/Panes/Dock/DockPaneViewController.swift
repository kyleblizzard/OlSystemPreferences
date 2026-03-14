import Cocoa

class DockPaneViewController: NSViewController, PaneProtocol {

    // MARK: - PaneProtocol

    var paneIdentifier: String { "dock" }
    var paneTitle: String { "Dock" }
    var paneIcon: NSImage {
        NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "Dock") ?? NSImage()
    }
    var paneCategory: PaneCategory { .personal }
    var preferredPaneSize: NSSize { NSSize(width: 668, height: 600) }
    var searchKeywords: [String] { ["dock", "menu bar", "size", "magnification", "autohide", "minimize", "position", "recent"] }
    var viewController: NSViewController { self }
    var settingsURL: String { "com.apple.Desktop-Settings.extension" }

    // MARK: - Services

    private let dock = DockService.shared
    private let dockPreview = DockPreviewView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))

    // MARK: - Controls

    private let sizeSlider = AquaSlider(minValue: 16, maxValue: 128, value: 48)
    private let magCheckbox = AquaCheckbox(title: "Magnification")
    private let magSlider = AquaSlider(minValue: 16, maxValue: 128, value: 64)

    private let leftRadio = AquaRadioButton(title: "Left")
    private let bottomRadio = AquaRadioButton(title: "Bottom")
    private let rightRadio = AquaRadioButton(title: "Right")
    private let effectPopup = AquaPopUpButton(items: ["Genie effect", "Scale effect"])

    private let minimizeToAppCheck = AquaCheckbox(title: "Minimize windows into application icon")
    private let animateCheck = AquaCheckbox(title: "Animate opening applications")
    private let autohideCheck = AquaCheckbox(title: "Automatically hide and show the Dock")
    private let indicatorsCheck = AquaCheckbox(title: "Show indicators for open applications")
    private let showRecentsCheck = AquaCheckbox(title: "Show recent applications in Dock")

    // Keep a reference to the scroll view wrapping the outer stack
    private var scrollView: NSScrollView!

    // MARK: - Load View

    override func loadView() {
        let root = NSView()
        root.translatesAutoresizingMaskIntoConstraints = false
        view = root

        // Outer vertical stack
        let outerStack = NSStackView()
        outerStack.translatesAutoresizingMaskIntoConstraints = false
        outerStack.orientation = .vertical
        outerStack.alignment = .leading
        outerStack.spacing = 16
        outerStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)

        // --- Header ---
        let header = SnowLeopardPaneHelper.makePaneHeader(
            icon: paneIcon,
            title: paneTitle,
            settingsURL: settingsURL
        )
        outerStack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Section 1: Dock Size & Magnification
        // =====================================================================
        let sizeBox = SnowLeopardPaneHelper.makeSectionBox(title: "Dock Size & Magnification")
        let sizeStack = NSStackView()
        sizeStack.translatesAutoresizingMaskIntoConstraints = false
        sizeStack.orientation = .vertical
        sizeStack.alignment = .leading
        sizeStack.spacing = 10
        sizeStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Dock preview
        dockPreview.translatesAutoresizingMaskIntoConstraints = false
        dockPreview.wantsLayer = true
        dockPreview.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1.0).cgColor
        dockPreview.layer?.cornerRadius = 8
        let previewContainer = NSStackView(views: [dockPreview])
        previewContainer.alignment = .centerX
        dockPreview.widthAnchor.constraint(equalToConstant: 300).isActive = true
        dockPreview.heightAnchor.constraint(equalToConstant: 80).isActive = true
        sizeStack.addArrangedSubview(previewContainer)
        previewContainer.widthAnchor.constraint(equalTo: sizeStack.widthAnchor, constant: -16).isActive = true

        // Size slider row
        sizeSlider.target = self
        sizeSlider.action = #selector(sizeChanged(_:))
        sizeSlider.isContinuous = true
        sizeSlider.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let smallLabel = SnowLeopardPaneHelper.makeLabel("Small", size: 10)
        let largeLabel = SnowLeopardPaneHelper.makeLabel("Large", size: 10)
        let sizeLabel = SnowLeopardPaneHelper.makeLabel("Size:")
        sizeLabel.alignment = .right
        sizeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        let sizeRow = NSStackView(views: [sizeLabel, smallLabel, sizeSlider, largeLabel])
        sizeRow.spacing = 6
        sizeRow.alignment = .firstBaseline
        sizeStack.addArrangedSubview(sizeRow)

        // Magnification row
        magCheckbox.target = self
        magCheckbox.action = #selector(magnificationToggled(_:))

        magSlider.target = self
        magSlider.action = #selector(magSizeChanged(_:))
        magSlider.isContinuous = true
        magSlider.widthAnchor.constraint(equalToConstant: 220).isActive = true

        let magSmallLabel = SnowLeopardPaneHelper.makeLabel("Small", size: 10)
        let magLargeLabel = SnowLeopardPaneHelper.makeLabel("Large", size: 10)
        let magLabel = SnowLeopardPaneHelper.makeLabel("")
        magLabel.alignment = .right
        magLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        // Place the checkbox in label position
        let magRow = NSStackView(views: [magCheckbox, magSmallLabel, magSlider, magLargeLabel])
        magRow.spacing = 6
        magRow.alignment = .firstBaseline

        // Indent magnification row to align with size controls
        let magIndent = NSStackView(views: [magLabel, magRow])
        magIndent.spacing = 0
        // Actually, just use the checkbox row directly
        let magRowFinal = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel(""),
            controls: [magCheckbox, magSmallLabel, magSlider, magLargeLabel],
            spacing: 6
        )
        sizeStack.addArrangedSubview(magRowFinal)

        sizeBox.contentView = sizeStack
        outerStack.addArrangedSubview(sizeBox)
        sizeBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Section 2: Position & Effects
        // =====================================================================
        let posBox = SnowLeopardPaneHelper.makeSectionBox(title: "Position & Effects")
        let posStack = NSStackView()
        posStack.translatesAutoresizingMaskIntoConstraints = false
        posStack.orientation = .vertical
        posStack.alignment = .leading
        posStack.spacing = 10
        posStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Position radio buttons — same groupTag so they auto-deselect
        leftRadio.groupTag = 1
        bottomRadio.groupTag = 1
        rightRadio.groupTag = 1
        leftRadio.target = self; leftRadio.action = #selector(positionChanged(_:))
        bottomRadio.target = self; bottomRadio.action = #selector(positionChanged(_:))
        rightRadio.target = self; rightRadio.action = #selector(positionChanged(_:))

        let posRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Position on screen:"),
            controls: [leftRadio, bottomRadio, rightRadio]
        )
        posStack.addArrangedSubview(posRow)

        // Minimize effect popup
        effectPopup.target = self
        effectPopup.action = #selector(effectChanged(_:))

        let effectRow = SnowLeopardPaneHelper.makeRow(
            label: SnowLeopardPaneHelper.makeLabel("Minimize using:"),
            controls: [effectPopup]
        )
        posStack.addArrangedSubview(effectRow)

        posBox.contentView = posStack
        outerStack.addArrangedSubview(posBox)
        posBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // =====================================================================
        // Section 3: Options
        // =====================================================================
        let optBox = SnowLeopardPaneHelper.makeSectionBox(title: "Options")
        let optStack = NSStackView()
        optStack.translatesAutoresizingMaskIntoConstraints = false
        optStack.orientation = .vertical
        optStack.alignment = .leading
        optStack.spacing = 6
        optStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let allChecks: [AquaCheckbox] = [minimizeToAppCheck, animateCheck, autohideCheck, indicatorsCheck, showRecentsCheck]
        for check in allChecks {
            check.target = self
            check.action = #selector(checkboxChanged(_:))
            // Indent checkboxes to align with other sections' controls
            let row = SnowLeopardPaneHelper.makeRow(
                label: SnowLeopardPaneHelper.makeLabel(""),
                controls: [check]
            )
            optStack.addArrangedSubview(row)
        }

        optBox.contentView = optStack
        outerStack.addArrangedSubview(optBox)
        optBox.widthAnchor.constraint(equalTo: outerStack.widthAnchor, constant: -48).isActive = true

        // Embed in scroll view for safety
        let sv = NSScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.documentView = outerStack
        sv.hasVerticalScroller = true
        sv.drawsBackground = false
        scrollView = sv

        root.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.topAnchor.constraint(equalTo: root.topAnchor),
            sv.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            outerStack.widthAnchor.constraint(equalTo: sv.widthAnchor),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadFromSystem()
    }

    // MARK: - PaneProtocol

    func reloadFromSystem() {
        sizeSlider.doubleValue = Double(dock.tileSize)
        magCheckbox.isChecked = dock.magnification
        magSlider.doubleValue = Double(dock.largeSize)
        magSlider.isEnabled = dock.magnification

        switch dock.orientation {
        case "left":
            leftRadio.isSelected = true; bottomRadio.isSelected = false; rightRadio.isSelected = false
        case "right":
            leftRadio.isSelected = false; bottomRadio.isSelected = false; rightRadio.isSelected = true
        default:
            leftRadio.isSelected = false; bottomRadio.isSelected = true; rightRadio.isSelected = false
        }

        effectPopup.selectedIndex = dock.minimizeEffect == "scale" ? 1 : 0
        minimizeToAppCheck.isChecked = dock.minimizeToApplication
        animateCheck.isChecked = dock.launchAnimation
        autohideCheck.isChecked = dock.autohide
        indicatorsCheck.isChecked = dock.showProcessIndicators
        showRecentsCheck.isChecked = dock.showRecents

        // Sync preview
        dockPreview.dockSize = CGFloat(dock.tileSize)
        dockPreview.magnificationEnabled = dock.magnification
        dockPreview.magnificationSize = CGFloat(dock.largeSize)
        dockPreview.position = dock.orientation
        dockPreview.showIndicators = dock.showProcessIndicators
    }

    // MARK: - Actions

    @objc private func sizeChanged(_ sender: AquaSlider) {
        dock.tileSize = Int(sender.doubleValue)
        dockPreview.dockSize = CGFloat(Int(sender.doubleValue))
    }

    @objc private func magnificationToggled(_ sender: AquaCheckbox) {
        dock.magnification = sender.isChecked
        magSlider.isEnabled = sender.isChecked
        dockPreview.magnificationEnabled = sender.isChecked
    }

    @objc private func magSizeChanged(_ sender: AquaSlider) {
        dock.largeSize = Int(sender.doubleValue)
        dockPreview.magnificationSize = CGFloat(Int(sender.doubleValue))
    }

    @objc private func positionChanged(_ sender: AquaRadioButton) {
        if sender === leftRadio {
            dock.orientation = "left"
            dockPreview.position = "left"
        } else if sender === bottomRadio {
            dock.orientation = "bottom"
            dockPreview.position = "bottom"
        } else {
            dock.orientation = "right"
            dockPreview.position = "right"
        }
    }

    @objc private func effectChanged(_ sender: AquaPopUpButton) {
        dock.minimizeEffect = sender.selectedIndex == 1 ? "scale" : "genie"
    }

    @objc private func checkboxChanged(_ sender: AquaCheckbox) {
        let on = sender.isChecked
        switch sender {
        case minimizeToAppCheck: dock.minimizeToApplication = on
        case animateCheck: dock.launchAnimation = on
        case autohideCheck: dock.autohide = on
        case indicatorsCheck:
            dock.showProcessIndicators = on
            dockPreview.showIndicators = on
        case showRecentsCheck: dock.showRecents = on
        default: break
        }
    }
}
