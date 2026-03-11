import Cocoa

class GridItemView: NSCollectionViewItem {

    static let identifier = NSUserInterfaceItemIdentifier("GridItemView")

    private let iconImageView: NSImageView = {
        let iv = NSImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: AppConstants.iconSize, weight: .light)
        return iv
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 2
        return label
    }()

    private let containerView: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.cornerRadius = 8
        return v
    }()

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 2),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),

            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: AppConstants.iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: AppConstants.iconSize),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -2),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -4),
        ])
    }

    override var isSelected: Bool {
        didSet {
            containerView.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
                : nil
        }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            switch highlightState {
            case .forSelection:
                containerView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
            case .forDeselection, .none:
                containerView.layer?.backgroundColor = isSelected
                    ? NSColor.controlAccentColor.withAlphaComponent(0.2).cgColor
                    : nil
            case .asDropTarget:
                break
            @unknown default:
                break
            }
        }
    }

    func configure(title: String, icon: NSImage) {
        titleLabel.stringValue = title
        iconImageView.image = icon
        iconImageView.contentTintColor = NSColor.controlAccentColor
    }
}

// MARK: - Section Header

class GridSectionHeaderView: NSView, NSCollectionViewSectionHeaderView {

    static let identifier = NSUserInterfaceItemIdentifier("GridSectionHeaderView")

    let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private let separatorView: NSView = {
        let v = NSView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.separatorColor.cgColor
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
        addSubview(separatorView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            separatorView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            separatorView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 6),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }
}
