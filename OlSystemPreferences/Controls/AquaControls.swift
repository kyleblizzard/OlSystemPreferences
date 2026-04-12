import Cocoa

// MARK: - Aqua Color Constants

enum AquaColors {
    // Blue button
    static let blueGradientTop = NSColor(calibratedRed: 0.486, green: 0.757, blue: 1.0, alpha: 1.0)     // #7CC1FF
    static let blueGradientMid = NSColor(calibratedRed: 0.302, green: 0.588, blue: 0.945, alpha: 1.0)    // #4D96F1
    static let blueGradientBottom = NSColor(calibratedRed: 0.106, green: 0.420, blue: 0.816, alpha: 1.0) // #1B6BD0
    static let blueBorder = NSColor(calibratedRed: 0.094, green: 0.337, blue: 0.659, alpha: 1.0)         // #1856A8
    static let bluePressed = NSColor(calibratedRed: 0.075, green: 0.310, blue: 0.620, alpha: 1.0)

    // Gray button
    static let grayGradientTop = NSColor(white: 0.99, alpha: 1.0)
    static let grayGradientMid = NSColor(white: 0.91, alpha: 1.0)
    static let grayGradientBottom = NSColor(white: 0.82, alpha: 1.0)
    static let grayBorder = NSColor(white: 0.53, alpha: 1.0)
    static let grayPressed = NSColor(white: 0.72, alpha: 1.0)

    // Checkbox / Radio
    static let checkGradientTop = NSColor(calibratedRed: 0.420, green: 0.710, blue: 0.957, alpha: 1.0)   // #6BB5F4
    static let checkGradientBottom = NSColor(calibratedRed: 0.125, green: 0.408, blue: 0.800, alpha: 1.0) // #2068CC
    static let checkBorder = NSColor(calibratedRed: 0.094, green: 0.337, blue: 0.659, alpha: 1.0)

    // Unchecked box/radio
    static let uncheckedTop = NSColor(white: 1.0, alpha: 1.0)
    static let uncheckedBottom = NSColor(white: 0.90, alpha: 1.0)
    static let uncheckedBorder = NSColor(white: 0.55, alpha: 1.0)

    // Slider
    static let sliderTrackTop = NSColor(white: 0.72, alpha: 1.0)
    static let sliderTrackBottom = NSColor(white: 0.88, alpha: 1.0)
    static let sliderTrackBorder = NSColor(white: 0.55, alpha: 1.0)
    static let sliderThumbTop = NSColor(white: 0.98, alpha: 1.0)
    static let sliderThumbBottom = NSColor(white: 0.78, alpha: 1.0)
    static let sliderThumbBorder = NSColor(white: 0.47, alpha: 1.0)
    static let sliderTickColor = NSColor(white: 0.45, alpha: 1.0)

    // Filled track (blue portion for sliders like volume/brightness)
    static let sliderFillTop = NSColor(calibratedRed: 0.400, green: 0.650, blue: 0.950, alpha: 1.0)
    static let sliderFillBottom = NSColor(calibratedRed: 0.200, green: 0.450, blue: 0.850, alpha: 1.0)

    // Tab
    static let tabActiveTop = NSColor(white: 0.97, alpha: 1.0)
    static let tabActiveBottom = NSColor(white: 0.88, alpha: 1.0)
    static let tabInactiveTop = NSColor(white: 0.82, alpha: 1.0)
    static let tabInactiveBottom = NSColor(white: 0.72, alpha: 1.0)
    static let tabBorder = NSColor(white: 0.50, alpha: 1.0)
    static let tabContentBackground = NSColor(white: 0.93, alpha: 1.0)

    // Popup button
    static let popupArrowColor = NSColor(white: 0.25, alpha: 1.0)

    // Segmented control
    static let segmentSelectedTop = NSColor(calibratedRed: 0.420, green: 0.680, blue: 0.960, alpha: 1.0)
    static let segmentSelectedBottom = NSColor(calibratedRed: 0.180, green: 0.440, blue: 0.820, alpha: 1.0)

    // Shared
    static let glossHighlight = NSColor(white: 1.0, alpha: 0.55)
    static let innerShadow = NSColor(white: 0.0, alpha: 0.10)
    static let textColor = NSColor(white: 0.15, alpha: 1.0)
    static let disabledAlpha: CGFloat = 0.5
}


// MARK: - AquaButton

/// Glossy Aqua-style push button with blue (default) or gray (regular) appearance.
class AquaButton: NSView {

