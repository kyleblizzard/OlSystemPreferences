import Cocoa

class WeatherWidget: DashboardWidget {

    override var widgetIdentifier: String { "weather" }
    override var widgetTitle: String { "Weather" }
    override var widgetSize: NSSize { NSSize(width: 200, height: 150) }

    override func setupContent(in container: NSView) {
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedRed: 0.25, green: 0.45, blue: 0.75, alpha: 1.0).cgColor

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4

        // Weather icon
        let iconView = NSImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        if let img = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: "Weather") {
            let config = NSImage.SymbolConfiguration(pointSize: 36, weight: .regular)
            iconView.image = img.withSymbolConfiguration(config)
        }
        iconView.contentTintColor = .white
        iconView.widthAnchor.constraint(equalToConstant: 48).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 48).isActive = true

        // Temperature
        let tempLabel = NSTextField(labelWithString: "72°F")
        tempLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 32, weight: .light)
        tempLabel.textColor = .white
        tempLabel.alignment = .center

        // Location
        let locationLabel = NSTextField(labelWithString: "Cupertino")
        locationLabel.font = SnowLeopardFonts.label(size: 11)
        locationLabel.textColor = NSColor(white: 0.85, alpha: 1.0)
        locationLabel.alignment = .center

        // Condition
        let conditionLabel = NSTextField(labelWithString: "Partly Cloudy")
        conditionLabel.font = SnowLeopardFonts.label(size: 10)
        conditionLabel.textColor = NSColor(white: 0.75, alpha: 1.0)
        conditionLabel.alignment = .center

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(tempLabel)
        stack.addArrangedSubview(locationLabel)
        stack.addArrangedSubview(conditionLabel)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }
}
