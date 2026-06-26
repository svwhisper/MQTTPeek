import Foundation
import CocoaMQTT

/// Owns the CocoaMQTT client. Subscribe-only: connects, subscribes to the configured
/// topic, and reports the latest payload + connection state back on the main thread.
final class MQTTManager: NSObject {
    enum State { case disconnected, connecting, connected }

    /// Called with each received payload (main thread).
    var onValue: ((String) -> Void)?
    /// Called on every connection-state change with an optional detail string (main thread).
    var onState: ((State, String?) -> Void)?

    private var mqtt: CocoaMQTT?
    private var topic = ""

    /// (Re)build the client from current Prefs and connect. Safe to call repeatedly.
    func reconnect() {
        stop()

        let host = Prefs.host
        topic = Prefs.topic
        guard !host.isEmpty, !topic.isEmpty else {
            emit(.disconnected, "Set broker host and topic in Preferences")
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
        client.autoReconnect = true
        client.autoReconnectTimeInterval = 3
        client.delegate = self
        mqtt = client

        emit(.connecting, nil)
        _ = client.connect()
    }

    func stop() {
        mqtt?.autoReconnect = false
        mqtt?.disconnect()
        mqtt = nil
    }

    private func emit(_ state: State, _ detail: String?) {
        DispatchQueue.main.async { self.onState?(state, detail) }
    }
}

extension MQTTManager: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            mqtt.subscribe(topic, qos: .qos0)
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
