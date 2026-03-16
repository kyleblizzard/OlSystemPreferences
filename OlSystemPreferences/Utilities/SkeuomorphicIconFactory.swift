import Cocoa

/// Generates rich, skeuomorphic Snow Leopard-style preference pane icons.
/// Each icon is a glossy rounded-rect with gradient background and a white SF Symbol overlay.
enum SkeuomorphicIconFactory {

    /// Cache generated icons for performance
    private static var cache: [String: NSImage] = [:]

    /// Generate a Snow Leopard-style skeuomorphic icon
    static func icon(sfSymbol: String, baseColor: NSColor, size: CGFloat = 32) -> NSImage {
        let key = "\(sfSymbol)-\(baseColor.description)-\(size)"
        if let cached = cache[key] { return cached }

        let imageSize = NSSize(width: size, height: size)

        let image = NSImage(size: imageSize)
        image.lockFocusFlipped(false)

        guard let ctx = NSGraphicsContext.current else {
            image.unlockFocus()
            return image
        }
        ctx.shouldAntialias = true
        ctx.imageInterpolation = .high

        // Scale for @2x rendering
        let transform = NSAffineTransform()
        transform.scale(by: 1.0)  // NSImage handles scaling via size vs pixel backing
        transform.concat()

        let fullRect = NSRect(x: 0, y: 0, width: size, height: size)
        let iconRect = fullRect.insetBy(dx: 1, dy: 1)
        let cornerRadius: CGFloat = size * 0.22  // Snow Leopard used ~22% corner radius

        // ---- Drop Shadow ----
        let shadowPath = NSBezierPath(roundedRect: iconRect.offsetBy(dx: 0, dy: -0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(white: 0.0, alpha: 0.35).setFill()
        shadowPath.fill()

        let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // ---- Base Gradient (3-stop for depth) ----
        let lighterColor = baseColor.blended(withFraction: 0.35, of: .white) ?? baseColor
        let darkerColor = baseColor.blended(withFraction: 0.40, of: .black) ?? baseColor
        let midColor = baseColor

        let baseGradient = NSGradient(colors: [lighterColor, midColor, darkerColor],
                                       atLocations: [0.0, 0.45, 1.0],
                                       colorSpace: .deviceRGB)
        baseGradient?.draw(in: iconPath, angle: 270)

        // ---- Inner glow / edge highlight ----
        NSGraphicsContext.saveGraphicsState()
        iconPath.addClip()

        // Top edge bright highlight
        let topHighlightRect = NSRect(x: iconRect.minX, y: iconRect.midY + iconRect.height * 0.05,
                                       width: iconRect.width, height: iconRect.height * 0.45)
        let topHighlightPath = NSBezierPath(roundedRect: topHighlightRect, xRadius: cornerRadius, yRadius: cornerRadius)
        let highlightGradient = NSGradient(starting: NSColor(white: 1.0, alpha: 0.50),
                                            ending: NSColor(white: 1.0, alpha: 0.0))
        highlightGradient?.draw(in: topHighlightPath, angle: 270)

        // Glossy capsule highlight (the classic Aqua "shine" bar)
        let glossHeight = iconRect.height * 0.38
        let glossRect = NSRect(x: iconRect.minX + iconRect.width * 0.08,
                                y: iconRect.maxY - glossHeight - iconRect.height * 0.06,
                                width: iconRect.width * 0.84,
                                height: glossHeight)
        let glossPath = NSBezierPath(roundedRect: glossRect, xRadius: glossRect.width * 0.5, yRadius: glossHeight * 0.5)
        let glossGradient = NSGradient(starting: NSColor(white: 1.0, alpha: 0.55),
                                        ending: NSColor(white: 1.0, alpha: 0.05))
        glossGradient?.draw(in: glossPath, angle: 270)

        // Bottom edge subtle darkening
        let bottomDarkRect = NSRect(x: iconRect.minX, y: iconRect.minY,
                                     width: iconRect.width, height: iconRect.height * 0.20)
        let bottomDarkGradient = NSGradient(starting: NSColor(white: 0.0, alpha: 0.20),
                                             ending: NSColor(white: 0.0, alpha: 0.0))
        bottomDarkGradient?.draw(in: bottomDarkRect, angle: 90)

        NSGraphicsContext.restoreGraphicsState()

        // ---- Border ----
        let borderColor = darkerColor.blended(withFraction: 0.3, of: .black) ?? darkerColor
        borderColor.withAlphaComponent(0.7).setStroke()
        iconPath.lineWidth = 0.75
        iconPath.stroke()

        // Inner light border (top/sides)
        NSGraphicsContext.saveGraphicsState()
        iconPath.addClip()
        let innerBorderRect = iconRect.insetBy(dx: 0.5, dy: 0.5)
        let innerPath = NSBezierPath(roundedRect: innerBorderRect, xRadius: cornerRadius - 0.5, yRadius: cornerRadius - 0.5)
        NSColor(white: 1.0, alpha: 0.25).setStroke()
        innerPath.lineWidth = 0.5
        innerPath.stroke()
        NSGraphicsContext.restoreGraphicsState()

        // ---- SF Symbol overlay ----
        let symbolSize = size * 0.52
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
        if let symbolImage = NSImage(systemSymbolName: sfSymbol, accessibilityDescription: nil) {
            let configured = symbolImage.withSymbolConfiguration(symbolConfig) ?? symbolImage

            // Get the symbol's actual size to center it properly
            let symbolBounds = configured.size
            let symbolX = iconRect.midX - symbolBounds.width / 2
            let symbolY = iconRect.midY - symbolBounds.height / 2 - size * 0.02

            let symbolRect = NSRect(x: symbolX, y: symbolY,
                                     width: symbolBounds.width, height: symbolBounds.height)

            // Draw shadow for the symbol
            let shadowImg = configured.copy() as! NSImage
            shadowImg.lockFocus()
            NSColor(white: 0.0, alpha: 0.3).set()
            NSRect(origin: .zero, size: shadowImg.size).fill(using: .sourceAtop)
            shadowImg.unlockFocus()
            shadowImg.draw(in: symbolRect.offsetBy(dx: 0, dy: -0.75),
                           from: .zero, operation: .sourceOver, fraction: 0.5)

            // Draw symbol in white
            let whiteSymbol = configured.copy() as! NSImage
            whiteSymbol.lockFocus()
            NSColor.white.set()
            NSRect(origin: .zero, size: whiteSymbol.size).fill(using: .sourceAtop)
            whiteSymbol.unlockFocus()
            whiteSymbol.draw(in: symbolRect,
                             from: .zero, operation: .sourceOver, fraction: 0.95)
        }

        image.unlockFocus()
        image.isTemplate = false

        cache[key] = image
        return image
    }

    /// Specific icon presets matching Snow Leopard's color palette
    static func presetIcon(for id: String, size: CGFloat = 32) -> NSImage? {
        guard let preset = iconPresets[id] else { return nil }
        return icon(sfSymbol: preset.symbol, baseColor: preset.color, size: size)
    }

    // MARK: - Presets

    private struct IconPreset {
        let symbol: String
        let color: NSColor
    }

    /// Snow Leopard-inspired color palette for each pane
    private static let iconPresets: [String: IconPreset] = [
        // Personal
        "appearance":     IconPreset(symbol: "paintbrush.fill", color: NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.75, alpha: 1.0)),
        "wallpaper":      IconPreset(symbol: "photo.fill", color: NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.80, alpha: 1.0)),
        "screensaver":    IconPreset(symbol: "sparkles.tv.fill", color: NSColor(calibratedRed: 0.35, green: 0.30, blue: 0.70, alpha: 1.0)),
        "dock":           IconPreset(symbol: "dock.rectangle", color: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0)),
        "notifications":  IconPreset(symbol: "bell.badge.fill", color: NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.25, alpha: 1.0)),
        "focus":          IconPreset(symbol: "moon.fill", color: NSColor(calibratedRed: 0.40, green: 0.35, blue: 0.75, alpha: 1.0)),
        "controlcenter":  IconPreset(symbol: "switch.2", color: NSColor(calibratedRed: 0.45, green: 0.45, blue: 0.52, alpha: 1.0)),
        "spotlight":      IconPreset(symbol: "magnifyingglass", color: NSColor(calibratedRed: 0.75, green: 0.30, blue: 0.55, alpha: 1.0)),
        "exposespaces":   IconPreset(symbol: "rectangle.3.group", color: NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.80, alpha: 1.0)),

        // Hardware
        "displays":       IconPreset(symbol: "display", color: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.78, alpha: 1.0)),
        "sound":          IconPreset(symbol: "speaker.wave.3.fill", color: NSColor(calibratedRed: 0.80, green: 0.35, blue: 0.50, alpha: 1.0)),
        "keyboard":       IconPreset(symbol: "keyboard", color: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.52, alpha: 1.0)),
        "mouse":          IconPreset(symbol: "computermouse.fill", color: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.52, alpha: 1.0)),
        "trackpad":       IconPreset(symbol: "rectangle.and.hand.point.up.left.fill", color: NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.52, alpha: 1.0)),
        "printers":       IconPreset(symbol: "printer.fill", color: NSColor(calibratedRed: 0.35, green: 0.55, blue: 0.75, alpha: 1.0)),
        "battery":        IconPreset(symbol: "battery.100.bolt", color: NSColor(calibratedRed: 0.25, green: 0.68, blue: 0.35, alpha: 1.0)),

        // Internet & Wireless
        "appleid":        IconPreset(symbol: "person.crop.circle.fill", color: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0)),
        "wifi":           IconPreset(symbol: "wifi", color: NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.85, alpha: 1.0)),
        "bluetooth":      IconPreset(symbol: "wave.3.right", color: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.85, alpha: 1.0)),
        "network":        IconPreset(symbol: "network", color: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0)),
        "internetaccounts": IconPreset(symbol: "at", color: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0)),
        "sharing":        IconPreset(symbol: "person.2.fill", color: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0)),

        // System
        "general":        IconPreset(symbol: "gearshape", color: NSColor(calibratedRed: 0.48, green: 0.48, blue: 0.55, alpha: 1.0)),
        "users":          IconPreset(symbol: "person.2.fill", color: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0)),
        "passwords":      IconPreset(symbol: "key.fill", color: NSColor(calibratedRed: 0.85, green: 0.70, blue: 0.20, alpha: 1.0)),
        "touchid":        IconPreset(symbol: "touchid", color: NSColor(calibratedRed: 0.80, green: 0.25, blue: 0.30, alpha: 1.0)),
        "privacy":        IconPreset(symbol: "hand.raised.fill", color: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0)),
        "datetime":       IconPreset(symbol: "clock.fill", color: NSColor(calibratedRed: 0.25, green: 0.48, blue: 0.80, alpha: 1.0)),
        "softwareupdate": IconPreset(symbol: "arrow.triangle.2.circlepath", color: NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.80, alpha: 1.0)),
        "accessibility":  IconPreset(symbol: "accessibility", color: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.85, alpha: 1.0)),
        "screentime":     IconPreset(symbol: "hourglass", color: NSColor(calibratedRed: 0.60, green: 0.30, blue: 0.75, alpha: 1.0)),
        "lockscreen":     IconPreset(symbol: "lock.fill", color: NSColor(calibratedRed: 0.85, green: 0.70, blue: 0.20, alpha: 1.0)),
        "startupdisk":    IconPreset(symbol: "internaldrive.fill", color: NSColor(calibratedRed: 0.48, green: 0.48, blue: 0.55, alpha: 1.0)),
        "timemachine":    IconPreset(symbol: "clock.arrow.circlepath", color: NSColor(calibratedRed: 0.25, green: 0.68, blue: 0.35, alpha: 1.0)),
        "gamecenter":     IconPreset(symbol: "gamecontroller.fill", color: NSColor(calibratedRed: 0.80, green: 0.35, blue: 0.55, alpha: 1.0)),
        "wallet":         IconPreset(symbol: "creditcard.fill", color: NSColor(calibratedRed: 0.85, green: 0.70, blue: 0.20, alpha: 1.0)),
    ]
}
