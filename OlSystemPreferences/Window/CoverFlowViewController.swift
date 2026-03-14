import Cocoa
import QuartzCore
import Quartz

protocol CoverFlowViewControllerDelegate: AnyObject {
    func coverFlowDidRequestOpen(_ controller: CoverFlowViewController, url: URL)
}

/// Cover Flow file browser — 3D carousel with file list, Quick Look preview, and thumbnail generation,
/// matching Finder's classic Cover Flow view from Mac OS X.
class CoverFlowViewController: NSViewController {

    weak var delegate: CoverFlowViewControllerDelegate?

    // MARK: - Data

    private var files: [FileEntry] = []
    private var selectedIndex: Int = 0
    private var currentDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    private var typeSelectBuffer: String = ""
    private var typeSelectTimer: Timer?

    private struct FileEntry {
        let url: URL
        let name: String
        let icon: NSImage
        let isDirectory: Bool
        let fileSize: Int64
        let dateModified: Date?
        let kind: String
        var thumbnail: NSImage?
    }

    // MARK: - Cover Flow Layer

    private var cardLayers: [CALayer] = []
    private var containerLayer = CATransformLayer()

    // MARK: - UI Components

    // Top: path bar
    private let pathLabel = NSTextField(labelWithString: "")

    // Middle: coverflow area (the layer-backed dark area)
    private let coverFlowArea = NSView()

    // Divider
    private let dividerView = NSView()

    // Bottom: file list table
    private let fileTable = NSTableView()
    private let fileTableScroll = NSScrollView()

    // Status bar
    private let statusLabel = NSTextField(labelWithString: "")

    // Scrub slider
    private let scrubSlider = NSSlider()

    // MARK: - Resizable divider

    private var coverFlowHeightConstraint: NSLayoutConstraint!
    private let coverFlowMinHeight: CGFloat = 140
    private let fileListMinHeight: CGFloat = 60
    private var isDraggingDivider = false
    private var dividerTrackingArea: NSTrackingArea?
    /// Proportion of total view height allocated to the CoverFlow area (0..1).
    /// Updated on divider drag; used to maintain ratio on window resize.
    private var coverFlowHeightRatio: CGFloat = 0.45
    private var lastViewHeight: CGFloat = 0

    // MARK: - Load View

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        // --- Cover Flow area (dark, layer-backed for 3D) ---
        coverFlowArea.translatesAutoresizingMaskIntoConstraints = false
        coverFlowArea.wantsLayer = true
        coverFlowArea.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor
        view.addSubview(coverFlowArea)

        // Path bar inside coverflow area
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.font = SnowLeopardFonts.label(size: 11)
        pathLabel.textColor = NSColor(white: 0.5, alpha: 1.0)
        pathLabel.alignment = .center
        pathLabel.backgroundColor = .clear
        pathLabel.isBezeled = false
        pathLabel.isEditable = false
        coverFlowArea.addSubview(pathLabel)

        // 3D container
        containerLayer = CATransformLayer()
        var perspective = CATransform3DIdentity
        perspective.m34 = CoverFlowConstants.perspectiveDepth
        containerLayer.sublayerTransform = perspective
        coverFlowArea.layer?.addSublayer(containerLayer)

        // Scrub slider at bottom of coverflow area
        scrubSlider.translatesAutoresizingMaskIntoConstraints = false
        scrubSlider.minValue = 0
        scrubSlider.maxValue = 1
        scrubSlider.isContinuous = true
        scrubSlider.target = self
        scrubSlider.action = #selector(scrubChanged(_:))
        scrubSlider.controlSize = .small
        coverFlowArea.addSubview(scrubSlider)

        // --- Divider (draggable resize handle) ---
        dividerView.translatesAutoresizingMaskIntoConstraints = false
        dividerView.wantsLayer = true
        dividerView.layer?.backgroundColor = NSColor(white: 0.35, alpha: 1.0).cgColor
        view.addSubview(dividerView)

