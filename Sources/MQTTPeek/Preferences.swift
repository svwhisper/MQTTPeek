import AppKit

extension Notification.Name {
    /// Posted after the user saves Preferences so the app re-applies appearance and reconnects.
    static let prefsChanged = Notification.Name("MQTTPeek.prefsChanged")
}

/// Thin typed wrapper around `UserDefaults`. One place that knows every setting key.
enum Prefs {
    private static let d = UserDefaults.standard

    private enum Key {
        static let host = "brokerHost"
        static let port = "brokerPort"
        static let topic = "topic"
        static let username = "username"
        static let password = "password"
        static let useTLS = "useTLS"
        static let allowUntrusted = "allowUntrusted"
        static let alwaysOnTop = "alwaysOnTop"
        static let showInMenuBar = "showInMenuBar"
        static let hideWindow = "hideWindow"
        static let fontSize = "fontSize"
        static let showCaption = "showTopicCaption"
        static let clientSuffix = "clientSuffix"
        static let winX = "winX"
        static let winY = "winY"
    }

    static func registerDefaults() {
        d.register(defaults: [
            Key.port: 1883,
            Key.useTLS: false,
            Key.allowUntrusted: false,
            Key.alwaysOnTop: true,
            Key.showInMenuBar: false,
            Key.hideWindow: false,
            Key.fontSize: 28,
            Key.showCaption: true,
        ])
    }

    // Connection
    static var host: String {
        get { d.string(forKey: Key.host) ?? "" }
        set { d.set(newValue, forKey: Key.host) }
    }
    static var port: Int {
        get { d.integer(forKey: Key.port) }
        set { d.set(newValue, forKey: Key.port) }
    }
    static var topic: String {
        get { d.string(forKey: Key.topic) ?? "" }
        set { d.set(newValue, forKey: Key.topic) }
    }
    static var username: String {
        get { d.string(forKey: Key.username) ?? "" }
        set { d.set(newValue, forKey: Key.username) }
    }
    static var password: String {
        get { d.string(forKey: Key.password) ?? "" }
        set { d.set(newValue, forKey: Key.password) }
    }
    static var useTLS: Bool {
        get { d.bool(forKey: Key.useTLS) }
        set { d.set(newValue, forKey: Key.useTLS) }
    }
    static var allowUntrusted: Bool {
        get { d.bool(forKey: Key.allowUntrusted) }
        set { d.set(newValue, forKey: Key.allowUntrusted) }
    }

    // Appearance / behaviour
    static var alwaysOnTop: Bool {
        get { d.bool(forKey: Key.alwaysOnTop) }
        set { d.set(newValue, forKey: Key.alwaysOnTop) }
    }
    static var showInMenuBar: Bool {
        get { d.bool(forKey: Key.showInMenuBar) }
        set { d.set(newValue, forKey: Key.showInMenuBar) }
    }
    static var hideWindow: Bool {
        get { d.bool(forKey: Key.hideWindow) }
        set { d.set(newValue, forKey: Key.hideWindow) }
    }
    static var fontSize: Int {
        get { d.integer(forKey: Key.fontSize) }
        set { d.set(newValue, forKey: Key.fontSize) }
    }
    static var showCaption: Bool {
        get { d.bool(forKey: Key.showCaption) }
        set { d.set(newValue, forKey: Key.showCaption) }
    }

    /// Stable per-install client-id suffix so reconnects reuse the same MQTT session id.
    static var clientSuffix: String {
        if let s = d.string(forKey: Key.clientSuffix) { return s }
        let s = String(UUID().uuidString.prefix(8))
        d.set(s, forKey: Key.clientSuffix)
        return s
    }

    /// Remembered window position (bottom-left origin). `nil` until first move.
    static var windowOrigin: CGPoint? {
        get {
            guard let x = d.object(forKey: Key.winX) as? Double,
                  let y = d.object(forKey: Key.winY) as? Double else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            guard let p = newValue else { return }
            d.set(p.x, forKey: Key.winX)
            d.set(p.y, forKey: Key.winY)
        }
    }

    static var isConfigured: Bool { !host.isEmpty && !topic.isEmpty }
}
