import Cocoa

class StickyNoteWidget: DashboardWidget {

    override var widgetIdentifier: String { "stickynote" }
    override var widgetTitle: String { "Sticky Note" }
    override var widgetSize: NSSize { NSSize(width: 200, height: 200) }

    private let textView = NSTextView()

    override var persistedData: [String: String]? {
        ["text": textView.string]
    }

    override func restoreData(_ data: [String: String]?) {
        if let text = data?["text"] {
            textView.string = text
        }
    }

    override func setupContent(in container: NSView) {
        // Yellow sticky background
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.93, blue: 0.55, alpha: 1.0).cgColor

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        textView.font = NSFont(name: "Marker Felt", size: 14) ?? SnowLeopardFonts.label(size: 14)
        textView.textColor = NSColor(white: 0.15, alpha: 1.0)
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width, .height]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }
}
