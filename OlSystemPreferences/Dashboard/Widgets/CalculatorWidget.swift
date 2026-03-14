import Cocoa

class CalculatorWidget: DashboardWidget {

    override var widgetIdentifier: String { "calculator" }
    override var widgetTitle: String { "Calculator" }
    override var widgetSize: NSSize { NSSize(width: 200, height: 280) }

    private let displayLabel = NSTextField(labelWithString: "0")
    private var currentValue: Double = 0
    private var pendingOperator: String?
    private var pendingValue: Double = 0
    private var resetOnNextDigit = true

    override func setupContent(in container: NSView) {
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 24, weight: .regular)
        displayLabel.textColor = .white
        displayLabel.alignment = .right
        displayLabel.backgroundColor = NSColor(white: 0.1, alpha: 0.8)
        displayLabel.isBezeled = true
        displayLabel.bezelStyle = .squareBezel
        displayLabel.drawsBackground = true
        displayLabel.isEditable = false
        container.addSubview(displayLabel)

        NSLayoutConstraint.activate([
            displayLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            displayLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            displayLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            displayLabel.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Button grid
        let buttons: [[String]] = [
            ["C", "±", "%", "÷"],
            ["7", "8", "9", "×"],
            ["4", "5", "6", "−"],
            ["1", "2", "3", "+"],
            ["0", ".", "=", ""],
        ]

        let grid = NSStackView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.orientation = .vertical
        grid.spacing = 2
        container.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: displayLabel.bottomAnchor, constant: 8),
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
        ])

        for row in buttons {
            let rowStack = NSStackView()
            rowStack.orientation = .horizontal
            rowStack.spacing = 2
            rowStack.distribution = .fillEqually

            for label in row where !label.isEmpty {
                let btn = NSButton(title: label, target: self, action: #selector(buttonPressed(_:)))
                btn.font = SnowLeopardFonts.label(size: 14)
                btn.bezelStyle = .texturedRounded
                btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
                rowStack.addArrangedSubview(btn)
            }
            grid.addArrangedSubview(rowStack)
        }
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        let label = sender.title

        switch label {
        case "0"..."9":
            if resetOnNextDigit {
                displayLabel.stringValue = label
                resetOnNextDigit = false
            } else {
                displayLabel.stringValue += label
            }

        case ".":
            if !displayLabel.stringValue.contains(".") {
                if resetOnNextDigit {
                    displayLabel.stringValue = "0."
                    resetOnNextDigit = false
                } else {
                    displayLabel.stringValue += "."
                }
            }

        case "C":
            currentValue = 0
            pendingOperator = nil
            pendingValue = 0
            displayLabel.stringValue = "0"
            resetOnNextDigit = true

        case "±":
            if let val = Double(displayLabel.stringValue) {
                displayLabel.stringValue = formatNumber(-val)
            }

        case "%":
            if let val = Double(displayLabel.stringValue) {
                displayLabel.stringValue = formatNumber(val / 100.0)
                resetOnNextDigit = true
            }

        case "+", "−", "×", "÷":
            if let val = Double(displayLabel.stringValue) {
                if let op = pendingOperator {
                    currentValue = calculate(pendingValue, op, val)
                    displayLabel.stringValue = formatNumber(currentValue)
                } else {
                    currentValue = val
                }
                pendingOperator = label
                pendingValue = currentValue
                resetOnNextDigit = true
            }

        case "=":
            if let op = pendingOperator, let val = Double(displayLabel.stringValue) {
                let result = calculate(pendingValue, op, val)
                displayLabel.stringValue = formatNumber(result)
                pendingOperator = nil
                pendingValue = 0
                currentValue = result
                resetOnNextDigit = true
            }

        default:
            break
        }
    }

    private func calculate(_ a: Double, _ op: String, _ b: Double) -> Double {
        switch op {
        case "+": return a + b
        case "−": return a - b
        case "×": return a * b
        case "÷": return b != 0 ? a / b : 0
        default: return b
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.8g", value)
    }
}