    var title: String = "" { didSet { needsDisplay = true } }
    var isDefault: Bool = false { didSet { needsDisplay = true } }
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }
    var target: AnyObject?
    var action: Selector?
    var font: NSFont = SnowLeopardFonts.label(size: 12)

    private var isPressed = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        return NSSize(width: max(textSize.width + 32, 80), height: 22)
    }

    convenience init(title: String, isDefault: Bool = false) {
        self.init(frame: .zero)
        self.title = title
        self.isDefault = isDefault
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)

        // Background gradient
        let topColor: NSColor
        let bottomColor: NSColor
        let borderColor: NSColor

        if isPressed {
            if isDefault {
                topColor = AquaColors.bluePressed
                bottomColor = AquaColors.blueGradientBottom.blended(withFraction: 0.2, of: .black) ?? AquaColors.blueGradientBottom
                borderColor = AquaColors.blueBorder
            } else {
                topColor = AquaColors.grayPressed
                bottomColor = AquaColors.grayGradientBottom.blended(withFraction: 0.15, of: .black) ?? AquaColors.grayGradientBottom
                borderColor = AquaColors.grayBorder
            }
        } else if isDefault {
            topColor = AquaColors.blueGradientTop
            bottomColor = AquaColors.blueGradientBottom
            borderColor = AquaColors.blueBorder
        } else {
            topColor = AquaColors.grayGradientTop
            bottomColor = AquaColors.grayGradientBottom
            borderColor = AquaColors.grayBorder
        }

        // Main gradient
        let gradient = NSGradient(colors: [topColor, bottomColor])
        gradient?.draw(in: path, angle: 270)

        // Glossy highlight (top half)
        let glossRect = NSRect(x: rect.minX + 1, y: rect.midY, width: rect.width - 2, height: rect.height / 2 - 1)
        let glossPath = NSBezierPath(roundedRect: glossRect, xRadius: 3, yRadius: 3)
        let glossGradient = NSGradient(starting: AquaColors.glossHighlight, ending: NSColor(white: 1.0, alpha: 0.0))
        glossGradient?.draw(in: glossPath, angle: 270)

        // Border
        borderColor.setStroke()
        path.lineWidth = 1.0
        path.stroke()

        // Title
        let textColor: NSColor = isDefault ? .white : AquaColors.textColor
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = isDefault ? NSColor(white: 0.0, alpha: 0.3) : NSColor(white: 1.0, alpha: 0.5)
        shadow.shadowBlurRadius = 0

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .shadow: shadow,
        ]
        let textSize = (title as NSString).size(withAttributes: attrs)
        let textPoint = NSPoint(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2
        )
        (title as NSString).draw(at: textPoint, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, isPressed else { return }
        isPressed = false
        needsDisplay = true
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc), let action = action {
            _ = target?.perform(action, with: self)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let wasPressed = isPressed
        isPressed = bounds.contains(loc)
        if isPressed != wasPressed { needsDisplay = true }
    }
}


// MARK: - AquaCheckbox

/// Gel-style checkbox with glossy blue checked state and white checkmark.
class AquaCheckbox: NSView {

    var title: String = "" { didSet { needsDisplay = true } }
    var isChecked: Bool = false { didSet { needsDisplay = true } }
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }
    var target: AnyObject?
    var action: Selector?
    var font: NSFont = SnowLeopardFonts.label(size: 11)

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        return NSSize(width: 18 + 6 + textSize.width, height: max(18, textSize.height))
    }

    convenience init(title: String, isChecked: Bool = false) {
        self.init(frame: .zero)
        self.title = title
        self.isChecked = isChecked
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let boxSize: CGFloat = 14
        let boxY = (bounds.height - boxSize) / 2
        let boxRect = NSRect(x: 1, y: boxY, width: boxSize, height: boxSize)
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 3, yRadius: 3)

        if isChecked {
            // Blue gradient
            let gradient = NSGradient(starting: AquaColors.checkGradientTop, ending: AquaColors.checkGradientBottom)
            gradient?.draw(in: boxPath, angle: 270)
            AquaColors.checkBorder.setStroke()
            boxPath.lineWidth = 1.0
            boxPath.stroke()

            // Glossy highlight top half
            let glossRect = NSRect(x: boxRect.minX + 1, y: boxRect.midY, width: boxRect.width - 2, height: boxRect.height / 2 - 1)
            let glossPath = NSBezierPath(roundedRect: glossRect, xRadius: 2, yRadius: 2)
            NSColor(white: 1.0, alpha: 0.35).setFill()
            glossPath.fill()

            // Checkmark
            let check = NSBezierPath()
            let cx = boxRect.midX
            let cy = boxRect.midY
            check.move(to: NSPoint(x: cx - 3.5, y: cy - 0.5))
            check.line(to: NSPoint(x: cx - 1, y: cy - 3))
            check.line(to: NSPoint(x: cx + 4, y: cy + 3))
            NSColor.white.setStroke()
            check.lineWidth = 2.0
            check.lineCapStyle = .round
            check.lineJoinStyle = .round
            check.stroke()
        } else {
            // Unchecked: white/light gray gradient
            let gradient = NSGradient(starting: AquaColors.uncheckedTop, ending: AquaColors.uncheckedBottom)
            gradient?.draw(in: boxPath, angle: 270)
            AquaColors.uncheckedBorder.setStroke()
            boxPath.lineWidth = 1.0
            boxPath.stroke()

            // Inner shadow at top
            let innerPath = NSBezierPath(roundedRect: boxRect.insetBy(dx: 1, dy: 1), xRadius: 2, yRadius: 2)
            let innerGradient = NSGradient(starting: AquaColors.innerShadow, ending: .clear)
            innerGradient?.draw(in: innerPath, angle: 270)
        }

        // Title
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: AquaColors.textColor,
        ]
        let textSize = (title as NSString).size(withAttributes: attrs)
        let textPoint = NSPoint(x: boxSize + 7, y: (bounds.height - textSize.height) / 2)
        (title as NSString).draw(at: textPoint, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isChecked.toggle()
        if let action = action {
            _ = target?.perform(action, with: self)
        }
    }
}


// MARK: - AquaRadioButton

/// Classic circular radio button with blue dot when selected.
class AquaRadioButton: NSView {

