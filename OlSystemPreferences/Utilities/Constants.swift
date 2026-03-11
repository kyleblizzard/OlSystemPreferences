import Cocoa

enum AppConstants {
    // Window
    static let gridWindowSize = NSSize(width: 668, height: 680)
    static let windowMinSize = NSSize(width: 668, height: 400)
    static let animationDuration: TimeInterval = 0.25

    // Grid items
    static let iconSize: CGFloat = 32
    static let gridItemSize = NSSize(width: 84, height: 74)
    static let gridSectionInset = NSEdgeInsets(top: 4, left: 10, bottom: 8, right: 10)
    static let gridInteritemSpacing: CGFloat = 4
    static let gridLineSpacing: CGFloat = 6
    static let headerHeight: CGFloat = 22
}

// MARK: - Snow Leopard Color Palette

enum SnowLeopardColors {
    // Grid background
    static let gridBackground = NSColor(white: 0.87, alpha: 1.0)

    // Category header gradient
    static let headerGradientTop = NSColor(white: 0.56, alpha: 1.0)
    static let headerGradientBottom = NSColor(white: 0.43, alpha: 1.0)
    static let headerTopLine = NSColor(white: 0.64, alpha: 1.0)
    static let headerBottomLine = NSColor(white: 0.33, alpha: 1.0)
    static let headerTextColor = NSColor.white
    static let headerTextShadowColor = NSColor(white: 0.0, alpha: 0.5)

    // Item labels
    static let labelColor = NSColor(white: 0.15, alpha: 1.0)
    static let labelShadowColor = NSColor(white: 1.0, alpha: 0.7)

    // Selection highlight (Aqua blue)
    static let selectionTop = NSColor(calibratedRed: 0.36, green: 0.58, blue: 0.90, alpha: 1.0)
    static let selectionBottom = NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.80, alpha: 1.0)
    static let selectionBorder = NSColor(calibratedRed: 0.16, green: 0.34, blue: 0.70, alpha: 1.0)

    // Hover highlight
    static let hoverBackground = NSColor(calibratedRed: 0.30, green: 0.50, blue: 0.85, alpha: 0.25)
}

// MARK: - Snow Leopard Fonts

enum SnowLeopardFonts {
    static func label(size: CGFloat = 11) -> NSFont {
        return NSFont(name: "Lucida Grande", size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    static func boldLabel(size: CGFloat = 11) -> NSFont {
        return NSFont(name: "Lucida Grande Bold", size: size)
            ?? NSFont.boldSystemFont(ofSize: size)
    }
}
