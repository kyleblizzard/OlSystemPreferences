import Cocoa

/// Base class for Dashboard widgets. Subclass and override `widgetIdentifier`, `widgetTitle`,
/// `widgetSize`, and `setupContent(in:)`.
class DashboardWidget: NSView {

    var widgetIdentifier: String { "base" }
    var widgetTitle: String { "Widget" }
    var widgetSize: NSSize { NSSize(width: 200, height: 200) }
    var instanceId: String = UUID().uuidString

    /// Override to persist widget-specific data.
    var persistedData: [String: String]? { nil }
    /// Override to restore widget-specific data.
    func restoreData(_ data: [String: String]?) {}

    private let titleBar = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let closeButton = NSButton()
    private let containerView = NSView()

    private var dragOrigin: NSPoint = .zero

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.92).cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.2).cgColor

        shadow = NSShadow()
        shadow?.shadowColor = NSColor(white: 0.0, alpha: 0.5)
        shadow?.shadowOffset = NSSize(width: 0, height: -3)
        shadow?.shadowBlurRadius = 10

        // Title bar
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        titleBar.wantsLayer = true
        titleBar.layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.5).cgColor
        addSubview(titleBar)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = SnowLeopardFonts.boldLabel(size: 10)
        titleLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
        titleBar.addSubview(titleLabel)

        // Close button (hidden until hover)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .circular
        closeButton.title = ""
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.isBordered = false
        closeButton.target = self
        closeButton.action = #selector(closeWidget(_:))
        closeButton.contentTintColor = NSColor(white: 0.7, alpha: 1.0)
        closeButton.isHidden = true
        titleBar.addSubview(closeButton)

        // Container for subclass content
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: 24),

            closeButton.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            closeButton.leadingAnchor.constraint(equalTo: titleBar.leadingAnchor, constant: 6),
            closeButton.widthAnchor.constraint(equalToConstant: 14),
            closeButton.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.centerYAnchor.constraint(equalTo: titleBar.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: titleBar.centerXAnchor),

            containerView.topAnchor.constraint(equalTo: titleBar.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func finalizeSetup() {
        titleLabel.stringValue = widgetTitle
        frame.size = widgetSize
        setupContent(in: containerView)
    }

    /// Override this method to add widget content.
    func setupContent(in container: NSView) {}

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        closeButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        closeButton.isHidden = true
    }

    // MARK: - Drag

    override func mouseDown(with event: NSEvent) {
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let current = superview?.convert(event.locationInWindow, from: nil) ?? .zero
        let startInSuper = superview?.convert(convert(dragOrigin, to: nil), from: nil) ?? .zero
        let newOrigin = NSPoint(
            x: frame.origin.x + (current.x - startInSuper.x),
            y: frame.origin.y + (current.y - startInSuper.y)
        )
        frame.origin = newOrigin
        dragOrigin = convert(event.locationInWindow, from: nil)
    }

    override func mouseUp(with event: NSEvent) {
        // Notify parent to save arrangement
        if let dashboard = superview?.superview as? DashboardContentView {
            dashboard.saveArrangement()
        }
    }

    @objc private func closeWidget(_ sender: Any?) {
        if let dashboard = superview?.superview as? DashboardContentView {
            dashboard.removeWidget(self)
        }
    }
}