    var title: String = "" { didSet { needsDisplay = true } }
    var isSelected: Bool = false { didSet { needsDisplay = true } }
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }
    var target: AnyObject?
    var action: Selector?
    var font: NSFont = SnowLeopardFonts.label(size: 11)


    /// Group tag — all radios with same groupTag auto-deselect siblings
    var groupTag: Int = 0

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
        let textSize = (title as NSString).size(withAttributes: [.font: font])
        return NSSize(width: 16 + 6 + textSize.width, height: max(16, textSize.height))
    }

    convenience init(title: String, isSelected: Bool = false) {
        self.init(frame: .zero)
        self.title = title
        self.isSelected = isSelected
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let circleSize: CGFloat = 14
        let circleY = (bounds.height - circleSize) / 2
        let circleRect = NSRect(x: 1, y: circleY, width: circleSize, height: circleSize)
        let circlePath = NSBezierPath(ovalIn: circleRect)

        if isSelected {
            let gradient = NSGradient(starting: AquaColors.checkGradientTop, ending: AquaColors.checkGradientBottom)
            gradient?.draw(in: circlePath, angle: 270)
            AquaColors.checkBorder.setStroke()
            circlePath.lineWidth = 1.0
            circlePath.stroke()

            // Gloss
            let glossRect = NSRect(x: circleRect.minX + 2, y: circleRect.midY, width: circleRect.width - 4, height: circleRect.height / 2 - 2)
            let glossPath = NSBezierPath(ovalIn: glossRect)
            NSColor(white: 1.0, alpha: 0.35).setFill()
            glossPath.fill()

            // White center dot
            let dotSize: CGFloat = 5
            let dotRect = NSRect(
                x: circleRect.midX - dotSize / 2,
                y: circleRect.midY - dotSize / 2,
                width: dotSize, height: dotSize
            )
            NSColor.white.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
        } else {
            let gradient = NSGradient(starting: AquaColors.uncheckedTop, ending: AquaColors.uncheckedBottom)
            gradient?.draw(in: circlePath, angle: 270)
            AquaColors.uncheckedBorder.setStroke()
            circlePath.lineWidth = 1.0
            circlePath.stroke()

            // Inner shadow
            let innerRect = circleRect.insetBy(dx: 2, dy: 2)
            let innerGradient = NSGradient(starting: AquaColors.innerShadow, ending: .clear)
            innerGradient?.draw(in: NSBezierPath(ovalIn: innerRect), angle: 270)
        }

        // Title
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: AquaColors.textColor,
        ]
        let textSize = (title as NSString).size(withAttributes: attrs)
        let textPoint = NSPoint(x: circleSize + 7, y: (bounds.height - textSize.height) / 2)
        (title as NSString).draw(at: textPoint, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        // Deselect siblings with same groupTag
        if let parent = superview {
            for subview in parent.subviews {
                if let radio = subview as? AquaRadioButton, radio !== self, radio.groupTag == groupTag {
                    radio.isSelected = false
                }
            }
        }
        isSelected = true
        if let action = action {
            _ = target?.perform(action, with: self)
        }
    }
}


// MARK: - AquaSlider

/// Recessed groove track with round glossy thumb. Supports continuous and tick-mark modes.
class AquaSlider: NSView {

