import Cocoa

class DashboardWindowController: NSWindowController {

    var onDismiss: (() -> Void)?
    private var isShowing = false

    convenience init() {
        let window = DashboardWindow()
        self.init(window: window)
    }

    func toggle() {
        if isShowing { dismiss() } else { show() }
    }

    func show() {
        guard !isShowing, let window = window, let screen = NSScreen.main else { return }

        let fraction = DashboardConstants.windowScreenFraction
        let screenFrame = screen.visibleFrame
        let w = screenFrame.width * fraction
        let h = screenFrame.height * fraction
        let x = screenFrame.origin.x + (screenFrame.width - w) / 2
        let y = screenFrame.origin.y + (screenFrame.height - h) / 2
        window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = DashboardConstants.showDuration
            window.animator().alphaValue = 1
        }

        isShowing = true

        // Auto-show widget bar if no widgets exist
        if let dashWindow = window as? DashboardWindow {
            dashWindow.contentArea.showBarIfEmpty()
        }
    }

    func dismissIfShowing() {
        guard isShowing else { return }
        dismiss()
    }

    @objc func dismiss() {
        guard isShowing, let window = window else { return }

        onDismiss?()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = DashboardConstants.dismissDuration
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
        })

        isShowing = false
    }
}

// MARK: - Dashboard Window

private class DashboardWindow: NSWindow {

