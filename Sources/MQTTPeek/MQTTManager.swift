import Foundation
import CocoaMQTT

/// Owns the CocoaMQTT client. Subscribe-only: connects, subscribes to the configured
/// topic, and reports the latest payload + connection state back on the main thread.
///
/// Reconnection is owned here by a single watchdog timer rather than CocoaMQTT's own
/// `autoReconnect` (which is disabled). While we want a connection but aren't connected,
/// the watchdog re-attempts every `reconnectInterval` — this also covers a broker that's
/// down at launch and a connect that gets stuck in "connecting".
final class MQTTManager: NSObject {
    enum State { case disconnected, connecting, connected }

    /// Called with each received payload (main thread).
    var onValue: ((String) -> Void)?
    /// Called on every connection-state change with an optional detail string (main thread).
    var onState: ((State, String?) -> Void)?

    /// How often to retry while not connected.
    private let reconnectInterval: TimeInterval = 5

    private var mqtt: CocoaMQTT?
    private var topic = ""
    private var watchdog: Timer?
    private var wantConnection = false
    private var state: State = .disconnected   // mutated on the main thread only

    /// (Re)configure from current Prefs, connect, and keep retrying until `stop()`.
    /// Call on the main thread (AppDelegate does).
    func reconnect() {
        wantConnection = true
        startWatchdog()
        connectNow()
    }

    /// Stop connecting and cancel the retry watchdog.
    func stop() {
        wantConnection = false
        watchdog?.invalidate()
        watchdog = nil
        teardownClient()
        update(.disconnected, nil)
    }

    // MARK: - Connection

    private func connectNow() {
        teardownClient()

        let host = Prefs.host
        topic = Prefs.topic
        guard !host.isEmpty, !topic.isEmpty else {
            update(.disconnected, "Set broker host and topic in Preferences")
            return
        }

        let client = CocoaMQTT(clientID: "MQTTPeek-" + Prefs.clientSuffix,
                               host: host,
                               port: UInt16(clamping: Prefs.port))
        client.username = Prefs.username.isEmpty ? nil : Prefs.username
        client.password = Prefs.password.isEmpty ? nil : Prefs.password
        client.enableSSL = Prefs.useTLS
        if Prefs.useTLS && Prefs.allowUntrusted { client.allowUntrustCACertificate = true }
        client.keepAlive = 60
        client.cleanSession = true
        client.autoReconnect = false   // reconnection is owned by the watchdog below
        client.delegate = self
        mqtt = client

        update(.connecting, nil)
        _ = client.connect()
    }

    private func teardownClient() {
        mqtt?.delegate = nil       // ignore any late callbacks from the outgoing client
        mqtt?.disconnect()
        mqtt = nil
    }

    // MARK: - Reconnect watchdog

    private func startWatchdog() {
        guard watchdog == nil else { return }
        let timer = Timer(timeInterval: reconnectInterval, repeats: true) { [weak self] _ in
            self?.watchdogTick()
        }
        timer.tolerance = 1.0
        // .common so retries keep firing even while a menu is open or the window is dragged.
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    /// Fires on the main runloop every `reconnectInterval`; re-attempts the connection
    /// whenever we want one but aren't currently connected.
    private func watchdogTick() {
        guard wantConnection, state != .connected, Prefs.isConfigured else { return }
        connectNow()
    }

    // MARK: - State

    /// Single funnel for state changes. Must run on the main thread.
    private func update(_ newState: State, _ detail: String?) {
        state = newState
        onState?(newState, detail)
    }

    /// Marshal a delegate callback (delivered on CocoaMQTT's queue) onto the main thread.
    private func emit(_ newState: State, _ detail: String?) {
        DispatchQueue.main.async { self.update(newState, detail) }
    }
}

extension MQTTManager: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            mqtt.subscribe(topic, qos: .qos0)   // re-subscribe on every (re)connect
            emit(.connected, nil)
        } else {
            emit(.disconnected, "Broker rejected connection: \(ack)")
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        guard message.topic == topic else { return }
        let value = message.string ?? message.payload.map(String.init).joined(separator: " ")
        DispatchQueue.main.async { self.onValue?(value) }
    }

    @objc func mqtt(_ mqtt: CocoaMQTT, didStateChangeTo state: CocoaMQTTConnState) {
        switch state {
        case .connected:    emit(.connected, nil)
        case .connecting:   emit(.connecting, nil)
        case .disconnected: emit(.disconnected, nil)
        @unknown default:   break
        }
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        emit(.disconnected, err?.localizedDescription)
    }

    // Unused requirements of the (subscribe-only) delegate.
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    func mqttDidPing(_ mqtt: CocoaMQTT) {}
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
}