    var minValue: Double = 0 { didSet { needsDisplay = true } }
    var maxValue: Double = 1 { didSet { needsDisplay = true } }
    var doubleValue: Double = 0.5 { didSet { needsDisplay = true } }
    var numberOfTickMarks: Int = 0 { didSet { needsDisplay = true } }
    var allowsTickMarkValuesOnly: Bool = true
    var isContinuous: Bool = true
    var showsFillColor: Bool = false { didSet { needsDisplay = true } }
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }
    var target: AnyObject?
    var action: Selector?


    /// Labels shown at min/max ends (e.g., speaker icons or "Slow"/"Fast")
    var minLabel: String? { didSet { needsDisplay = true } }
    var maxLabel: String? { didSet { needsDisplay = true } }

    private var isDragging = false
    private let thumbSize: CGFloat = 18
    private let trackHeight: CGFloat = 5

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
        let h: CGFloat = numberOfTickMarks > 0 ? 28 : 22
        return NSSize(width: 200, height: h)
    }

    convenience init(minValue: Double = 0, maxValue: Double = 1, value: Double = 0.5) {
        self.init(frame: .zero)
        self.minValue = minValue
        self.maxValue = maxValue
        self.doubleValue = value
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    private var trackRect: NSRect {
        let labelInset: CGFloat = (minLabel != nil || maxLabel != nil) ? 0 : 0
        let y = (bounds.height - trackHeight) / 2
        return NSRect(x: thumbSize / 2 + labelInset, y: y, width: bounds.width - thumbSize - labelInset * 2, height: trackHeight)
    }

    private var normalizedValue: CGFloat {
        let range = maxValue - minValue
        guard range > 0 else { return 0 }
        return CGFloat((doubleValue - minValue) / range)
    }

    private var thumbCenter: CGFloat {
        let track = trackRect
        return track.minX + track.width * normalizedValue
    }

    override func draw(_ dirtyRect: NSRect) {
        let track = trackRect

        // Track groove
        let trackPath = NSBezierPath(roundedRect: track, xRadius: trackHeight / 2, yRadius: trackHeight / 2)

        // Track gradient (recessed look)
        let trackGradient = NSGradient(starting: AquaColors.sliderTrackTop, ending: AquaColors.sliderTrackBottom)
        trackGradient?.draw(in: trackPath, angle: 270)
        AquaColors.sliderTrackBorder.setStroke()
        trackPath.lineWidth = 0.5
        trackPath.stroke()

        // Blue filled portion (optional)
        if showsFillColor {
            let fillWidth = track.width * normalizedValue
            if fillWidth > 0 {
                let fillRect = NSRect(x: track.minX, y: track.minY, width: fillWidth, height: track.height)
                let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: trackHeight / 2, yRadius: trackHeight / 2)
                let fillGradient = NSGradient(starting: AquaColors.sliderFillTop, ending: AquaColors.sliderFillBottom)
                fillGradient?.draw(in: fillPath, angle: 270)
            }
        }

        // Tick marks
        if numberOfTickMarks > 1 {
            AquaColors.sliderTickColor.setStroke()
            for i in 0..<numberOfTickMarks {
                let frac = CGFloat(i) / CGFloat(numberOfTickMarks - 1)
                let x = track.minX + track.width * frac
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: x, y: track.minY - 4))
                tickPath.line(to: NSPoint(x: x, y: track.minY - 1))
                tickPath.lineWidth = 1.0
                tickPath.stroke()
            }
        }

        // Thumb
        let thumbX = thumbCenter - thumbSize / 2
        let thumbY = (bounds.height - thumbSize) / 2
        let thumbRect = NSRect(x: thumbX, y: thumbY, width: thumbSize, height: thumbSize)
        let thumbPath = NSBezierPath(ovalIn: thumbRect)

        // Thumb shadow
        let shadowRect = thumbRect.offsetBy(dx: 0, dy: -1)
        NSColor(white: 0.0, alpha: 0.15).setFill()
        NSBezierPath(ovalIn: shadowRect.insetBy(dx: -1, dy: -1)).fill()

        // Thumb gradient
        let thumbGradient = NSGradient(starting: AquaColors.sliderThumbTop, ending: AquaColors.sliderThumbBottom)
        thumbGradient?.draw(in: thumbPath, angle: 270)

        // Thumb gloss
        let glossRect = NSRect(x: thumbRect.minX + 2, y: thumbRect.midY, width: thumbRect.width - 4, height: thumbRect.height / 2 - 2)
        let glossPath = NSBezierPath(ovalIn: glossRect)
        NSColor(white: 1.0, alpha: 0.5).setFill()
        glossPath.fill()

        // Thumb border
        AquaColors.sliderThumbBorder.setStroke()
        thumbPath.lineWidth = 0.75
        thumbPath.stroke()

        // Min/Max labels
        let labelFont = SnowLeopardFonts.label(size: 9)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: AquaColors.textColor,
        ]
        if let minLabel = minLabel {
            let size = (minLabel as NSString).size(withAttributes: labelAttrs)
            (minLabel as NSString).draw(at: NSPoint(x: track.minX - size.width - 4, y: (bounds.height - size.height) / 2), withAttributes: labelAttrs)
        }
        if let maxLabel = maxLabel {
            let size = (maxLabel as NSString).size(withAttributes: labelAttrs)
            (maxLabel as NSString).draw(at: NSPoint(x: track.maxX + 4, y: (bounds.height - size.height) / 2), withAttributes: labelAttrs)
        }
    }

    private func valueForX(_ x: CGFloat) -> Double {
        let track = trackRect
        let clamped = max(track.minX, min(x, track.maxX))
        let frac = (clamped - track.minX) / track.width
        var value = minValue + Double(frac) * (maxValue - minValue)

        // Snap to tick marks
        if numberOfTickMarks > 1 && allowsTickMarkValuesOnly {
            let step = (maxValue - minValue) / Double(numberOfTickMarks - 1)
            value = (value / step).rounded() * step
        }

        return max(minValue, min(value, maxValue))
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        let loc = convert(event.locationInWindow, from: nil)
        isDragging = true
        doubleValue = valueForX(loc.x)
        if let action = action {
            _ = target?.perform(action, with: self)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, isDragging else { return }
        let loc = convert(event.locationInWindow, from: nil)
        doubleValue = valueForX(loc.x)
        if isContinuous, let action = action {
            _ = target?.perform(action, with: self)
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, isDragging else { return }
        isDragging = false
        if let action = action {
            _ = target?.perform(action, with: self)
        }
    }
}


// MARK: - AquaPopUpButton

/// Drop-down button with Aqua gradient and arrows.
class AquaPopUpButton: NSView {

    var items: [String] = [] { didSet { needsDisplay = true } }
    var selectedIndex: Int = 0 { didSet { needsDisplay = true } }
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }
    var target: AnyObject?
    var action: Selector?
    var font: NSFont = SnowLeopardFonts.label(size: 11)


    var selectedTitle: String {
        guard selectedIndex >= 0, selectedIndex < items.count else { return "" }
        return items[selectedIndex]
    }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
        var maxWidth: CGFloat = 60
        for item in items {
            let w = (item as NSString).size(withAttributes: [.font: font]).width
            if w > maxWidth { maxWidth = w }
        }
        return NSSize(width: maxWidth + 36, height: 22)
    }

    convenience init(items: [String], selectedIndex: Int = 0) {
        self.init(frame: .zero)
        self.items = items
        self.selectedIndex = selectedIndex
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)

        // Gradient (gray button style)
        let gradient = NSGradient(starting: AquaColors.grayGradientTop, ending: AquaColors.grayGradientBottom)
        gradient?.draw(in: path, angle: 270)

        // Gloss
        let glossRect = NSRect(x: rect.minX + 1, y: rect.midY, width: rect.width - 2, height: rect.height / 2 - 1)
        let glossPath = NSBezierPath(roundedRect: glossRect, xRadius: 3, yRadius: 3)
        NSColor(white: 1.0, alpha: 0.4).setFill()
        glossPath.fill()

        // Border
        AquaColors.grayBorder.setStroke()
        path.lineWidth = 1.0
        path.stroke()

        // Arrows on right side
        let arrowX = rect.maxX - 16
        let arrowY = rect.midY
        let arrowPath = NSBezierPath()
        // Up arrow
        arrowPath.move(to: NSPoint(x: arrowX - 3, y: arrowY + 1))
        arrowPath.line(to: NSPoint(x: arrowX, y: arrowY + 4))
        arrowPath.line(to: NSPoint(x: arrowX + 3, y: arrowY + 1))
        // Down arrow
        arrowPath.move(to: NSPoint(x: arrowX - 3, y: arrowY - 1))
        arrowPath.line(to: NSPoint(x: arrowX, y: arrowY - 4))
        arrowPath.line(to: NSPoint(x: arrowX + 3, y: arrowY - 1))
        AquaColors.popupArrowColor.setStroke()
        arrowPath.lineWidth = 1.5
        arrowPath.lineCapStyle = .round
        arrowPath.stroke()

        // Text
        let title = selectedTitle
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: AquaColors.textColor,
        ]
        let textSize = (title as NSString).size(withAttributes: attrs)
        let textPoint = NSPoint(x: 8, y: (bounds.height - textSize.height) / 2)
        (title as NSString).draw(at: textPoint, withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, !items.isEmpty else { return }

        // Build NSMenu and show
        let menu = NSMenu()
        for (i, item) in items.enumerated() {
            let menuItem = NSMenuItem(title: item, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = i
            if i == selectedIndex { menuItem.state = .on }
            menu.addItem(menuItem)
        }

        let loc = NSPoint(x: 0, y: bounds.height)
        menu.popUp(positioning: menu.item(at: selectedIndex), at: loc, in: self)
    }

    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        selectedIndex = sender.tag
        if let action = action {
            _ = target?.perform(action, with: self)
        }
    }
}


