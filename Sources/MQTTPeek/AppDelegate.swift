import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let mqtt = MQTTManager()
    private let valueWindow = ValueWindowController()
    private var prefsController: PreferencesWindowController?
    private var statusItem: NSStatusItem?

    private var lastValue = "—"
    private var lastState: MQTTManager.State = .disconnected
    private var lastDetail: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Prefs.registerDefaults()
        buildMainMenu()

        mqtt.onValue = { [weak self] value in self?.handleValue(value) }
        mqtt.onState = { [weak self] state, detail in self?.handleState(state, detail) }

        NotificationCenter.default.addObserver(self, selector: #selector(prefsChanged),
                                               name: .prefsChanged, object: nil)

        applyAll()
        mqtt.reconnect()

        if !Prefs.isConfigured {
            openPreferences(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Applying preferences

    @objc private func prefsChanged() {
        applyAll()
        mqtt.reconnect()
    }

    private func applyAll() {
        NSApp.setActivationPolicy(Prefs.hideWindow ? .accessory : .regular)
        valueWindow.setAlwaysOnTop(Prefs.alwaysOnTop)
        valueWindow.setFontSize(CGFloat(Prefs.fontSize))
        valueWindow.setShowCaption(Prefs.showCaption)
        valueWindow.setTopic(Prefs.topic)
        valueWindow.setValue(lastValue)
        if Prefs.hideWindow { valueWindow.hide() } else { valueWindow.show() }
        applyStatusItem()
        refreshMenus()
    }

    private func applyStatusItem() {
        let want = Prefs.showInMenuBar || Prefs.hideWindow
        if want {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            }
            if let button = statusItem?.button {
                // An icon keeps the item identifiable even when the value is short.
                button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right",
                                       accessibilityDescription: "MQTT")
                button.image?.isTemplate = true
                button.imagePosition = .imageLeading
                button.title = statusBarTitle(lastValue)
                button.toolTip = headerText()
            }
            statusItem?.isVisible = true
        } else if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - MQTT callbacks

    private func handleValue(_ value: String) {
        lastValue = value
        valueWindow.setValue(value)
        statusItem?.button?.title = statusBarTitle(value)
    }

    private func handleState(_ state: MQTTManager.State, _ detail: String?) {
        lastState = state
        lastDetail = detail
        switch state {
        case .connected:    valueWindow.setDot(.connected)
        case .connecting:   valueWindow.setDot(.connecting)
        case .disconnected: valueWindow.setDot(.disconnected)
        }
        statusItem?.button?.toolTip = headerText()
        refreshMenus()
    }

    // MARK: - Menus

    private func stateText() -> String {
        switch lastState {
        case .connected:    return "connected"
        case .connecting:   return "connecting…"
        case .disconnected: return lastDetail.map { "disconnected — \($0)" } ?? "disconnected"
        }
    }

    private func headerText() -> String {
        Prefs.topic.isEmpty ? "MQTT Peek — \(stateText())" : "\(Prefs.topic) — \(stateText())"
    }

    private func statusBarTitle(_ value: String) -> String {
        let v = value.isEmpty ? "—" : value
        return v.count > 24 ? String(v.prefix(24)) + "…" : v
    }

    /// A fresh menu shared in spirit by the status item and the window's right-click menu.
    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let header = NSMenuItem(title: headerText(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let aot = NSMenuItem(title: "Always on Top", action: #selector(toggleAlwaysOnTop(_:)), keyEquivalent: "")
        aot.target = self
        aot.state = Prefs.alwaysOnTop ? .on : .off
        menu.addItem(aot)

        let hide = NSMenuItem(title: Prefs.hideWindow ? "Show Window" : "Hide Window (Menu Bar Only)",
                              action: #selector(toggleHideWindow(_:)), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MQTT Peek", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    private func refreshMenus() {
        statusItem?.menu = makeMenu()
        valueWindow.setContextMenu(makeMenu())
    }

    /// Minimal app + edit menu. The Edit menu is what gives the Preferences text
    /// fields working cut/copy/paste/select-all.
    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPreferences(_:)), keyEquivalent: ",")
        prefs.target = self
        appMenu.addItem(prefs)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit MQTT Peek", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Actions

    @objc private func openPreferences(_ sender: Any?) {
        // Surface the menu bar (and Edit menu) while editing, even in accessory mode.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if prefsController == nil {
            let controller = PreferencesWindowController()
            controller.onSave = { [weak self] in self?.prefsChanged() }
            controller.onClose = { [weak self] in
                self?.prefsController = nil
                // Restore accessory mode if the window is meant to stay hidden.
                NSApp.setActivationPolicy(Prefs.hideWindow ? .accessory : .regular)
            }
            prefsController = controller
        }
        prefsController?.showWindow(nil)
        prefsController?.window?.center()
        prefsController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleAlwaysOnTop(_ sender: Any?) {
        Prefs.alwaysOnTop.toggle()
        valueWindow.setAlwaysOnTop(Prefs.alwaysOnTop)
        refreshMenus()
    }

    @objc private func toggleHideWindow(_ sender: Any?) {
        Prefs.hideWindow.toggle()
        if Prefs.hideWindow { Prefs.showInMenuBar = true }
        applyAll()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