        // Grip dots in center of divider
        let gripDot = NSView()
        gripDot.translatesAutoresizingMaskIntoConstraints = false
        gripDot.wantsLayer = true
        gripDot.layer?.backgroundColor = NSColor(white: 0.55, alpha: 1.0).cgColor
        gripDot.layer?.cornerRadius = 1.5
        dividerView.addSubview(gripDot)
        NSLayoutConstraint.activate([
            gripDot.centerXAnchor.constraint(equalTo: dividerView.centerXAnchor),
            gripDot.centerYAnchor.constraint(equalTo: dividerView.centerYAnchor),
            gripDot.widthAnchor.constraint(equalToConstant: 36),
            gripDot.heightAnchor.constraint(equalToConstant: 3),
        ])

        // --- File list table ---
        fileTableScroll.translatesAutoresizingMaskIntoConstraints = false
        fileTableScroll.hasVerticalScroller = true
        fileTableScroll.borderType = .noBorder
        fileTableScroll.drawsBackground = true
        fileTableScroll.backgroundColor = .white

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 260
        nameCol.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        fileTable.addTableColumn(nameCol)

        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateCol.title = "Date Modified"
        dateCol.width = 160
        fileTable.addTableColumn(dateCol)

        let sizeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeCol.title = "Size"
        sizeCol.width = 80
        fileTable.addTableColumn(sizeCol)