// MARK: - AquaTabView

/// Rounded Aqua-style tab view with gradient tabs drawn from scratch.
class AquaTabView: NSView {

    struct Tab {
        let title: String
        let view: NSView
    }

    private(set) var tabs: [Tab] = []
    private(set) var selectedIndex: Int = 0

    var onTabChanged: ((Int) -> Void)?
    var font: NSFont = SnowLeopardFonts.label(size: 11)

    private let tabBarHeight: CGFloat = 24
    private let contentContainer = NSView()

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentContainer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func addTab(title: String, view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = tabs.count != selectedIndex
        tabs.append(Tab(title: title, view: view))
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])
        needsDisplay = true
        needsLayout = true
    }

    func selectTab(at index: Int) {
        guard index >= 0, index < tabs.count, index != selectedIndex else { return }
        tabs[selectedIndex].view.isHidden = true
        selectedIndex = index
        tabs[selectedIndex].view.isHidden = false
        needsDisplay = true
        onTabChanged?(index)
    }

    override func layout() {
        super.layout()
        contentContainer.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - tabBarHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !tabs.isEmpty else { return }

        let tabY = bounds.height - tabBarHeight
        // Content area background with rounded bottom corners
        let contentRect = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - tabBarHeight + 2)
        let contentPath = NSBezierPath(roundedRect: contentRect, xRadius: 4, yRadius: 4)
        AquaColors.tabContentBackground.setFill()
        contentPath.fill()
        AquaColors.tabBorder.setStroke()
        contentPath.lineWidth = 1.0
        contentPath.stroke()

        // Draw each tab
        let tabCount = tabs.count
        let totalPadding: CGFloat = 40
        let availableWidth = bounds.width - totalPadding
        let tabWidth = min(availableWidth / CGFloat(tabCount), 120)
        let totalTabWidth = tabWidth * CGFloat(tabCount)
        let startX = (bounds.width - totalTabWidth) / 2

        for i in 0..<tabCount {
            let x = startX + tabWidth * CGFloat(i)
            let isActive = i == selectedIndex

            let tabRect = NSRect(x: x, y: tabY, width: tabWidth, height: tabBarHeight)

            // Tab shape (rounded top)
            let tabPath = NSBezierPath()
            let radius: CGFloat = 5
            tabPath.move(to: NSPoint(x: tabRect.minX, y: tabRect.minY))
            tabPath.line(to: NSPoint(x: tabRect.minX, y: tabRect.maxY - radius))
            tabPath.curve(to: NSPoint(x: tabRect.minX + radius, y: tabRect.maxY),
                         controlPoint1: NSPoint(x: tabRect.minX, y: tabRect.maxY),
                         controlPoint2: NSPoint(x: tabRect.minX, y: tabRect.maxY))
            tabPath.line(to: NSPoint(x: tabRect.maxX - radius, y: tabRect.maxY))
            tabPath.curve(to: NSPoint(x: tabRect.maxX, y: tabRect.maxY - radius),
                         controlPoint1: NSPoint(x: tabRect.maxX, y: tabRect.maxY),
                         controlPoint2: NSPoint(x: tabRect.maxX, y: tabRect.maxY))
            tabPath.line(to: NSPoint(x: tabRect.maxX, y: tabRect.minY))
            tabPath.close()

            if isActive {
                let gradient = NSGradient(starting: AquaColors.tabActiveTop, ending: AquaColors.tabActiveBottom)
                gradient?.draw(in: tabPath, angle: 270)
            } else {
                let gradient = NSGradient(starting: AquaColors.tabInactiveTop, ending: AquaColors.tabInactiveBottom)
                gradient?.draw(in: tabPath, angle: 270)
            }

            AquaColors.tabBorder.setStroke()
            tabPath.lineWidth = 1.0
            tabPath.stroke()

            // If active, cover the bottom border
            if isActive {
                AquaColors.tabContentBackground.setFill()
                NSRect(x: tabRect.minX + 1, y: tabRect.minY, width: tabRect.width - 2, height: 2).fill()
            }

            // Tab title
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: AquaColors.textColor,
            ]
            let textSize = (tabs[i].title as NSString).size(withAttributes: attrs)
            let textPoint = NSPoint(
                x: tabRect.midX - textSize.width / 2,
                y: tabRect.midY - textSize.height / 2 + 1
            )
            (tabs[i].title as NSString).draw(at: textPoint, withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        let tabY = bounds.height - tabBarHeight

        guard loc.y >= tabY else { return }

        let tabCount = tabs.count
        let totalPadding: CGFloat = 40
        let availableWidth = bounds.width - totalPadding
        let tabWidth = min(availableWidth / CGFloat(tabCount), 120)
        let totalTabWidth = tabWidth * CGFloat(tabCount)
        let startX = (bounds.width - totalTabWidth) / 2

        let clickedTab = Int((loc.x - startX) / tabWidth)
        if clickedTab >= 0 && clickedTab < tabCount {
            selectTab(at: clickedTab)
        }
    }
}


// MARK: - AquaSegmentedControl

/// Connected segments with Aqua gradient — blue for selected, gray for unselected.
class AquaSegmentedControl: NSView {

