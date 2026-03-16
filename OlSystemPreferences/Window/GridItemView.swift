import Cocoa

class GridItemView: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("GridItemView")

    private let iconImageView: NSImageView = {
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = SnowLeopardFonts.label(size: 11)
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.cell?.truncatesLastVisibleLine = true
        label.textColor = SnowLeopardColors.labelColor
        label.shadow = {
            let s = NSShadow()
            s.shadowOffset = NSSize(width: 0, height: -1)
            s.shadowColor = SnowLeopardColors.labelShadowColor
            s.shadowBlurRadius = 0
            return s
        }()
        return label
    }()

    private let selectionView: SelectionBackgroundView = {
        let v = SelectionBackgroundView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        view.addSubview(selectionView)
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            selectionView.topAnchor.constraint(equalTo: view.topAnchor, constant: 3),
            selectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 3),
            selectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -3),
            selectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -3),

            iconImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: AppConstants.iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: AppConstants.iconSize),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 1),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -1),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -2),
        ])
    }

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet { updateAppearance() }
    }

    private func updateAppearance() {
        if isSelected {
            selectionView.isHidden = false
            selectionView.isHovered = false
            titleLabel.textColor = .white
            titleLabel.shadow = nil
        } else if highlightState == .forSelection {
            selectionView.isHidden = false
            selectionView.isHovered = true
            titleLabel.textColor = SnowLeopardColors.labelColor
            titleLabel.shadow = makeLabelShadow()
        } else {
            selectionView.isHidden = true
            titleLabel.textColor = SnowLeopardColors.labelColor
            titleLabel.shadow = makeLabelShadow()
        }
    }

    private func makeLabelShadow() -> NSShadow {
        let s = NSShadow()
        s.shadowOffset = NSSize(width: 0, height: -1)
        s.shadowColor = SnowLeopardColors.labelShadowColor
        s.shadowBlurRadius = 0
        return s
    }

    /// Whether this item is dimmed during a Spotlight search (non-matching items get dimmed)
    var isDimmed: Bool = false {
        didSet { updateDimming() }
    }

    func configure(title: String, icon: NSImage, tintColor: NSColor?) {
        titleLabel.stringValue = title
        iconImageView.image = icon
        // Icons are pre-rendered by SkeuomorphicIconFactory or are app icons — no tint needed
        iconImageView.symbolConfiguration = nil
        iconImageView.contentTintColor = nil
    }

    /// Animate opacity to show/hide the dimming overlay for search spotlight effect.
    /// Non-matching items fade to ~30% opacity; matching items stay fully visible.
    private func updateDimming() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            self.view.animator().alphaValue = isDimmed ? 0.3 : 1.0
        }
    }
}

// MARK: - Aqua-Style Selection Background

private class SelectionBackgroundView: NSView {

    var isHovered = false {
        didSet { needsDisplay = true }
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
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        if isHovered {
            SnowLeopardColors.hoverBackground.setFill()
            path.fill()
        } else {
            // Aqua blue gradient selection
            let gradient = NSGradient(
                starting: SnowLeopardColors.selectionTop,
                ending: SnowLeopardColors.selectionBottom
            )
            gradient?.draw(in: path, angle: 270)

            // Aqua gloss: white highlight in upper portion
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let glossRect = NSRect(
                x: rect.origin.x,
                y: rect.origin.y + rect.height * 0.5,
                width: rect.width,
                height: rect.height * 0.5
            )
            let glossGradient = NSGradient(
                starting: NSColor(white: 1.0, alpha: 0.28),
                ending: NSColor(white: 1.0, alpha: 0.04)
            )
            glossGradient?.draw(in: glossRect, angle: 270)
            NSGraphicsContext.restoreGraphicsState()

            // Border
            SnowLeopardColors.selectionBorder.setStroke()
            path.lineWidth = 1.0
            path.stroke()
        }
    }
}

// MARK: - Snow Leopard Section Header

class GridSectionHeaderView: NSView, NSCollectionViewSectionHeaderView {

    static let identifier = NSUserInterfaceItemIdentifier("GridSectionHeaderView")

    let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = SnowLeopardFonts.boldLabel(size: 11)
        label.textColor = SnowLeopardColors.headerTextColor
        label.shadow = {
            let s = NSShadow()
            s.shadowOffset = NSSize(width: 0, height: -1)
            s.shadowColor = SnowLeopardColors.headerTextShadowColor
            s.shadowBlurRadius = 0
            return s
        }()
        return label
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
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 1),
        ])
    }

    override func draw(_ dirtyRect: NSRect) {
        // Dark gradient background
        let gradient = NSGradient(
            starting: SnowLeopardColors.headerGradientTop,
            ending: SnowLeopardColors.headerGradientBottom
        )
        gradient?.draw(in: bounds, angle: 270)

        // Top highlight line
        SnowLeopardColors.headerTopLine.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()

        // Bottom shadow line
        SnowLeopardColors.headerBottomLine.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
}
