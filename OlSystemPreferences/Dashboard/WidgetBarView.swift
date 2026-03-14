import Cocoa

protocol WidgetBarDelegate: AnyObject {
    func widgetBar(_ bar: WidgetBarView, didSelectType type: String)
}

class WidgetBarView: NSView {

    weak var delegate: WidgetBarDelegate?

    private let widgetTypes: [(type: String, title: String, symbol: String)] = [
        ("calculator", "Calculator", "plus.forwardslash.minus"),
        ("stickynote", "Sticky Note", "note.text"),
        ("clock", "Clock", "clock.fill"),
        ("weather", "Weather", "cloud.sun.fill"),
        ("unitconverter", "Converter", "arrow.left.arrow.right"),
    ]

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
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.85).cgColor

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.spacing = 24
        stack.alignment = .centerY

        for widgetType in widgetTypes {
            let button = makeWidgetButton(widgetType)
            stack.addArrangedSubview(button)
        }

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    private func makeWidgetButton(_ type: (type: String, title: String, symbol: String)) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.widthAnchor.constraint(equalToConstant: 64).isActive = true
        container.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: type.symbol, accessibilityDescription: type.title) {
            iconView.image = img
        }
        iconView.contentTintColor = .white
        iconView.imageScaling = .scaleProportionallyUpOrDown
        container.addSubview(iconView)

        let label = NSTextField(labelWithString: type.title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = SnowLeopardFonts.label(size: 9)
        label.textColor = NSColor(white: 0.8, alpha: 1.0)
        label.alignment = .center
        container.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            iconView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.widthAnchor.constraint(equalTo: container.widthAnchor),
        ])

        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(widgetTypeClicked(_:)))
        container.addGestureRecognizer(clickGesture)
        container.identifier = NSUserInterfaceItemIdentifier(type.type)

        return container
    }

    @objc private func widgetTypeClicked(_ sender: NSClickGestureRecognizer) {
        guard let typeId = sender.view?.identifier?.rawValue else { return }
        delegate?.widgetBar(self, didSelectType: typeId)
    }
}
