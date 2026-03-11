import Cocoa

extension NSWindow {
    /// Animates window resize while keeping the top-left corner anchored (classic System Preferences behavior)
    func animateResize(to newSize: NSSize, duration: TimeInterval = AppConstants.animationDuration) {
        let currentFrame = frame
        let newOriginY = currentFrame.origin.y + (currentFrame.size.height - newSize.height)
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: newOriginY,
            width: newSize.width,
            height: newSize.height
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: true)
        }
    }
}
