import Cocoa

enum AppConstants {
    // Window
    static let gridWindowSize = NSSize(width: 668, height: 668)
    static let windowMinSize = NSSize(width: 668, height: 400)
    static let animationDuration: TimeInterval = 0.25

    // Grid items
    static let iconSize: CGFloat = 32
    static let gridItemSize = NSSize(width: 84, height: 76)
    static let gridSectionInset = NSEdgeInsets(top: 6, left: 16, bottom: 8, right: 16)
    static let gridInteritemSpacing: CGFloat = 4
    static let gridLineSpacing: CGFloat = 4
    static let headerHeight: CGFloat = 22
}

// MARK: - Launchpad Constants

enum LaunchpadConstants {
    // Grid items (scaled up 20%)
    static let iconSize: CGFloat = 78
    static let itemSize = NSSize(width: 132, height: 132)
    static let interitemSpacing: CGFloat = 24
    static let lineSpacing: CGFloat = 32
    static let sectionInset = NSEdgeInsets(top: 24, left: 72, bottom: 48, right: 72)

    // Search
    static let searchFieldWidth: CGFloat = 336
    static let searchTopOffset: CGFloat = 60

    // Folder overlay
    static let folderOverlayWidth: CGFloat = 552
    static let folderItemSize = NSSize(width: 96, height: 108)
    static let folderIconSize: CGFloat = 58
    static let folderIconCornerRadius: CGFloat = 17
    static let folderIconPadding: CGFloat = 10
    static let folderIconGap: CGFloat = 4

    // Window
    static let windowScreenFraction: CGFloat = 0.80
    static let windowCornerRadius: CGFloat = 16

    // Animation durations
    static let showDuration: TimeInterval = 0.25
    static let dismissDuration: TimeInterval = 0.2
    static let folderOpenDuration: TimeInterval = 0.5
    static let folderCloseDuration: TimeInterval = 0.35

    // Jiggle
    static let jiggleAngle: CGFloat = 0.02  // radians
    static let jiggleDuration: CFTimeInterval = 0.12
    static let longPressMinDuration: TimeInterval = 0.5

    // App launch animation
    static let launchScale: CGFloat = 2.5
    static let launchDuration: TimeInterval = 0.35

    // Spring animation
    static let springDamping: CGFloat = 15
    static let springStiffness: CGFloat = 200

    // Pagination
    static let maxColumns: Int = 9
    static let maxRows: Int = 6
    static let pageDotsHeight: CGFloat = 28
    static let pageDotSize: CGFloat = 8
    static let pageDotSpacing: CGFloat = 12
    static let pageTransitionDuration: TimeInterval = 0.35
}

// MARK: - Snow Leopard Color Palette

enum SnowLeopardColors {
    // Grid background
    static let gridBackground = NSColor(white: 0.87, alpha: 1.0)

    // Category header gradient
    static let headerGradientTop = NSColor(white: 0.58, alpha: 1.0)
    static let headerGradientBottom = NSColor(white: 0.42, alpha: 1.0)
    static let headerTopLine = NSColor(white: 0.66, alpha: 1.0)
    static let headerBottomLine = NSColor(white: 0.30, alpha: 1.0)
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

    // Pane background (lighter gray used inside pane views)
    static let paneBackground = NSColor(white: 0.93, alpha: 1.0)

    // Toolbar nav control
    static let navGradientTop = NSColor(white: 0.92, alpha: 1.0)
    static let navGradientBottom = NSColor(white: 0.75, alpha: 1.0)
    static let navBorder = NSColor(white: 0.55, alpha: 1.0)
    static let navDivider = NSColor(white: 0.60, alpha: 1.0)
    static let navArrow = NSColor(white: 0.30, alpha: 1.0)
    static let navArrowDisabled = NSColor(white: 0.65, alpha: 1.0)
    static let navPressedTop = NSColor(white: 0.70, alpha: 1.0)
    static let navPressedBottom = NSColor(white: 0.58, alpha: 1.0)
}

// MARK: - Dashboard Constants

enum DashboardConstants {
    static let windowScreenFraction: CGFloat = 0.80
    static let cornerRadius: CGFloat = 16
    static let showDuration: TimeInterval = 0.25
    static let dismissDuration: TimeInterval = 0.2
}

// MARK: - Cover Flow Constants

enum CoverFlowConstants {
    static let cardSize = NSSize(width: 160, height: 200)
    static let sideCardAngle: CGFloat = 70 * .pi / 180  // 70 degrees
    static let perspectiveDepth: CGFloat = -1.0 / 800.0
    static let animationDuration: TimeInterval = 0.35
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
