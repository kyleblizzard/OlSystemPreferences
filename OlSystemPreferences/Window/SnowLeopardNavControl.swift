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

// MARK: - Liquid Glass Mode Buttons

/// Four liquid-glass mode buttons: Preferences, Launchpad, Dashboard, Cover Flow.
/// Selected mode is highlighted with a glowing translucent fill.
class LiquidGlassModeButtons: NSView {

    enum Mode: Int, CaseIterable {
        case preferences = 0
        case launchpad = 1
        case dashboard = 2
        case coverFlow = 3

        var title: String {
            switch self {
            case .preferences: return "Preferences"
            case .launchpad:   return "Launchpad"
            case .dashboard:   return "Dashboard"
            case .coverFlow:   return "Cover Flow"
            }
        }

        var symbolName: String {
            switch self {
            case .preferences: return "gearshape"
            case .launchpad:   return "square.grid.3x3"
            case .dashboard:   return "gauge.medium"
            case .coverFlow:   return "rectangle.stack"
            }
        }
    }

    var selectedMode: Mode = .preferences { didSet { needsDisplay = true } }
    var onModeSelected: ((Mode) -> Void)?

    private var hoveredIndex: Int? = nil
    private var pressedIndex: Int? = nil

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addTrackingArea(NSTrackingArea(
            rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        ))
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 340, height: 26)
    }

    override func draw(_ dirtyRect: NSRect) {
        let modes = Mode.allCases
        let count = CGFloat(modes.count)
        let gap: CGFloat = 3
        let totalGap = gap * (count - 1)
        let btnWidth = (bounds.width - totalGap) / count
        let btnHeight = bounds.height

        for (i, mode) in modes.enumerated() {
            let x = CGFloat(i) * (btnWidth + gap)
            let rect = NSRect(x: x, y: 0, width: btnWidth, height: btnHeight)
            let isSelected = mode == selectedMode
            let isHovered = hoveredIndex == i && !isSelected
            let isPressed = pressedIndex == i

            drawGlassButton(in: rect, selected: isSelected, hovered: isHovered, pressed: isPressed)
            drawButtonContent(in: rect, mode: mode, selected: isSelected)
        }
    }

    private func drawGlassButton(in rect: NSRect, selected: Bool, hovered: Bool, pressed: Bool) {
        let radius: CGFloat = 7
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: radius, yRadius: radius)

        if selected {
            // Liquid glass selected — luminous translucent fill
            let topColor = NSColor(calibratedRed: 0.55, green: 0.70, blue: 0.95, alpha: 0.55)
            let bottomColor = NSColor(calibratedRed: 0.40, green: 0.55, blue: 0.85, alpha: 0.45)
            let gradient = NSGradient(starting: topColor, ending: bottomColor)
            gradient?.draw(in: path, angle: 270)

            // Top highlight (gloss)
            let glossRect = NSRect(x: rect.minX + 2, y: rect.midY, width: rect.width - 4, height: rect.height / 2 - 1)
            let glossPath = NSBezierPath(roundedRect: glossRect, xRadius: radius - 1, yRadius: radius - 1)
            NSColor(white: 1.0, alpha: 0.15).setFill()
            glossPath.fill()

            // Border glow
            NSColor(calibratedRed: 0.45, green: 0.60, blue: 0.90, alpha: 0.6).setStroke()
            path.lineWidth = 1.0
            path.stroke()
        } else if pressed {
            NSColor(white: 0.0, alpha: 0.15).setFill()
            path.fill()
            NSColor(white: 0.0, alpha: 0.10).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        } else if hovered {
            // Subtle glass hover
            NSColor(white: 0.0, alpha: 0.06).setFill()
            path.fill()
            NSColor(white: 0.0, alpha: 0.08).setStroke()
            path.lineWidth = 0.5
            path.stroke()
        } else {
            // Idle — nearly invisible, just a hint of glass
            NSColor(white: 0.0, alpha: 0.03).setFill()
            path.fill()
        }
    }

    private func drawButtonContent(in rect: NSRect, mode: Mode, selected: Bool) {
        let textColor = selected
            ? NSColor(calibratedRed: 0.10, green: 0.20, blue: 0.50, alpha: 1.0)
            : NSColor(white: 0.30, alpha: 1.0)

        // Icon
        let iconSize: CGFloat = 11
        if let img = NSImage(systemSymbolName: mode.symbolName, accessibilityDescription: mode.title) {
            let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: selected ? .semibold : .regular)
            let configured = img.withSymbolConfiguration(config) ?? img

            let iconX = rect.minX + 8
            let iconY = rect.midY - iconSize / 2
            let iconRect = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)

            NSGraphicsContext.saveGraphicsState()
            textColor.set()
            configured.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
        }

        // Title
        let font = selected
            ? (NSFont(name: "Lucida Grande Bold", size: 10) ?? NSFont.boldSystemFont(ofSize: 10))
            : (NSFont(name: "Lucida Grande", size: 10) ?? NSFont.systemFont(ofSize: 10))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
        ]
        let str = mode.title as NSString
        let textSize = str.size(withAttributes: attrs)
        let textX = rect.minX + 22
        let textY = rect.midY - textSize.height / 2
        str.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
    }

    // MARK: - Hit testing

    private func modeIndex(at point: NSPoint) -> Int? {
        let count = CGFloat(Mode.allCases.count)
        let gap: CGFloat = 3
        let btnWidth = (bounds.width - gap * (count - 1)) / count

        for i in 0..<Int(count) {
            let x = CGFloat(i) * (btnWidth + gap)
            let rect = NSRect(x: x, y: 0, width: btnWidth, height: bounds.height)
            if rect.contains(point) { return i }
        }
        return nil
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newHover = modeIndex(at: point)
        if newHover != hoveredIndex {
            hoveredIndex = newHover
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoveredIndex = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        pressedIndex = modeIndex(at: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let idx = modeIndex(at: point), idx == pressedIndex, let mode = Mode(rawValue: idx) {
            onModeSelected?(mode)
        }
        pressedIndex = nil
        needsDisplay = true
    }
}
