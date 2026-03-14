import Cocoa

class UnitConverterWidget: DashboardWidget {

    override var widgetIdentifier: String { "unitconverter" }
    override var widgetTitle: String { "Unit Converter" }
    override var widgetSize: NSSize { NSSize(width: 220, height: 180) }

    private let categoryPopup = NSPopUpButton()
    private let fromField = NSTextField()
    private let toField = NSTextField(labelWithString: "0")
    private let fromUnitPopup = NSPopUpButton()
    private let toUnitPopup = NSPopUpButton()

    private let categories: [(name: String, units: [(String, Dimension)])] = [
        ("Length", [
            ("Meters", UnitLength.meters),
            ("Feet", UnitLength.feet),
            ("Inches", UnitLength.inches),
            ("Kilometers", UnitLength.kilometers),
            ("Miles", UnitLength.miles),
        ]),
        ("Weight", [
            ("Kilograms", UnitMass.kilograms),
            ("Pounds", UnitMass.pounds),
            ("Ounces", UnitMass.ounces),
            ("Grams", UnitMass.grams),
        ]),
        ("Temperature", [
            ("Celsius", UnitTemperature.celsius),
            ("Fahrenheit", UnitTemperature.fahrenheit),
            ("Kelvin", UnitTemperature.kelvin),
        ]),
        ("Volume", [
            ("Liters", UnitVolume.liters),
            ("Gallons", UnitVolume.gallons),
            ("Cups", UnitVolume.cups),
            ("Milliliters", UnitVolume.milliliters),
        ]),
    ]

    override func setupContent(in container: NSView) {
        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        // Category
        categoryPopup.removeAllItems()
        for cat in categories {
            categoryPopup.addItem(withTitle: cat.name)
        }
        categoryPopup.font = SnowLeopardFonts.label(size: 11)
        categoryPopup.target = self
        categoryPopup.action = #selector(categoryChanged(_:))

        stack.addArrangedSubview(categoryPopup)

        // From row
        fromField.translatesAutoresizingMaskIntoConstraints = false
        fromField.font = SnowLeopardFonts.label(size: 13)
        fromField.stringValue = "1"
        fromField.alignment = .right
        fromField.delegate = self
        fromField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        fromUnitPopup.font = SnowLeopardFonts.label(size: 11)
        fromUnitPopup.target = self
        fromUnitPopup.action = #selector(unitChanged(_:))

        let fromRow = NSStackView(views: [fromField, fromUnitPopup])
        fromRow.spacing = 6
        stack.addArrangedSubview(fromRow)

        // Arrow
        let arrowLabel = NSTextField(labelWithString: "↓")
        arrowLabel.font = SnowLeopardFonts.boldLabel(size: 16)
        arrowLabel.textColor = NSColor(white: 0.7, alpha: 1.0)
        arrowLabel.alignment = .center
        stack.addArrangedSubview(arrowLabel)

        // To row
        toField.translatesAutoresizingMaskIntoConstraints = false
        toField.font = SnowLeopardFonts.boldLabel(size: 13)
        toField.textColor = .white
        toField.alignment = .right
        toField.widthAnchor.constraint(equalToConstant: 80).isActive = true

        toUnitPopup.font = SnowLeopardFonts.label(size: 11)
        toUnitPopup.target = self
        toUnitPopup.action = #selector(unitChanged(_:))

        let toRow = NSStackView(views: [toField, toUnitPopup])
        toRow.spacing = 6
        stack.addArrangedSubview(toRow)

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        updateUnitPopups()
        convert()
    }

    private func updateUnitPopups() {
        let idx = categoryPopup.indexOfSelectedItem
        guard idx >= 0 && idx < categories.count else { return }
        let units = categories[idx].units

        fromUnitPopup.removeAllItems()
        toUnitPopup.removeAllItems()
        for u in units {
            fromUnitPopup.addItem(withTitle: u.0)
            toUnitPopup.addItem(withTitle: u.0)
        }
        if toUnitPopup.numberOfItems > 1 {
            toUnitPopup.selectItem(at: 1)
        }
    }

    private func convert() {
        let catIdx = categoryPopup.indexOfSelectedItem
        guard catIdx >= 0 && catIdx < categories.count else { return }
        let units = categories[catIdx].units

        let fromIdx = fromUnitPopup.indexOfSelectedItem
        let toIdx = toUnitPopup.indexOfSelectedItem
        guard fromIdx >= 0 && fromIdx < units.count,
              toIdx >= 0 && toIdx < units.count else { return }

        let value = Double(fromField.stringValue) ?? 0
        let fromUnit = units[fromIdx].1
        let toUnit = units[toIdx].1

        let measurement = Measurement(value: value, unit: fromUnit)
        let converted = measurement.converted(to: toUnit)

        toField.stringValue = String(format: "%.4g", converted.value)
    }

    @objc private func categoryChanged(_ sender: Any?) {
        updateUnitPopups()
        convert()
    }

    @objc private func unitChanged(_ sender: Any?) {
        convert()
    }
}

extension UnitConverterWidget: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        convert()
    }
}