        let kindCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("kind"))
        kindCol.title = "Kind"
        kindCol.width = 130
        fileTable.addTableColumn(kindCol)

        fileTable.delegate = self
        fileTable.dataSource = self
        fileTable.rowHeight = 20
        fileTable.usesAlternatingRowBackgroundColors = true
        fileTable.allowsMultipleSelection = false
        fileTable.doubleAction = #selector(tableDoubleClicked(_:))
        fileTable.target = self
        fileTable.style = .plain

        fileTableScroll.documentView = fileTable
        view.addSubview(fileTableScroll)

        // --- Status bar ---
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = SnowLeopardFonts.label(size: 10)
        statusLabel.textColor = NSColor(white: 0.4, alpha: 1.0)
        statusLabel.alignment = .center
        statusLabel.backgroundColor = NSColor(white: 0.95, alpha: 1.0)
        statusLabel.drawsBackground = true
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        view.addSubview(statusLabel)

        // --- Layout ---
        // Initial height set to 45% of parent; viewDidLayout will maintain ratio on resize
        coverFlowHeightConstraint = coverFlowArea.heightAnchor.constraint(equalToConstant: 280)
        coverFlowHeightRatio = 0.45

        NSLayoutConstraint.activate([
            // Cover flow area
            coverFlowArea.topAnchor.constraint(equalTo: view.topAnchor),
            coverFlowArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            coverFlowArea.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            coverFlowHeightConstraint,

            // Path bar
            pathLabel.topAnchor.constraint(equalTo: coverFlowArea.topAnchor, constant: 6),
            pathLabel.centerXAnchor.constraint(equalTo: coverFlowArea.centerXAnchor),
            pathLabel.widthAnchor.constraint(lessThanOrEqualTo: coverFlowArea.widthAnchor, constant: -40),

            // Scrub slider
            scrubSlider.bottomAnchor.constraint(equalTo: coverFlowArea.bottomAnchor, constant: -6),
            scrubSlider.centerXAnchor.constraint(equalTo: coverFlowArea.centerXAnchor),
            scrubSlider.widthAnchor.constraint(equalTo: coverFlowArea.widthAnchor, multiplier: 0.6),

            // Divider
            dividerView.topAnchor.constraint(equalTo: coverFlowArea.bottomAnchor),
            dividerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dividerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dividerView.heightAnchor.constraint(equalToConstant: 8),

            // File table
            fileTableScroll.topAnchor.constraint(equalTo: dividerView.bottomAnchor),
            fileTableScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fileTableScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fileTableScroll.bottomAnchor.constraint(equalTo: statusLabel.topAnchor),

            // Status bar
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statusLabel.heightAnchor.constraint(equalToConstant: 22),
        ])

        loadDirectory(currentDirectory)
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        let totalHeight = view.bounds.height
        // On window resize (not divider drag), scale CoverFlow height proportionally
        if !isDraggingDivider && totalHeight > 0 && lastViewHeight > 0 && abs(totalHeight - lastViewHeight) > 1 {
            let maxH = totalHeight - fileListMinHeight - 30
            let newHeight = min(max(totalHeight * coverFlowHeightRatio, coverFlowMinHeight), maxH)
            coverFlowHeightConstraint.constant = newHeight
        }
        lastViewHeight = totalHeight

        let area = coverFlowArea.bounds
        containerLayer.frame = CGRect(x: 0, y: 30, width: area.width, height: area.height - 60)
        updateLayout(animated: false)
        updateDividerTrackingArea()
    }

    // MARK: - Directory Loading

    func loadDirectory(_ url: URL) {
        currentDirectory = url
        pathLabel.stringValue = url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")

        files.removeAll()
        cardLayers.forEach { $0.removeFromSuperlayer() }
        cardLayers.removeAll()

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let sorted = contents.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }

        for fileURL in sorted {
            let rv = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .localizedTypeDescriptionKey])
            let isDir = rv?.isDirectory ?? false
            let fileSize = Int64(rv?.fileSize ?? 0)
            let dateMod = rv?.contentModificationDate
            let kind = rv?.localizedTypeDescription ?? (isDir ? "Folder" : "Document")

            // Generate thumbnail for image files, fall back to icon
            let thumbnail = generateThumbnail(for: fileURL)
            let icon = thumbnail ?? NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = NSSize(width: 256, height: 256)

            files.append(FileEntry(
                url: fileURL, name: fileURL.lastPathComponent, icon: icon,
                isDirectory: isDir, fileSize: fileSize, dateModified: dateMod,
                kind: kind, thumbnail: thumbnail
            ))
        }

        selectedIndex = min(selectedIndex, max(files.count - 1, 0))

        for (i, file) in files.enumerated() {
            let card = makeCardLayer(for: file, index: i)
            cardLayers.append(card)
            containerLayer.addSublayer(card)
        }

        // Update scrub slider
        scrubSlider.maxValue = max(Double(files.count - 1), 0)
        scrubSlider.doubleValue = Double(selectedIndex)
        scrubSlider.isEnabled = files.count > 1

        fileTable.reloadData()
        updateStatusBar()
        updateLayout(animated: false)
        syncTableSelection()
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(for url: URL) -> NSImage? {
        let ext = url.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "gif", "tiff", "tif", "bmp", "heic", "webp"]
        let previewExts = imageExts + ["pdf"]

        guard previewExts.contains(ext) else { return nil }

        // Use QuickLook thumbnail generator
        if let cgRef = QLThumbnailImageCreate(
            kCFAllocatorDefault,
            url as CFURL,
            CGSize(width: 256, height: 256),
            nil
        ) {
            let thumbnail = cgRef.takeRetainedValue()
            return NSImage(cgImage: thumbnail, size: NSSize(width: 256, height: 256))
        }

        // Fallback for images: load directly
        if imageExts.contains(ext), let img = NSImage(contentsOf: url) {
            return img
        }

        return nil
    }

    // MARK: - Card Layer Construction

    private func makeCardLayer(for file: FileEntry, index: Int) -> CALayer {
        let cardSize = CoverFlowConstants.cardSize
        let card = CALayer()
        card.frame = CGRect(x: 0, y: 0, width: cardSize.width, height: cardSize.height)
        card.cornerRadius = 4
        card.masksToBounds = false

        let hasThumbnail = file.thumbnail != nil
        if hasThumbnail {
            // White border for image thumbnails (like photo prints)
            card.backgroundColor = NSColor.white.cgColor
            card.borderWidth = 2
            card.borderColor = NSColor(white: 0.85, alpha: 1.0).cgColor
        } else {
            card.backgroundColor = NSColor(white: 0.18, alpha: 1.0).cgColor
            card.borderWidth = 1
            card.borderColor = NSColor(white: 0.3, alpha: 0.5).cgColor
        }

        card.shadowColor = NSColor.black.cgColor
        card.shadowOpacity = 0.6
        card.shadowOffset = CGSize(width: 0, height: -6)
        card.shadowRadius = 10

        // Content (icon or thumbnail)
        let contentLayer = CALayer()
        if hasThumbnail {
            // Full-bleed thumbnail
            let inset: CGFloat = 4
            contentLayer.frame = CGRect(x: inset, y: inset, width: cardSize.width - inset * 2, height: cardSize.height - inset * 2)
            contentLayer.contents = file.thumbnail
            contentLayer.contentsGravity = .resizeAspectFill
            contentLayer.masksToBounds = true
        } else {
            // Centered icon
            let iconSize: CGFloat = cardSize.width * 0.6
            contentLayer.frame = CGRect(
                x: (cardSize.width - iconSize) / 2,
                y: (cardSize.height - iconSize) / 2 + 12,
                width: iconSize, height: iconSize
            )
            contentLayer.contents = file.icon
            contentLayer.contentsGravity = .resizeAspect
        }
        contentLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        card.addSublayer(contentLayer)

        // File name label (only for non-thumbnail cards)
        if !hasThumbnail {
            let textLayer = CATextLayer()
            textLayer.string = file.name
            textLayer.fontSize = 10
            textLayer.font = NSFont(name: "Lucida Grande", size: 10)
            textLayer.foregroundColor = NSColor.white.cgColor
            textLayer.alignmentMode = .center
            textLayer.truncationMode = .end
            textLayer.isWrapped = false
            textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            textLayer.frame = CGRect(x: 4, y: 8, width: cardSize.width - 8, height: 16)
            card.addSublayer(textLayer)
        }

        // Reflection
        let reflectionHeight = cardSize.height * 0.4
        let reflection = CALayer()
        reflection.frame = CGRect(x: 0, y: -reflectionHeight - 1, width: cardSize.width, height: reflectionHeight)
        reflection.contents = card.contents
        reflection.transform = CATransform3DMakeScale(1, -1, 1)
        reflection.opacity = 0.15
        reflection.cornerRadius = card.cornerRadius

        if hasThumbnail {
            // Mirror the thumbnail content
            let reflContent = CALayer()
            reflContent.frame = CGRect(x: 0, y: 0, width: cardSize.width, height: reflectionHeight)
            reflContent.contents = file.thumbnail
            reflContent.contentsGravity = .resizeAspectFill
            reflContent.masksToBounds = true
            reflection.addSublayer(reflContent)
        } else {
            reflection.backgroundColor = card.backgroundColor
        }

        let gradientMask = CAGradientLayer()
        gradientMask.frame = reflection.bounds
        gradientMask.colors = [NSColor.white.cgColor, NSColor.clear.cgColor]
        gradientMask.startPoint = CGPoint(x: 0.5, y: 0.3)
        gradientMask.endPoint = CGPoint(x: 0.5, y: 0)
        reflection.mask = gradientMask
        card.addSublayer(reflection)

        return card
    }

    // MARK: - Layout

    private func updateLayout(animated: Bool) {
        guard !files.isEmpty else {
            statusLabel.stringValue = "0 items"
            return
        }

        let duration = animated ? CoverFlowConstants.animationDuration : 0
        let containerWidth = containerLayer.bounds.width
        let containerHeight = containerLayer.bounds.height
        let centerX = containerWidth / 2
        let centerY = containerHeight / 2
        let sideAngle = CoverFlowConstants.sideCardAngle

        // Scale card size proportionally with container height (reference: 200pt at 220pt container)
        let baseContainerH: CGFloat = 220
        let scaleFactor = max(0.6, min(1.5, containerHeight / baseContainerH))
        let baseCardSize = CoverFlowConstants.cardSize
        let cardW = baseCardSize.width * scaleFactor
        let cardH = baseCardSize.height * scaleFactor

        // Scale spacing proportionally with container width (reference: 768pt window)
        let baseWidth: CGFloat = 768
        let widthRatio = max(0.7, containerWidth / baseWidth)
        let sideSpacing: CGFloat = 50 * widthRatio   // spacing between side cards
        let centerGap: CGFloat = 110 * widthRatio     // gap between center card and first side card
        let depthStep: CGFloat = 15 * widthRatio      // z-depth step per card

        // Show more side cards when wider
        let maxVisible = max(6, Int(containerWidth / (sideSpacing * 2)))

        CATransaction.begin()
        CATransaction.setAnimationDuration(duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))

        for (i, card) in cardLayers.enumerated() {
            let offset = i - selectedIndex
            let absOffset = abs(offset)

            card.isHidden = absOffset > maxVisible

            guard absOffset <= maxVisible else { continue }

            // Scale entire card (preserves sublayer positions)
            var transform = CATransform3DScale(CATransform3DIdentity, scaleFactor, scaleFactor, 1)

            if offset == 0 {
                card.position = CGPoint(x: centerX, y: centerY)
                card.zPosition = 10
                card.opacity = 1.0
            } else if offset < 0 {
                let x = centerX - CGFloat(-offset) * sideSpacing - centerGap
                transform = CATransform3DRotate(transform, sideAngle, 0, 1, 0)
                transform = CATransform3DTranslate(transform, 0, 0, CGFloat(-absOffset) * depthStep)
                card.position = CGPoint(x: x, y: centerY)
                card.zPosition = CGFloat(-absOffset)
                card.opacity = absOffset <= 4 ? 1.0 : Float(1.0 - Double(absOffset - 4) * 0.3)
            } else {
                let x = centerX + CGFloat(offset) * sideSpacing + centerGap
                transform = CATransform3DRotate(transform, -sideAngle, 0, 1, 0)
                transform = CATransform3DTranslate(transform, 0, 0, CGFloat(-absOffset) * depthStep)
                card.position = CGPoint(x: x, y: centerY)
                card.zPosition = CGFloat(-absOffset)
                card.opacity = absOffset <= 4 ? 1.0 : Float(1.0 - Double(absOffset - 4) * 0.3)
            }

            card.transform = transform
        }

        CATransaction.commit()

        // Update scrub slider position
        scrubSlider.doubleValue = Double(selectedIndex)
    }

    private func updateStatusBar() {
        let count = files.count
        if count == 0 {
            statusLabel.stringValue = "0 items"
        } else if count == 1 {
            statusLabel.stringValue = "1 item"
        } else {
            statusLabel.stringValue = "\(count) items"
        }
    }

    private func syncTableSelection() {
        guard selectedIndex >= 0, selectedIndex < files.count else { return }
        fileTable.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        fileTable.scrollRowToVisible(selectedIndex)
    }

    // MARK: - Navigation

    func selectPrevious() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
        SoundService.playNavigate()
        updateLayout(animated: true)
        syncTableSelection()
        syncQuickLookSelection()
    }

    func selectNext() {
        guard selectedIndex < files.count - 1 else { return }
        selectedIndex += 1
        SoundService.playNavigate()
        updateLayout(animated: true)
        syncTableSelection()
        syncQuickLookSelection()
    }

    func openSelected() {
        guard selectedIndex >= 0 && selectedIndex < files.count else { return }
        let file = files[selectedIndex]
        SoundService.playClick()
        if file.isDirectory {
            selectedIndex = 0
            loadDirectory(file.url)
        } else {
            NSWorkspace.shared.open(file.url)
        }
    }

    func navigateUp() {
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent != currentDirectory else { return }
        SoundService.playNavigate()
        selectedIndex = 0
        loadDirectory(parent)
    }

    func navigateIntoSelected() {
        guard selectedIndex >= 0 && selectedIndex < files.count else { return }
        let file = files[selectedIndex]
        if file.isDirectory {
            SoundService.playNavigate()
            selectedIndex = 0
            loadDirectory(file.url)
        }
    }

    // MARK: - Quick Look Preview

    private var quickLookOpen: Bool {
        guard let panel = QLPreviewPanel.shared() else { return false }
        return panel.isVisible
    }

    private func toggleQuickLookPreview() {
        guard !files.isEmpty else { return }

        if let panel = QLPreviewPanel.shared() {
            if panel.isVisible {
                panel.orderOut(nil)
            } else {
                panel.center()
                panel.updateController()
                panel.delegate = self
                panel.dataSource = self
                panel.reloadData()
                panel.currentPreviewItemIndex = selectedIndex
                panel.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Called when the CoverFlow selection changes while Quick Look is open —
    /// keeps the panel in sync with the carousel.
    private func syncQuickLookSelection() {
        guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
        if panel.currentPreviewItemIndex != selectedIndex {
            panel.currentPreviewItemIndex = selectedIndex
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = self
        panel.dataSource = self
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        // No-op
    }

    // MARK: - Type-to-Select

    private func handleTypeSelect(character: String) {
        typeSelectTimer?.invalidate()
        typeSelectBuffer += character.lowercased()

        // Find first file matching the typed prefix
        if let idx = files.firstIndex(where: { $0.name.lowercased().hasPrefix(typeSelectBuffer) }) {
            selectedIndex = idx
            updateLayout(animated: true)
            syncTableSelection()
        }

        // Reset buffer after 0.8s of no typing
        typeSelectTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.typeSelectBuffer = ""
        }
    }

    // MARK: - Key Handling

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: selectPrevious()              // Left arrow
        case 124: selectNext()                  // Right arrow
        case 36, 76: openSelected()             // Return / Enter
        case 126: navigateUp()                  // Up arrow
        case 125: navigateIntoSelected()        // Down arrow — enter directory
        case 49: toggleQuickLookPreview()        // Spacebar — Quick Look toggle
        case 53:                                 // Escape — close Quick Look if open
            if quickLookOpen {
                QLPreviewPanel.shared()?.orderOut(nil)
            } else {
                super.keyDown(with: event)
            }
        case 51:                                 // Delete — navigate up
            navigateUp()
        default:
            // Type-to-select for printable characters
            if let chars = event.characters, !chars.isEmpty,
               event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                let ch = chars.first!
                if ch.isLetter || ch.isNumber || ch == "." || ch == " " {
                    handleTypeSelect(character: String(ch))
                    return
                }
            }
            super.keyDown(with: event)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Scroll Wheel

    private var scrollAccumulator: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        // Horizontal scroll (trackpad swipe) is primary; also accept vertical
        let delta = event.scrollingDeltaX != 0 ? -event.scrollingDeltaX : event.scrollingDeltaY
        scrollAccumulator += delta

        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 30 : 2

        while scrollAccumulator > threshold {
            scrollAccumulator -= threshold
            selectNext()
        }
        while scrollAccumulator < -threshold {
            scrollAccumulator += threshold
            selectPrevious()
        }

        // Decay for precise scrolling
        if event.phase == .ended || event.phase == .cancelled {
            scrollAccumulator = 0
        }
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let viewLoc = view.convert(event.locationInWindow, from: nil)

        // Check divider drag first (in view coordinates)
        let dividerFrame = dividerView.frame
        let grabZone = dividerFrame.insetBy(dx: 0, dy: -4)
        if grabZone.contains(viewLoc) {
            isDraggingDivider = true
            NSCursor.resizeUpDown.push()
            return
        }

        // Card hit-testing (in layer coordinates)
        let location = view.layer?.convert(viewLoc, to: containerLayer) ?? .zero

        for (i, card) in cardLayers.enumerated() {
            guard !card.isHidden else { continue }
            if card.frame.contains(location) {
                if i == selectedIndex {
                    if event.clickCount >= 2 {
                        openSelected()
                    }
                } else {
                    selectedIndex = i
                    SoundService.playClick()
                    updateLayout(animated: true)
                    syncTableSelection()
                    syncQuickLookSelection()
                }
                return
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDraggingDivider else { return }
        let totalHeight = view.bounds.height
        let maxHeight = totalHeight - fileListMinHeight - 30 // 30 = divider + status bar
        // deltaY: positive = mouse up, negative = mouse down (screen coords Y-up)
        // Drag divider down → increase CoverFlow height → subtract deltaY (which is negative)
        let newHeight = min(max(coverFlowHeightConstraint.constant - event.deltaY, coverFlowMinHeight), maxHeight)
        coverFlowHeightConstraint.constant = newHeight

        // Update ratio so window resize maintains this proportion
        if totalHeight > 0 {
            coverFlowHeightRatio = newHeight / totalHeight
        }

        // Force layout pass so coverFlowArea.bounds is up to date
        view.layoutSubtreeIfNeeded()

        // Relayout the 3D container immediately
        let area = coverFlowArea.bounds
        containerLayer.frame = CGRect(x: 0, y: 30, width: area.width, height: area.height - 60)
        updateLayout(animated: false)
    }

    override func mouseUp(with event: NSEvent) {
        if isDraggingDivider {
            isDraggingDivider = false
            NSCursor.pop()
        }
    }

    // MARK: - Cursor tracking for divider

    private func updateDividerTrackingArea() {
        if let existing = dividerTrackingArea {
            view.removeTrackingArea(existing)
        }
        let dividerFrame = dividerView.frame
        guard dividerFrame.width > 0 else { return }
        let trackRect = dividerFrame.insetBy(dx: 0, dy: -4)
        dividerTrackingArea = NSTrackingArea(
            rect: trackRect,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(dividerTrackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeUpDown.set()
    }

    override func mouseExited(with event: NSEvent) {
        if !isDraggingDivider {
            NSCursor.arrow.set()
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        let viewLoc = view.convert(event.locationInWindow, from: nil)
        let dividerFrame = dividerView.frame
        let grabZone = dividerFrame.insetBy(dx: 0, dy: -4)
        if grabZone.contains(viewLoc) || isDraggingDivider {
            NSCursor.resizeUpDown.set()
        }
    }

    // MARK: - Scrub Slider

    @objc private func scrubChanged(_ sender: NSSlider) {
        let newIndex = max(0, min(files.count - 1, Int(sender.doubleValue.rounded())))
        guard newIndex != selectedIndex else { return }
        selectedIndex = newIndex
        updateLayout(animated: false)
        syncTableSelection()
        syncQuickLookSelection()
    }

    // MARK: - Table Double Click

    @objc private func tableDoubleClicked(_ sender: Any?) {
        let row = fileTable.clickedRow
        guard row >= 0, row < files.count else { return }
        selectedIndex = row
        openSelected()
    }

    // MARK: - Formatting Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}

// MARK: - NSTableViewDataSource & Delegate

extension CoverFlowViewController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return files.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = files[row]
        let colID = tableColumn?.identifier.rawValue ?? ""

        switch colID {
        case "name":
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let iconView = NSImageView()
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.image = NSWorkspace.shared.icon(forFile: file.url.path)
            iconView.imageScaling = .scaleProportionallyUpOrDown
            container.addSubview(iconView)

            let label = NSTextField(labelWithString: file.name)
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = SnowLeopardFonts.label(size: 11)
            label.textColor = NSColor(white: 0.1, alpha: 1.0)
            label.lineBreakMode = .byTruncatingTail
            container.addSubview(label)

            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 16),
                iconView.heightAnchor.constraint(equalToConstant: 16),
                label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 4),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -2),
            ])
            return container

        case "date":
            let dateStr: String
            if let date = file.dateModified {
                dateStr = CoverFlowViewController.dateFormatter.string(from: date)
            } else {
                dateStr = "--"
            }
            let cell = NSTextField(labelWithString: dateStr)
            cell.font = SnowLeopardFonts.label(size: 11)
            cell.textColor = .secondaryLabelColor
            return cell

        case "size":
            let sizeStr: String
            if file.isDirectory {
                sizeStr = "--"
            } else {
                sizeStr = CoverFlowViewController.sizeFormatter.string(fromByteCount: file.fileSize)
            }
            let cell = NSTextField(labelWithString: sizeStr)
            cell.font = SnowLeopardFonts.label(size: 11)
            cell.textColor = .secondaryLabelColor
            cell.alignment = .right
            return cell

        case "kind":
            let cell = NSTextField(labelWithString: file.kind)
            cell.font = SnowLeopardFonts.label(size: 11)
            cell.textColor = .secondaryLabelColor
            return cell

        default:
            return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = fileTable.selectedRow
        guard row >= 0, row < files.count, row != selectedIndex else { return }
        selectedIndex = row
        updateLayout(animated: true)
        syncQuickLookSelection()
    }
}

