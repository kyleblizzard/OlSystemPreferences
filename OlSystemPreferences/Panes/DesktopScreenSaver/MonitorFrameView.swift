import Cocoa

/// Reusable monitor bezel view with an embedded content area, matching Snow Leopard monitor preview style.
class MonitorFrameView: NSView {

    let contentView: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.cornerRadius = 2
        v.layer?.masksToBounds = true
        return v
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
        ])
    }

    override func draw(_ dirtyRect: NSRect) {
        let bezelRect = NSRect(
            x: 0,
            y: 20,
            width: bounds.width,
            height: bounds.height - 20
        )

        // Monitor body
        let bodyPath = NSBezierPath(roundedRect: bezelRect, xRadius: 6, yRadius: 6)
        NSColor(white: 0.22, alpha: 1.0).setFill()
        bodyPath.fill()

        // Screen border
        let screenRect = bezelRect.insetBy(dx: 8, dy: 8)
        NSColor(white: 0.12, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: screenRect, xRadius: 2, yRadius: 2).fill()

        // Stand
        let standWidth: CGFloat = bounds.width * 0.22
        let standHeight: CGFloat = 18
        let standX = bounds.midX - standWidth / 2
        let standRect = NSRect(x: standX, y: 2, width: standWidth, height: standHeight)
        NSColor(white: 0.30, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: standRect, xRadius: 2, yRadius: 2).fill()

        // Base
        let baseWidth: CGFloat = bounds.width * 0.35
        let baseRect = NSRect(x: bounds.midX - baseWidth / 2, y: 0, width: baseWidth, height: 5)
        NSColor(white: 0.28, alpha: 1.0).setFill()
        NSBezierPath(roundedRect: baseRect, xRadius: 2.5, yRadius: 2.5).fill()
    }
}
