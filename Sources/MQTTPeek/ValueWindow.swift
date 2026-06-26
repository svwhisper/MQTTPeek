import AppKit

/// Borderless windows can't become key by default; allow it so the right-click menu works.
final class ValueWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// The frameless, draggable, optionally always-on-top window that shows the topic value.
final class ValueWindowController: NSObject, NSWindowDelegate {
    enum DotState { case disconnected, connecting, connected }

    private let window: ValueWindow
    private let backdrop = NSVisualEffectView()
    private let valueLabel = NSTextField(labelWithString: "—")
    private let captionLabel = NSTextField(labelWithString: "")
    private let dot = NSView()

    private var fontSize: CGFloat = 28
    private var captionVisible = true

    override init() {
        window = ValueWindow(contentRect: NSRect(x: 0, y: 0, width: 160, height: 80),
                             styleMask: [.borderless],
                             backing: .buffered,
                             defer: false)
        super.init()

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.delegate = self

        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = 12
        backdrop.layer?.masksToBounds = true
        backdrop.autoresizingMask = [.width, .height]

        valueLabel.alignment = .center
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.maximumNumberOfLines = 1
        valueLabel.textColor = .labelColor
        valueLabel.font = .systemFont(ofSize: fontSize, weight: .semibold)

        captionLabel.alignment = .center
        captionLabel.lineBreakMode = .byTruncatingMiddle
        captionLabel.maximumNumberOfLines = 1
        captionLabel.textColor = .secondaryLabelColor
        captionLabel.font = .systemFont(ofSize: 10, weight: .regular)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.frame = NSRect(x: 8, y: 8, width: 8, height: 8)
        setDot(.disconnected)

        backdrop.addSubview(captionLabel)
        backdrop.addSubview(valueLabel)
        backdrop.addSubview(dot)
        window.contentView = backdrop

        resizeToFit()
        if let origin = Prefs.windowOrigin {
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }
    }

    // MARK: - Public API used by AppDelegate

    func show() {
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    func setContextMenu(_ menu: NSMenu) {
        backdrop.menu = menu
        valueLabel.menu = menu
        captionLabel.menu = menu
    }

    func setAlwaysOnTop(_ on: Bool) {
        window.level = on ? .floating : .normal
    }

    func setFontSize(_ size: CGFloat) {
        fontSize = size
        valueLabel.font = .systemFont(ofSize: size, weight: .semibold)
        resizeToFit()
    }

    func setShowCaption(_ show: Bool) {
        captionVisible = show
        captionLabel.isHidden = !show
        resizeToFit()
    }

    func setTopic(_ topic: String) {
        captionLabel.stringValue = topic
        resizeToFit()
    }

    func setValue(_ value: String) {
        valueLabel.stringValue = value.isEmpty ? "—" : value
        resizeToFit()
    }

    func setDot(_ state: DotState) {
        let color: NSColor
        switch state {
        case .connected:    color = .systemGreen
        case .connecting:   color = .systemYellow
        case .disconnected: color = .systemRed
        }
        dot.layer?.backgroundColor = color.cgColor
    }

    // MARK: - Layout

    private func resizeToFit() {
        let padX: CGFloat = 18, padY: CGFloat = 12, gap: CGFloat = 3
        valueLabel.sizeToFit()
        captionLabel.sizeToFit()

        let vSize = valueLabel.frame.size
        let showCap = captionVisible && !captionLabel.stringValue.isEmpty
        let cSize = showCap ? captionLabel.frame.size : .zero

        let contentW = max(vSize.width, cSize.width)
        let w = max(70, min(520, contentW + padX * 2))
        let h = padY * 2 + vSize.height + (showCap ? cSize.height + gap : 0)

        // Grow from a stable top-left corner.
        let old = window.frame
        let topLeft = CGPoint(x: old.minX, y: old.maxY)
        window.setFrame(NSRect(x: topLeft.x, y: topLeft.y - h, width: w, height: h), display: true)

        if showCap {
            captionLabel.frame = NSRect(x: (w - cSize.width) / 2,
                                        y: h - padY - cSize.height,
                                        width: cSize.width, height: cSize.height)
        }
        valueLabel.frame = NSRect(x: (w - vSize.width) / 2,
                                  y: padY,
                                  width: vSize.width, height: vSize.height)
        dot.frame = NSRect(x: 8, y: h - 8 - 8, width: 8, height: 8)
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        Prefs.windowOrigin = window.frame.origin
    }
}
