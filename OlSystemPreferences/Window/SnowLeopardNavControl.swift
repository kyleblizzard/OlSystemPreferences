import Cocoa

/// Snow Leopard pill-shaped back/forward segmented navigation control.
class SnowLeopardNavControl: NSView {

    var backAction: (() -> Void)?
    var forwardAction: (() -> Void)?

    var backEnabled = false { didSet { needsDisplay = true } }
    var forwardEnabled = false { didSet { needsDisplay = true } }

    private var pressedSegment: Int? = nil

    override var intrinsicContentSize: NSSize {
        return NSSize(width: 56, height: 24)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = false
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius: CGFloat = rect.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        let midX = bounds.midX

        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        let leftRect = NSRect(x: 0, y: 0, width: midX, height: bounds.height)
        drawSegmentBackground(in: leftRect, pressed: pressedSegment == 0)

        let rightRect = NSRect(x: midX, y: 0, width: bounds.width - midX, height: bounds.height)
        drawSegmentBackground(in: rightRect, pressed: pressedSegment == 1)

        NSGraphicsContext.restoreGraphicsState()

        SnowLeopardColors.navBorder.setStroke()
        path.lineWidth = 1.0
        path.stroke()

        SnowLeopardColors.navDivider.setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: midX, y: 2))
        divider.line(to: NSPoint(x: midX, y: bounds.height - 2))
        divider.lineWidth = 1.0
        divider.stroke()

        drawBackArrow(in: leftRect, enabled: backEnabled)
        drawForwardArrow(in: rightRect, enabled: forwardEnabled)
    }

    private func drawSegmentBackground(in rect: NSRect, pressed: Bool) {
        let top = pressed ? SnowLeopardColors.navPressedTop : SnowLeopardColors.navGradientTop
        let bottom = pressed ? SnowLeopardColors.navPressedBottom : SnowLeopardColors.navGradientBottom
        let gradient = NSGradient(starting: top, ending: bottom)
        gradient?.draw(in: rect, angle: 270)
    }

    private func drawBackArrow(in rect: NSRect, enabled: Bool) {
        let color = enabled ? SnowLeopardColors.navArrow : SnowLeopardColors.navArrowDisabled
        color.setFill()
        let cx = rect.midX, cy = rect.midY, size: CGFloat = 5.5
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: cx - size * 0.5, y: cy))
        arrow.line(to: NSPoint(x: cx + size * 0.5, y: cy + size))
        arrow.line(to: NSPoint(x: cx + size * 0.5, y: cy - size))
        arrow.close()
        arrow.fill()
    }

    private func drawForwardArrow(in rect: NSRect, enabled: Bool) {
        let color = enabled ? SnowLeopardColors.navArrow : SnowLeopardColors.navArrowDisabled
        color.setFill()
        let cx = rect.midX, cy = rect.midY, size: CGFloat = 5.5
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: cx + size * 0.5, y: cy))
        arrow.line(to: NSPoint(x: cx - size * 0.5, y: cy + size))
        arrow.line(to: NSPoint(x: cx - size * 0.5, y: cy - size))
        arrow.close()
        arrow.fill()
    }

    // MARK: - Mouse Handling

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pressedSegment = point.x < bounds.midX ? 0 : 1
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            if point.x < bounds.midX && backEnabled { backAction?() }
            else if point.x >= bounds.midX && forwardEnabled { forwardAction?() }
        }
        pressedSegment = nil
        needsDisplay = true
    }
}
