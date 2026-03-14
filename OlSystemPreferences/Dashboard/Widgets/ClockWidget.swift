import Cocoa

class ClockWidget: DashboardWidget {

    override var widgetIdentifier: String { "clock" }
    override var widgetTitle: String { "Clock" }
    override var widgetSize: NSSize { NSSize(width: 180, height: 204) }

    private let clockFace = ClockFaceView()
    private var timer: Timer?

    override func setupContent(in container: NSView) {
        clockFace.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(clockFace)

        NSLayoutConstraint.activate([
            clockFace.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            clockFace.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            clockFace.widthAnchor.constraint(equalToConstant: 160),
            clockFace.heightAnchor.constraint(equalToConstant: 160),
        ])

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.clockFace.needsDisplay = true
        }
    }

    deinit {
        timer?.invalidate()
    }
}

private class ClockFaceView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 4

        // Face
        let facePath = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        NSColor(white: 0.95, alpha: 1.0).setFill()
        facePath.fill()
        NSColor(white: 0.3, alpha: 1.0).setStroke()
        facePath.lineWidth = 2
        facePath.stroke()

        // Hour markers
        for i in 0..<12 {
            let angle = CGFloat(i) * .pi / 6 - .pi / 2
            let outerR = radius - 4
            let innerR = radius - 12
            let outer = NSPoint(x: center.x + cos(angle) * outerR, y: center.y + sin(angle) * outerR)
            let inner = NSPoint(x: center.x + cos(angle) * innerR, y: center.y + sin(angle) * innerR)

            let tick = NSBezierPath()
            tick.move(to: outer)
            tick.line(to: inner)
            tick.lineWidth = 2
            NSColor(white: 0.2, alpha: 1.0).setStroke()
            tick.stroke()
        }

        // Current time
        let calendar = Calendar.current
        let now = Date()
        let hour = CGFloat(calendar.component(.hour, from: now) % 12)
        let minute = CGFloat(calendar.component(.minute, from: now))
        let second = CGFloat(calendar.component(.second, from: now))

        // Hour hand
        let hourAngle = (hour + minute / 60) * .pi / 6 - .pi / 2
        drawHand(from: center, angle: hourAngle, length: radius * 0.5, width: 4, color: NSColor(white: 0.15, alpha: 1.0))

        // Minute hand
        let minuteAngle = minute * .pi / 30 - .pi / 2
        drawHand(from: center, angle: minuteAngle, length: radius * 0.7, width: 2.5, color: NSColor(white: 0.15, alpha: 1.0))

        // Second hand
        let secondAngle = second * .pi / 30 - .pi / 2
        drawHand(from: center, angle: secondAngle, length: radius * 0.75, width: 1, color: .systemRed)

        // Center dot
        let dotSize: CGFloat = 6
        let dotRect = NSRect(x: center.x - dotSize / 2, y: center.y - dotSize / 2, width: dotSize, height: dotSize)
        NSColor(white: 0.2, alpha: 1.0).setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }

    private func drawHand(from center: NSPoint, angle: CGFloat, length: CGFloat, width: CGFloat, color: NSColor) {
        let end = NSPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
        let hand = NSBezierPath()
        hand.move(to: center)
        hand.line(to: end)
        hand.lineWidth = width
        hand.lineCapStyle = .round
        color.setStroke()
        hand.stroke()
    }
}