// MARK: - QLPreviewPanelDataSource & Delegate

extension CoverFlowViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return files.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        guard index >= 0, index < files.count else { return nil }
        return files[index].url as NSURL
    }

    /// When the user navigates inside the Quick Look panel (left/right arrows, or the
    /// built-in navigation buttons), QL updates currentPreviewItemIndex and calls this
    /// so we can sync the CoverFlow carousel and file list.
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard let event = event else { return false }

        if event.type == .keyDown {
            switch event.keyCode {
            case 123: // Left arrow — previous file in Quick Look
                if selectedIndex > 0 {
                    selectedIndex -= 1
                    updateLayout(animated: true)
                    syncTableSelection()
                    panel.currentPreviewItemIndex = selectedIndex
                }
                return true
            case 124: // Right arrow — next file in Quick Look
                if selectedIndex < files.count - 1 {
                    selectedIndex += 1
                    updateLayout(animated: true)
                    syncTableSelection()
                    panel.currentPreviewItemIndex = selectedIndex
                }
                return true
            case 126: // Up arrow — navigate up a directory
                navigateUp()
                panel.reloadData()
                if !files.isEmpty {
                    panel.currentPreviewItemIndex = selectedIndex
                }
                return true
            case 125: // Down arrow — enter directory
                let prevDir = currentDirectory
                navigateIntoSelected()
                if currentDirectory != prevDir {
                    panel.reloadData()
                    if !files.isEmpty {
                        panel.currentPreviewItemIndex = selectedIndex
                    }
                }
                return true
            case 49: // Spacebar — close Quick Look
                panel.orderOut(nil)
                return true
            case 53: // Escape — close Quick Look
                panel.orderOut(nil)
                return true
            case 36, 76: // Return/Enter — open the file
                panel.orderOut(nil)
                openSelected()
                return true
            default:
                break
            }
        }

        return false
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: (any QLPreviewItem)!) -> NSRect {
        // Determine which card corresponds to the item
        let idx = panel.currentPreviewItemIndex
        guard idx >= 0, idx < cardLayers.count else { return .zero }
        let card = cardLayers[idx]

        // Convert card frame through the layer tree to window coordinates
        guard let windowLayer = view.layer else { return .zero }
        let cardFrame = containerLayer.convert(card.frame, to: windowLayer)

        // Convert from layer coords to view coords, then to screen
        let viewFrame = NSRect(origin: cardFrame.origin, size: cardFrame.size)
        let windowFrame = coverFlowArea.convert(viewFrame, to: nil)
        if let window = view.window {
            return window.convertToScreen(windowFrame)
        }
        return .zero
    }

    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: (any QLPreviewItem)!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        let idx = panel.currentPreviewItemIndex
        guard idx >= 0, idx < files.count else { return nil }
        return files[idx].icon
    }
}