    var segments: [String] = [] { didSet { needsDisplay = true } }
    var selectedSegment: Int = 0 { didSet { needsDisplay = true } }
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }
    var target: AnyObject?
    var action: Selector?
    var font: NSFont = SnowLeopardFonts.label(size: 11)


    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize {
        var totalWidth: CGFloat = 0
        for seg in segments {
            totalWidth += (seg as NSString).size(withAttributes: [.font: font]).width + 20
        }
        return NSSize(width: max(totalWidth, 60), height: 22)
    }

    convenience init(segments: [String], selectedSegment: Int = 0) {
        self.init(frame: .zero)
        self.segments = segments
        self.selectedSegment = selectedSegment
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard !segments.isEmpty else { return }

        let rect = bounds.insetBy(dx: 1, dy: 1)
        let segCount = segments.count
        let segWidth = rect.width / CGFloat(segCount)

        for i in 0..<segCount {
            let segRect = NSRect(x: rect.minX + segWidth * CGFloat(i), y: rect.minY, width: segWidth, height: rect.height)
            let isSelected = i == selectedSegment
            let isFirst = i == 0
            let isLast = i == segCount - 1

            // Create rounded rect for first/last, square for middle
            let path: NSBezierPath
            if isFirst && isLast {
                path = NSBezierPath(roundedRect: segRect, xRadius: 4, yRadius: 4)
            } else if isFirst {
                path = makeLeftRoundedPath(segRect, radius: 4)
            } else if isLast {
                path = makeRightRoundedPath(segRect, radius: 4)
            } else {
                path = NSBezierPath(rect: segRect)
            }

            // Fill
            if isSelected {
                let gradient = NSGradient(starting: AquaColors.segmentSelectedTop, ending: AquaColors.segmentSelectedBottom)
                gradient?.draw(in: path, angle: 270)
            } else {
                let gradient = NSGradient(starting: AquaColors.grayGradientTop, ending: AquaColors.grayGradientBottom)
                gradient?.draw(in: path, angle: 270)
            }

            // Gloss
            let glossRect = NSRect(x: segRect.minX + 1, y: segRect.midY, width: segRect.width - 2, height: segRect.height / 2 - 1)
            NSColor(white: 1.0, alpha: isSelected ? 0.25 : 0.4).setFill()
            NSBezierPath(rect: glossRect).fill()

            // Border
            AquaColors.grayBorder.setStroke()
            path.lineWidth = 1.0
            path.stroke()

            // Title
            let textColor: NSColor = isSelected ? .white : AquaColors.textColor
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowColor = isSelected ? NSColor(white: 0.0, alpha: 0.3) : NSColor(white: 1.0, alpha: 0.5)
            shadow.shadowBlurRadius = 0

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor,
                .shadow: shadow,
            ]
            let textSize = (segments[i] as NSString).size(withAttributes: attrs)
            let textPoint = NSPoint(
                x: segRect.midX - textSize.width / 2,
                y: segRect.midY - textSize.height / 2
            )
            (segments[i] as NSString).draw(at: textPoint, withAttributes: attrs)
        }
    }

    private func makeLeftRoundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX + radius, y: rect.minY))
        path.curve(to: NSPoint(x: rect.minX, y: rect.minY + radius),
                   controlPoint1: NSPoint(x: rect.minX, y: rect.minY),
                   controlPoint2: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY - radius))
        path.curve(to: NSPoint(x: rect.minX + radius, y: rect.maxY),
                   controlPoint1: NSPoint(x: rect.minX, y: rect.maxY),
                   controlPoint2: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        path.close()
        return path
    }

    private func makeRightRoundedPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
        path.curve(to: NSPoint(x: rect.maxX, y: rect.minY + radius),
                   controlPoint1: NSPoint(x: rect.maxX, y: rect.minY),
                   controlPoint2: NSPoint(x: rect.maxX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - radius))
        path.curve(to: NSPoint(x: rect.maxX - radius, y: rect.maxY),
                   controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY),
                   controlPoint2: NSPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.close()
        return path
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, !segments.isEmpty else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let segWidth = rect.width / CGFloat(segments.count)
        let clicked = Int((loc.x - rect.minX) / segWidth)
        if clicked >= 0 && clicked < segments.count {
            selectedSegment = clicked
            if let action = action {
                _ = target?.perform(action, with: self)
            }
        }
    }
}


// MARK: - AquaTextField

/// Text field with Aqua-style inset border and white background.
class AquaTextField: NSTextField {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        font = SnowLeopardFonts.label(size: 11)
        textColor = AquaColors.textColor
        isBordered = true
        isBezeled = true
        bezelStyle = .squareBezel
        drawsBackground = true
        backgroundColor = .white
        focusRingType = .exterior
        translatesAutoresizingMaskIntoConstraints = false
    }
}


// MARK: - AquaProgressBar

/// Striped Aqua progress bar (barber pole animation for indeterminate, solid blue for determinate).
class AquaProgressBar: NSView {

    var doubleValue: Double = 0.5 { didSet { needsDisplay = true } }
    var minValue: Double = 0
    var maxValue: Double = 1.0
    var isIndeterminate: Bool = false {
        didSet {
            if isIndeterminate { startAnimation() } else { stopAnimation() }
            needsDisplay = true
        }
    }

