import Cocoa
import IOKit

class AboutWindowController: NSWindowController {

    private var clickCount = 0

    private let versionLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = SnowLeopardFonts.label(size: 11)
        tf.textColor = .secondaryLabelColor
        tf.alignment = .center
        return tf
    }()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About This Mac"
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = SnowLeopardColors.gridBackground
        window.center()

        self.init(window: window)
        setupContent()
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 30, bottom: 24, right: 30)

        // App icon
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 64).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 64).isActive = true
        stack.addArrangedSubview(iconView)

        // "Mac OS X" title
        let titleLabel = NSTextField(labelWithString: "Mac OS X")
        titleLabel.font = SnowLeopardFonts.boldLabel(size: 18)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        stack.addArrangedSubview(titleLabel)

        // Snow Leopard subtitle
        let subtitleLabel = NSTextField(labelWithString: "Snow Leopard")
        subtitleLabel.font = SnowLeopardFonts.label(size: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.alignment = .center
        stack.addArrangedSubview(subtitleLabel)

        // Version label (clickable to cycle)
        updateVersionLabel()
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(versionClicked(_:)))
        versionLabel.addGestureRecognizer(clickGesture)
        stack.addArrangedSubview(versionLabel)

        // Separator
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 260).isActive = true
        stack.addArrangedSubview(separator)

        stack.setCustomSpacing(16, after: separator)

        // Hardware info
        let processorLabel = makeInfoLabel("Processor", value: cpuBrandString())
        let memoryLabel = makeInfoLabel("Memory", value: memoryString())
        let startupLabel = makeInfoLabel("Startup Disk", value: startupDiskName())
        let serialLabel = makeInfoLabel("Serial Number", value: serialNumber())

        stack.addArrangedSubview(processorLabel)
        stack.addArrangedSubview(memoryLabel)
        stack.addArrangedSubview(startupLabel)
        stack.addArrangedSubview(serialLabel)

        stack.setCustomSpacing(20, after: serialLabel)

        // Buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12

        let softwareUpdateButton = NSButton(title: "Software Update...", target: self, action: #selector(openSoftwareUpdate(_:)))
        softwareUpdateButton.font = SnowLeopardFonts.label(size: 11)
        let moreInfoButton = NSButton(title: "More Info...", target: self, action: #selector(openSystemInfo(_:)))
        moreInfoButton.font = SnowLeopardFonts.label(size: 11)

        buttonRow.addArrangedSubview(softwareUpdateButton)
        buttonRow.addArrangedSubview(moreInfoButton)
        stack.addArrangedSubview(buttonRow)

        // Copyright
        let copyrightLabel = NSTextField(labelWithString: "TM and \u{00A9} 1983-2009 Apple Inc.\nAll Rights Reserved.")
        copyrightLabel.font = SnowLeopardFonts.label(size: 9)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        copyrightLabel.maximumNumberOfLines = 2
        stack.addArrangedSubview(copyrightLabel)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])
    }

    private func makeInfoLabel(_ label: String, value: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 8

        let nameField = NSTextField(labelWithString: "\(label):")
        nameField.font = SnowLeopardFonts.boldLabel(size: 11)
        nameField.textColor = .labelColor
        nameField.alignment = .right
        nameField.widthAnchor.constraint(equalToConstant: 100).isActive = true

        let valueField = NSTextField(labelWithString: value)
        valueField.font = SnowLeopardFonts.label(size: 11)
        valueField.textColor = .secondaryLabelColor
        valueField.lineBreakMode = .byTruncatingTail
        valueField.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true

        row.addArrangedSubview(nameField)
        row.addArrangedSubview(valueField)
        return row
    }

    // MARK: - Version cycling

    @objc private func versionClicked(_ sender: Any?) {
        clickCount = (clickCount + 1) % 3
        updateVersionLabel()
    }

    private func updateVersionLabel() {
        switch clickCount {
        case 0:
            versionLabel.stringValue = "Version 10.6.8"
        case 1:
            versionLabel.stringValue = "Build \(osBuildString())"
        case 2:
            versionLabel.stringValue = "Serial: \(serialNumber())"
        default:
            break
        }
    }

    // MARK: - System Info

    private func cpuBrandString() -> String {
        var size: Int = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var result = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &result, &size, nil, 0)
        return String(cString: result)
    }

    private func memoryString() -> String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb)
    }

    private func osBuildString() -> String {
        var size: Int = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var result = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &result, &size, nil, 0)
        return String(cString: result)
    }

    private func startupDiskName() -> String {
        let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey],
            options: [.skipHiddenVolumes]
        )
        if let root = mountedVolumes?.first(where: { $0.path == "/" || $0.path == "/System/Volumes/Data" }),
           let name = try? root.resourceValues(forKeys: [.volumeNameKey]).volumeName {
            return name
        }
        return "Macintosh HD"
    }

    private func serialNumber() -> String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard platformExpert != 0 else { return "Unknown" }
        defer { IOObjectRelease(platformExpert) }

        if let serialCF = IORegistryEntryCreateCFProperty(
            platformExpert,
            "IOPlatformSerialNumber" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            return serialCF
        }
        return "Unknown"
    }

    // MARK: - Actions

    @objc private func openSoftwareUpdate(_ sender: Any?) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openSystemInfo(_ sender: Any?) {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/System Information.app"))
    }
}
