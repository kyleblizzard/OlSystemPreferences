import Cocoa
import QuartzCore

/// Mini Dock visualization that updates live as preference sliders change.
class DockPreviewView: NSView {

    var dockSize: CGFloat = 48 { didSet { updatePreview(animated: true) } }
    var magnificationEnabled: Bool = false { didSet { updatePreview(animated: true) } }
    var magnificationSize: CGFloat = 64 { didSet { updatePreview(animated: true) } }
    var position: String = "bottom" { didSet { updatePreview(animated: true) } }
    var showIndicators: Bool = true { didSet { updatePreview(animated: true) } }

    private let shelfLayer = CALayer()
    private var iconLayers: [CALayer] = []
    private var indicatorLayers: [CALayer] = []

    private let sampleIcons = ["folder.fill", "safari.fill", "envelope.fill", "photo.fill", "trash.fill"]

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
        layer?.masksToBounds = true

        // Shelf background
        shelfLayer.backgroundColor = NSColor(white: 0.5, alpha: 0.25).cgColor
        shelfLayer.cornerRadius = 8
        shelfLayer.borderWidth = 0.5
        shelfLayer.borderColor = NSColor(white: 1.0, alpha: 0.3).cgColor
        layer?.addSublayer(shelfLayer)

        // Create icon layers
        for symbolName in sampleIcons {
            let iconLayer = CALayer()
            iconLayer.contentsGravity = .resizeAspect

            if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .regular)
                let configured = img.withSymbolConfiguration(config) ?? img
                let tinted = tintImage(configured, color: .white)
                iconLayer.contents = tinted
            }

            layer?.addSublayer(iconLayer)
            iconLayers.append(iconLayer)

            // Indicator dot
            let dot = CALayer()
            dot.backgroundColor = NSColor(white: 0.3, alpha: 0.8).cgColor
            dot.cornerRadius = 1.5
            layer?.addSublayer(dot)
            indicatorLayers.append(dot)
        }

        updatePreview(animated: false)
    }

    private func tintImage(_ image: NSImage, color: NSColor) -> NSImage {
        let tinted = NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        return tinted
    }

    func updatePreview(animated: Bool) {
        let duration = animated ? 0.2 : 0.0

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)

        let iconCount = CGFloat(sampleIcons.count)
        let scale = min(dockSize / 128.0, 1.0)
        let iconSize: CGFloat = max(12, 24 * scale)
        let gap: CGFloat = max(3, 6 * scale)
        let totalWidth = iconCount * iconSize + (iconCount - 1) * gap
        let shelfPadding: CGFloat = 8

        if position == "bottom" {
            let shelfHeight = iconSize + shelfPadding * 2
            let shelfY = (bounds.height - shelfHeight) / 2
            shelfLayer.frame = NSRect(
                x: (bounds.width - totalWidth - shelfPadding * 2) / 2,
                y: shelfY,
                width: totalWidth + shelfPadding * 2,
                height: shelfHeight
            )

            let startX = shelfLayer.frame.origin.x + shelfPadding
            for (i, iconLayer) in iconLayers.enumerated() {
                let x = startX + CGFloat(i) * (iconSize + gap)
                iconLayer.frame = NSRect(x: x, y: shelfY + shelfPadding, width: iconSize, height: iconSize)

                indicatorLayers[i].frame = NSRect(
                    x: x + iconSize / 2 - 1.5,
                    y: shelfY + 2,
                    width: 3, height: 3
                )
                indicatorLayers[i].isHidden = !showIndicators
            }
        } else {
            // Left or right
            let totalHeight = iconCount * iconSize + (iconCount - 1) * gap
            let shelfWidth = iconSize + shelfPadding * 2
            let shelfX = position == "left" ? CGFloat(4) : bounds.width - shelfWidth - 4

            shelfLayer.frame = NSRect(
                x: shelfX,
                y: (bounds.height - totalHeight - shelfPadding * 2) / 2,
                width: shelfWidth,
                height: totalHeight + shelfPadding * 2
            )

            let startY = shelfLayer.frame.origin.y + shelfPadding
            for (i, iconLayer) in iconLayers.enumerated() {
                let y = startY + CGFloat(i) * (iconSize + gap)
                iconLayer.frame = NSRect(x: shelfLayer.frame.origin.x + shelfPadding, y: y, width: iconSize, height: iconSize)

                let dotX = position == "left"
                    ? shelfLayer.frame.origin.x + shelfWidth - 4
                    : shelfLayer.frame.origin.x + 1
                indicatorLayers[i].frame = NSRect(x: dotX, y: y + iconSize / 2 - 1.5, width: 3, height: 3)
                indicatorLayers[i].isHidden = !showIndicators
            }
        }

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        updatePreview(animated: false)
    }
}