    private var stripeOffset: CGFloat = 0
    private var animationTimer: Timer?

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 16)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.defaultHigh, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)

        // Track
        let trackGradient = NSGradient(starting: AquaColors.sliderTrackTop, ending: AquaColors.sliderTrackBottom)
        trackGradient?.draw(in: path, angle: 270)
        AquaColors.sliderTrackBorder.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Fill
        let range = maxValue - minValue
        let frac = range > 0 ? CGFloat((doubleValue - minValue) / range) : 0
        let fillWidth = isIndeterminate ? rect.width : rect.width * frac

        if fillWidth > 0 {
            let fillRect = NSRect(x: rect.minX, y: rect.minY, width: fillWidth, height: rect.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: rect.height / 2, yRadius: rect.height / 2)

            let fillGradient = NSGradient(starting: AquaColors.sliderFillTop, ending: AquaColors.sliderFillBottom)
            fillGradient?.draw(in: fillPath, angle: 270)

            // Barber pole stripes for indeterminate
            if isIndeterminate {
                NSGraphicsContext.saveGraphicsState()
                fillPath.setClip()
                let stripeWidth: CGFloat = 12
                NSColor(white: 1.0, alpha: 0.2).setFill()
                var x = rect.minX + stripeOffset - stripeWidth * 2
                while x < rect.maxX + stripeWidth {
                    let stripe = NSBezierPath()
                    stripe.move(to: NSPoint(x: x, y: rect.minY))
                    stripe.line(to: NSPoint(x: x + stripeWidth, y: rect.maxY))
                    stripe.line(to: NSPoint(x: x + stripeWidth * 0.6, y: rect.maxY))
                    stripe.line(to: NSPoint(x: x - stripeWidth * 0.4, y: rect.minY))
                    stripe.close()
                    stripe.fill()
                    x += stripeWidth * 1.5
                }
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    func startAnimation() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.stripeOffset += 1
            if self.stripeOffset > 18 { self.stripeOffset = 0 }
            self.needsDisplay = true
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    override func removeFromSuperview() {
        stopAnimation()
        super.removeFromSuperview()
    }
}


// MARK: - AquaHelpButton

/// Purple circle help button with white "?" — matches Snow Leopard's pane help buttons.
/// Visible in Dock, Appearance, Desktop & Screen Saver, and Exposé & Spaces panes.
class AquaHelpButton: NSView {

    var target: AnyObject?
    var action: Selector?
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }

    private var isPressed = false

    /// The button draws at a fixed 20x20 size (matching Snow Leopard's help button diameter)
    override var intrinsicContentSize: NSSize { NSSize(width: 20, height: 20) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // Center a 20x20 circle in whatever bounds we have
        let size: CGFloat = min(bounds.width, bounds.height)
        let circleRect = NSRect(
            x: bounds.midX - size / 2 + 0.5,
            y: bounds.midY - size / 2 + 0.5,
            width: size - 1,
            height: size - 1
        )
        let circlePath = NSBezierPath(ovalIn: circleRect)

        // Purple/violet gradient — Snow Leopard's help button was a muted purple
        let topColor: NSColor
        let bottomColor: NSColor
        if isPressed {
            topColor = NSColor(calibratedRed: 0.45, green: 0.35, blue: 0.65, alpha: 1.0)
            bottomColor = NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.50, alpha: 1.0)
        } else {
            topColor = NSColor(calibratedRed: 0.60, green: 0.50, blue: 0.78, alpha: 1.0)
            bottomColor = NSColor(calibratedRed: 0.40, green: 0.30, blue: 0.60, alpha: 1.0)
        }

        let gradient = NSGradient(starting: topColor, ending: bottomColor)
        gradient?.draw(in: circlePath, angle: 270)

        // Glossy highlight on upper half
        NSGraphicsContext.saveGraphicsState()
        circlePath.addClip()
        let glossRect = NSRect(x: circleRect.minX, y: circleRect.midY,
                                width: circleRect.width, height: circleRect.height / 2)
        let glossPath = NSBezierPath(ovalIn: glossRect.insetBy(dx: 2, dy: -2))
        let glossGradient = NSGradient(starting: NSColor(white: 1.0, alpha: 0.45),
                                        ending: NSColor(white: 1.0, alpha: 0.0))
        glossGradient?.draw(in: glossPath, angle: 270)
        NSGraphicsContext.restoreGraphicsState()

        // Border
        let borderColor = NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.50, alpha: 0.8)
        borderColor.setStroke()
        circlePath.lineWidth = 1.0
        circlePath.stroke()

        // "?" character centered in the circle
        let questionFont = NSFont(name: "Lucida Grande Bold", size: size * 0.60)
            ?? NSFont.boldSystemFont(ofSize: size * 0.60)
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -0.5)
        shadow.shadowColor = NSColor(white: 0.0, alpha: 0.35)
        shadow.shadowBlurRadius = 0

        let attrs: [NSAttributedString.Key: Any] = [
            .font: questionFont,
            .foregroundColor: NSColor.white,
            .shadow: shadow,
        ]
        let qStr = "?" as NSString
        let qSize = qStr.size(withAttributes: attrs)
        let qPoint = NSPoint(
            x: circleRect.midX - qSize.width / 2,
            y: circleRect.midY - qSize.height / 2 - 0.5
        )
        qStr.draw(at: qPoint, withAttributes: attrs)
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, isPressed else { return }
        isPressed = false
        needsDisplay = true
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc), let action = action {
            _ = target?.perform(action, with: self)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let loc = convert(event.locationInWindow, from: nil)
        let was = isPressed
        isPressed = bounds.contains(loc)
        if isPressed != was { needsDisplay = true }
    }
}


// MARK: - AquaStepper

/// Up/down arrow stepper control matching Snow Leopard Aqua style.
/// Visible in the Appearance pane (Number of recent items: 10 Applications).
class AquaStepper: NSView {

    /// Current value managed by the stepper
    var value: Int = 0 { didSet { needsDisplay = true } }
    var minValue: Int = 0
    var maxValue: Int = 100
    var increment: Int = 1
    var isEnabled: Bool = true { didSet { needsDisplay = true; alphaValue = isEnabled ? 1.0 : AquaColors.disabledAlpha } }

