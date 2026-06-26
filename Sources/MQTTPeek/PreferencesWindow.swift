import AppKit

/// Settings panel: connection details + appearance/behaviour toggles.
/// Reads current `Prefs` on open, writes them back and fires `onSave` on Save.
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    var onSave: (() -> Void)?
    var onClose: (() -> Void)?

    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let topicField = NSTextField()
    private let userField = NSTextField()
    private let passField = NSSecureTextField()
    private let tlsCheck = NSButton(checkboxWithTitle: "Use TLS / SSL", target: nil, action: nil)
    private let untrustedCheck = NSButton(checkboxWithTitle: "Allow untrusted certificate", target: nil, action: nil)

    private let alwaysOnTopCheck = NSButton(checkboxWithTitle: "Always on top", target: nil, action: nil)
    private let menuBarCheck = NSButton(checkboxWithTitle: "Show value in menu bar", target: nil, action: nil)
    private let hideWindowCheck = NSButton(checkboxWithTitle: "Hide window (menu bar only)", target: nil, action: nil)
    private let captionCheck = NSButton(checkboxWithTitle: "Show topic name under value", target: nil, action: nil)
    private let fontStepper = NSStepper()
    private let fontValueLabel = NSTextField(labelWithString: "")

    convenience init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 520),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "MQTT Peek Preferences"
        self.init(window: window)
        window.delegate = self
        window.contentView = buildForm()
        loadValues()
    }

    // MARK: - Form construction

    private func row(_ label: String, _ control: NSView) -> NSStackView {
        let l = NSTextField(labelWithString: label)
        l.alignment = .right
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let s = NSStackView(views: [l, control])
        s.orientation = .horizontal
        s.spacing = 8
        s.alignment = .firstBaseline
        return s
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let t = NSTextField(labelWithString: title)
        t.font = .boldSystemFont(ofSize: 12)
        t.textColor = .secondaryLabelColor
        return t
    }

    private func buildForm() -> NSView {
        for f in [hostField, portField, topicField, userField, passField] {
            f.translatesAutoresizingMaskIntoConstraints = false
            f.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        }
        hostField.placeholderString = "e.g. 192.168.2.5 or broker.example.com"
        portField.placeholderString = "1883"
        topicField.placeholderString = "e.g. home/sensor/temperature"
        userField.placeholderString = "optional"
        passField.placeholderString = "optional"

        tlsCheck.target = self
        tlsCheck.action = #selector(tlsToggled)
        hideWindowCheck.target = self
        hideWindowCheck.action = #selector(hideWindowToggled)

        fontStepper.minValue = 12
        fontStepper.maxValue = 80
        fontStepper.increment = 2
        fontStepper.valueWraps = false
        fontStepper.target = self
        fontStepper.action = #selector(fontStepped)
        let fontRow = NSStackView(views: [fontValueLabel, fontStepper])
        fontRow.spacing = 8

        let saveButton = NSButton(title: "Save & Connect", target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [NSView(), cancelButton, saveButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10

        let stack = NSStackView(views: [
            sectionHeader("CONNECTION"),
            row("Broker", hostField),
            row("Port", portField),
            row("Topic", topicField),
            row("Username", userField),
            row("Password", passField),
            indented(tlsCheck),
            indented(untrustedCheck),
            NSBox.separator(),
            sectionHeader("DISPLAY"),
            indented(alwaysOnTopCheck),
            indented(menuBarCheck),
            indented(hideWindowCheck),
            indented(captionCheck),
            row("Font size", fontRow),
            NSBox.separator(),
            buttons,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            buttons.trailingAnchor.constraint(equalTo: stack.trailingAnchor, constant: -20),
        ])
        return container
    }

    /// Wrap a checkbox so it aligns under the label column.
    private func indented(_ v: NSView) -> NSStackView {
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 98).isActive = true
        let s = NSStackView(views: [spacer, v])
        s.orientation = .horizontal
        s.spacing = 0
        return s
    }

    // MARK: - Load / save

    private func loadValues() {
        hostField.stringValue = Prefs.host
        portField.stringValue = String(Prefs.port)
        topicField.stringValue = Prefs.topic
        userField.stringValue = Prefs.username
        passField.stringValue = Prefs.password
        tlsCheck.state = Prefs.useTLS ? .on : .off
        untrustedCheck.state = Prefs.allowUntrusted ? .on : .off
        alwaysOnTopCheck.state = Prefs.alwaysOnTop ? .on : .off
        menuBarCheck.state = Prefs.showInMenuBar ? .on : .off
        hideWindowCheck.state = Prefs.hideWindow ? .on : .off
        captionCheck.state = Prefs.showCaption ? .on : .off
        fontStepper.integerValue = Prefs.fontSize
        syncFontLabel()
        syncDependentStates()
    }

    @objc private func save() {
        Prefs.host = hostField.stringValue.trimmingCharacters(in: .whitespaces)
        Prefs.port = Int(portField.stringValue) ?? 1883
        Prefs.topic = topicField.stringValue.trimmingCharacters(in: .whitespaces)
        Prefs.username = userField.stringValue
        Prefs.password = passField.stringValue
        Prefs.useTLS = tlsCheck.state == .on
        Prefs.allowUntrusted = untrustedCheck.state == .on
        Prefs.alwaysOnTop = alwaysOnTopCheck.state == .on
        Prefs.showInMenuBar = menuBarCheck.state == .on
        Prefs.hideWindow = hideWindowCheck.state == .on
        Prefs.showCaption = captionCheck.state == .on
        Prefs.fontSize = fontStepper.integerValue
        onSave?()
        window?.close()
    }

    @objc private func cancel() {
        window?.close()
    }

    // MARK: - Live dependency wiring

    @objc private func tlsToggled() { syncDependentStates() }

    @objc private func hideWindowToggled() {
        // Menu-bar-only mode needs the menu-bar item as the access point.
        if hideWindowCheck.state == .on { menuBarCheck.state = .on }
        syncDependentStates()
    }

    @objc private func fontStepped() { syncFontLabel() }

    private func syncFontLabel() {
        fontValueLabel.stringValue = "\(fontStepper.integerValue) pt"
    }

    private func syncDependentStates() {
        untrustedCheck.isEnabled = tlsCheck.state == .on
        // When the window is hidden, the menu-bar item is mandatory.
        menuBarCheck.isEnabled = hideWindowCheck.state != .on
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

private extension NSBox {
    /// A thin horizontal divider for the form.
    static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true
        return box
    }
}