    let contentArea = DashboardContentView()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .transient]
        appearance = NSAppearance(named: .darkAqua)

        let effectView = NSVisualEffectView()
        effectView.material = .fullScreenUI
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = DashboardConstants.cornerRadius

        contentView = effectView

        // Close button
        let closeButton = NSButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .circular
        closeButton.title = ""
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor(white: 0.7, alpha: 0.9)
        closeButton.target = nil
        closeButton.action = #selector(DashboardWindowController.dismiss)
        effectView.addSubview(closeButton)

        // Add widget button — target set directly to contentArea
        let addButton = NSButton()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.bezelStyle = .circular
        addButton.title = ""
        addButton.image = NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add Widget")
        addButton.imagePosition = .imageOnly
        addButton.isBordered = false
        addButton.contentTintColor = NSColor(white: 0.7, alpha: 0.9)
        addButton.target = contentArea
        addButton.action = #selector(DashboardContentView.toggleWidgetBar)
        effectView.addSubview(addButton)

        // Hint label
        let hintLabel = NSTextField(labelWithString: "Click + to add widgets")
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = SnowLeopardFonts.label(size: 14)
        hintLabel.textColor = NSColor(white: 0.5, alpha: 0.6)
        hintLabel.alignment = .center
        hintLabel.tag = 999
        effectView.addSubview(hintLabel)

        // Content area
        contentArea.translatesAutoresizingMaskIntoConstraints = false
        contentArea.hintLabel = hintLabel
        effectView.addSubview(contentArea)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            addButton.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 12),
            addButton.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -12),
            addButton.widthAnchor.constraint(equalToConstant: 24),
            addButton.heightAnchor.constraint(equalToConstant: 24),

            hintLabel.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            hintLabel.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),

            contentArea.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 44),
            contentArea.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            contentArea.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            contentArea.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])

        contentArea.loadSavedWidgets()
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            (windowController as? DashboardWindowController)?.dismiss()
        } else if event.modifierFlags.contains(.command) && event.characters == "w" {
            (windowController as? DashboardWindowController)?.dismiss()
        } else {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Dashboard Content View

class DashboardContentView: NSView, WidgetBarDelegate {

    private let widgetContainer = NSView()
    private let widgetBar = WidgetBarView()
    private var barVisible = false
    private var barBottomConstraint: NSLayoutConstraint?
    weak var hintLabel: NSTextField?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        widgetContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(widgetContainer)

        widgetBar.translatesAutoresizingMaskIntoConstraints = false
        widgetBar.delegate = self
        addSubview(widgetBar)

        let barBottom = widgetBar.topAnchor.constraint(equalTo: bottomAnchor)
        barBottomConstraint = barBottom

        NSLayoutConstraint.activate([
            widgetContainer.topAnchor.constraint(equalTo: topAnchor),
            widgetContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            widgetContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            widgetContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            widgetBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            widgetBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            widgetBar.heightAnchor.constraint(equalToConstant: 80),
            barBottom,
        ])
    }

    func showBarIfEmpty() {
        let hasWidgets = widgetContainer.subviews.contains { $0 is DashboardWidget }
        hintLabel?.isHidden = hasWidgets
        if !hasWidgets && !barVisible {
            toggleWidgetBar()
        }
    }

    @objc func toggleWidgetBar() {
        barVisible.toggle()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.allowsImplicitAnimation = true
            barBottomConstraint?.constant = barVisible ? -80 : 0
            layoutSubtreeIfNeeded()
        }
    }

    func loadSavedWidgets() {
        guard let arrangement = DashboardPersistence.load() else { return }
        for entry in arrangement.widgets {
            let widget = createWidget(type: entry.type)
            widget.instanceId = entry.instanceId
            widget.finalizeSetup()
            widget.restoreData(entry.data)
            widget.frame.origin = NSPoint(x: entry.x, y: entry.y)
            widgetContainer.addSubview(widget)
        }
        hintLabel?.isHidden = !arrangement.widgets.isEmpty
    }

    func saveArrangement() {
        let entries = widgetContainer.subviews.compactMap { view -> DashboardArrangement.WidgetEntry? in
            guard let widget = view as? DashboardWidget else { return nil }
            return DashboardArrangement.WidgetEntry(
                type: widget.widgetIdentifier,
                instanceId: widget.instanceId,
                x: Double(widget.frame.origin.x),
                y: Double(widget.frame.origin.y),
                data: widget.persistedData
            )
        }
        DashboardPersistence.save(DashboardArrangement(widgets: entries))
    }

    func removeWidget(_ widget: DashboardWidget) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            widget.animator().alphaValue = 0
        }, completionHandler: {
            widget.removeFromSuperview()
            self.saveArrangement()
            let hasWidgets = self.widgetContainer.subviews.contains { $0 is DashboardWidget }
            self.hintLabel?.isHidden = hasWidgets
        })
    }

    // MARK: - WidgetBarDelegate

    func widgetBar(_ bar: WidgetBarView, didSelectType type: String) {
        let widget = createWidget(type: type)
        widget.finalizeSetup()

        // Place near center with slight random offset
        let cx = bounds.midX - widget.widgetSize.width / 2 + CGFloat.random(in: -40...40)
        let cy = bounds.midY - widget.widgetSize.height / 2 + CGFloat.random(in: -40...40)
        widget.frame.origin = NSPoint(x: cx, y: cy)

        widget.alphaValue = 0
        widgetContainer.addSubview(widget)

        // Ripple animation
        addRippleEffect(at: NSPoint(x: cx + widget.widgetSize.width / 2, y: cy + widget.widgetSize.height / 2))

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            widget.animator().alphaValue = 1
        }

        hintLabel?.isHidden = true
        saveArrangement()
    }

    private func createWidget(type: String) -> DashboardWidget {
        switch type {
        case "calculator": return CalculatorWidget()
        case "stickynote": return StickyNoteWidget()
        case "clock": return ClockWidget()
        case "weather": return WeatherWidget()
        case "unitconverter": return UnitConverterWidget()
        default: return DashboardWidget()
        }
    }

    private func addRippleEffect(at center: NSPoint) {
        let ripple = CAShapeLayer()
        let startRadius: CGFloat = 10
        let endRadius: CGFloat = 60

        ripple.path = CGPath(ellipseIn: CGRect(
            x: center.x - startRadius, y: center.y - startRadius,
            width: startRadius * 2, height: startRadius * 2
        ), transform: nil)
        ripple.fillColor = NSColor(white: 1.0, alpha: 0.3).cgColor
        ripple.opacity = 1

        widgetContainer.wantsLayer = true
        widgetContainer.layer?.addSublayer(ripple)

        let pathAnim = CABasicAnimation(keyPath: "path")
        pathAnim.toValue = CGPath(ellipseIn: CGRect(
            x: center.x - endRadius, y: center.y - endRadius,
            width: endRadius * 2, height: endRadius * 2
        ), transform: nil)

        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.toValue = 0

        let group = CAAnimationGroup()
        group.animations = [pathAnim, fadeAnim]
        group.duration = 0.4
        group.isRemovedOnCompletion = true

        CATransaction.begin()
        CATransaction.setCompletionBlock { ripple.removeFromSuperlayer() }
        ripple.add(group, forKey: "ripple")
        CATransaction.commit()
    }
}