    /// Called when the value changes — passes the new value
    var onValueChanged: ((Int) -> Void)?

    var target: AnyObject?
    var action: Selector?

    private var pressedSegment: Int? = nil  // 0 = down (bottom), 1 = up (top)

    override var intrinsicContentSize: NSSize { NSSize(width: 15, height: 22) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        setContentHuggingPriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let midY = rect.midY
        let radius: CGFloat = 2.5

        // Full outline
        let fullPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        // Top half (up button)
        let topRect = NSRect(x: rect.minX, y: midY, width: rect.width, height: rect.height / 2)
        drawStepperSegment(in: topRect, pressed: pressedSegment == 1, clipPath: fullPath, isTop: true)

        // Bottom half (down button)
        let bottomRect = NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2)
        drawStepperSegment(in: bottomRect, pressed: pressedSegment == 0, clipPath: fullPath, isTop: false)

        // Border
        AquaColors.grayBorder.setStroke()
        fullPath.lineWidth = 1.0
        fullPath.stroke()

        // Divider line
        AquaColors.grayBorder.setStroke()
        let divider = NSBezierPath()
        divider.move(to: NSPoint(x: rect.minX, y: midY))
        divider.line(to: NSPoint(x: rect.maxX, y: midY))
        divider.lineWidth = 0.5
        divider.stroke()

        // Up arrow (top segment)
        let upArrowColor = (isEnabled && value < maxValue) ? AquaColors.popupArrowColor : AquaColors.popupArrowColor.withAlphaComponent(0.35)
        drawArrow(in: topRect, pointingUp: true, color: upArrowColor)

        // Down arrow (bottom segment)
        let downArrowColor = (isEnabled && value > minValue) ? AquaColors.popupArrowColor : AquaColors.popupArrowColor.withAlphaComponent(0.35)
        drawArrow(in: bottomRect, pointingUp: false, color: downArrowColor)
    }

    private func drawStepperSegment(in rect: NSRect, pressed: Bool, clipPath: NSBezierPath, isTop: Bool) {
        NSGraphicsContext.saveGraphicsState()
        clipPath.addClip()

        let top = pressed ? AquaColors.grayPressed : AquaColors.grayGradientTop
        let bottom = pressed ? AquaColors.grayGradientBottom.blended(withFraction: 0.15, of: .black) ?? AquaColors.grayGradientBottom : AquaColors.grayGradientBottom
        let gradient = NSGradient(starting: top, ending: bottom)
        gradient?.draw(in: rect, angle: 270)

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawArrow(in rect: NSRect, pointingUp: Bool, color: NSColor) {
        let cx = rect.midX
        let cy = rect.midY
        let arrowW: CGFloat = 5.0
        let arrowH: CGFloat = 3.0

        color.setFill()
        let arrow = NSBezierPath()
        if pointingUp {
            arrow.move(to: NSPoint(x: cx, y: cy + arrowH / 2))
            arrow.line(to: NSPoint(x: cx - arrowW / 2, y: cy - arrowH / 2))
            arrow.line(to: NSPoint(x: cx + arrowW / 2, y: cy - arrowH / 2))
        } else {
            arrow.move(to: NSPoint(x: cx, y: cy - arrowH / 2))
            arrow.line(to: NSPoint(x: cx - arrowW / 2, y: cy + arrowH / 2))
            arrow.line(to: NSPoint(x: cx + arrowW / 2, y: cy + arrowH / 2))
        }
        arrow.close()
        arrow.fill()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        let loc = convert(event.locationInWindow, from: nil)
        pressedSegment = loc.y >= bounds.midY ? 1 : 0
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isEnabled, let seg = pressedSegment else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            if seg == 1 && value < maxValue {
                value = min(value + increment, maxValue)
                onValueChanged?(value)
                if let action = action { _ = target?.perform(action, with: self) }
            } else if seg == 0 && value > minValue {
                value = max(value - increment, minValue)
                onValueChanged?(value)
                if let action = action { _ = target?.perform(action, with: self) }
            }
        }
        pressedSegment = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else { return }
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            let newSeg = loc.y >= bounds.midY ? 1 : 0
            if pressedSegment != newSeg {
                pressedSegment = newSeg
                needsDisplay = true
            }
        }
    }
}


// MARK: - AquaGroupBox

/// Snow Leopard group box with etched border and optional title.
class AquaGroupBox: NSView {

    var title: String? { didSet { needsDisplay = true } }
    var titleFont: NSFont = SnowLeopardFonts.boldLabel(size: 11)

    let contentView = NSView()
    private let titleHeight: CGFloat = 18
    private let padding: CGFloat = 12

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let topInset: CGFloat = title != nil ? titleHeight + padding : padding
        contentView.frame = NSRect(
            x: padding,
            y: padding,
            width: bounds.width - padding * 2,
            height: bounds.height - topInset - padding
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        let topInset: CGFloat = title != nil ? titleHeight : 0
        let boxRect = NSRect(x: 0.5, y: 0.5, width: bounds.width - 1, height: bounds.height - topInset - 1)

        // Etched border — outer light, inner dark
        let outerPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        NSColor(white: 1.0, alpha: 0.5).setStroke()
        outerPath.lineWidth = 1.0
        outerPath.stroke()

        let innerRect = boxRect.insetBy(dx: 1, dy: 1)
        let innerPath = NSBezierPath(roundedRect: innerRect, xRadius: 3, yRadius: 3)
        NSColor(white: 0.65, alpha: 0.4).setStroke()
        innerPath.lineWidth = 1.0
        innerPath.stroke()

        // Title
        if let title = title {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: AquaColors.textColor,
            ]
            let textSize = (title as NSString).size(withAttributes: attrs)
            (title as NSString).draw(at: NSPoint(x: padding, y: bounds.height - textSize.height - 2), withAttributes: attrs)
        }
    }
}
