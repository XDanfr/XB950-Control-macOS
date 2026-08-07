import Foundation
import os

final class HeadphoneController {
    var onState: ((HeadphoneState) -> Void)?
    var onError: ((Error) -> Void)?

    private let transport = XB950BluetoothTransport()
    private let queue = DispatchQueue(label: "me.xdan.XB950ControlMac.protocol")
    private let parser = MDRFrameParser()
    private let logger = Logger(subsystem: "me.xdan.XB950ControlMac", category: "MDR")
    private var state = HeadphoneState()
    private var sequence: UInt8 = 0
    private var pending: [Data] = []
    private var active: (payload: Data, attempt: Int, token: UUID)?

    init() {
        transport.dataHandler = { [weak self] data in
            self?.queue.async { self?.receive(data) }
        }
        transport.disconnectHandler = { [weak self] error in
            self?.queue.async { self?.didDisconnect(error) }
        }
    }

    static func pairedDevices() -> [PairedHeadphones] {
        XB950BluetoothTransport.pairedSonyDevices().compactMap { item in
            guard let name = item["name"], let address = item["address"] else { return nil }
            return PairedHeadphones(name: name, address: address)
        }
    }

    func connect(to device: PairedHeadphones, completion: @escaping (Error?) -> Void) {
        transport.connect(to: device.address) { [weak self] error in
            guard let self else { return }
            if let error {
                completion(error)
                return
            }
            self.queue.async {
                self.state = HeadphoneState(connected: true, address: device.address)
                self.emitState()
                self.enqueue([
                    MDRProtocol.getProtocol(), MDRProtocol.getModel(), MDRProtocol.getFirmware(),
                    MDRProtocol.getFunctions(), MDRProtocol.getBattery(),
                    MDRProtocol.getNoiseCancelling(), MDRProtocol.getClearBass(), MDRProtocol.getSurround()
                ])
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    func disconnect() {
        transport.disconnect()
        queue.async {
            self.pending.removeAll()
            self.active = nil
            self.state.connected = false
            self.emitState()
        }
    }

    func refresh() {
        enqueueFromAnyThread([
            MDRProtocol.getBattery(), MDRProtocol.getNoiseCancelling(),
            MDRProtocol.getClearBass(), MDRProtocol.getSurround()
        ])
    }

    func setNoiseCancelling(_ enabled: Bool) {
        queue.async {
            self.state.noiseCancelling = enabled
            self.emitState()
            self.enqueue([MDRProtocol.setNoiseCancelling(enabled), MDRProtocol.getNoiseCancelling()])
        }
    }

    func setClearBass(_ level: Int) {
        guard (-10...10).contains(level) else { return }
        queue.async {
            self.state.clearBassLevel = level
            self.emitState()
            self.enqueue([MDRProtocol.setClearBass(level), MDRProtocol.getClearBass()])
        }
    }

    func setSurround(_ mode: SurroundMode) {
        queue.async {
            self.state.surround = mode
            self.emitState()
            self.enqueue([MDRProtocol.setSurround(mode), MDRProtocol.getSurround()])
        }
    }

    private func enqueueFromAnyThread(_ payloads: [Data]) {
        queue.async { self.enqueue(payloads) }
    }

    private func enqueue(_ payloads: [Data]) {
        guard state.connected else { return }
        pending.append(contentsOf: payloads)
        sendNextIfNeeded()
    }

    private func sendNextIfNeeded() {
        guard active == nil, !pending.isEmpty, state.connected else { return }
        let payload = pending.removeFirst()
        send(payload, attempt: 1)
    }

    private func send(_ payload: Data, attempt: Int) {
        let token = UUID()
        active = (payload, attempt, token)
        let packet = MDRProtocol.encode(messageType: .command1, sequence: sequence, payload: payload)
        logger.debug("TX command 0x\(String(payload.first ?? 0, radix: 16), privacy: .public)")
        do {
            try transport.send(packet)
        } catch {
            failConnection(error)
            return
        }
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, let active = self.active, active.token == token else { return }
            if attempt < 3 {
                self.logger.warning("ACK timeout; retrying command")
                self.send(payload, attempt: attempt + 1)
            } else {
                self.failConnection(ControllerError.ackTimeout(payload.first ?? 0))
            }
        }
    }

    private func receive(_ data: Data) {
        do {
            for frame in try parser.feed(data) { handle(frame) }
        } catch {
            logger.error("Invalid MDR frame: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(_ frame: MDRFrame) {
        sequence = frame.sequence
        if frame.messageType == MDRMessageType.acknowledgement.rawValue {
            active = nil
            sendNextIfNeeded()
            return
        }
        guard frame.messageType == MDRMessageType.command1.rawValue ||
                frame.messageType == MDRMessageType.command2.rawValue else { return }

        let ackSequence: UInt8 = frame.sequence == 0 ? 1 : 0
        do {
            try transport.send(MDRProtocol.encode(messageType: .acknowledgement, sequence: ackSequence))
        } catch {
            failConnection(error)
            return
        }
        parse(frame.payload)
    }

    private func parse(_ payload: Data) {
        guard let rawCommand = payload.first, let command = MDRCommand(rawValue: rawCommand) else { return }
        switch command {
        case .returnProtocol where payload.count >= 4:
            state.protocolVersion = UInt16(payload[2]) << 8 | UInt16(payload[3])
        case .returnDeviceInfo where payload.count >= 3:
            let kind = payload[1]
            let length = min(Int(payload[2]), payload.count - 3)
            let value = String(decoding: payload[3..<(3 + length)], as: UTF8.self)
                .trimmingCharacters(in: .controlCharacters)
            if kind == 1 { state.model = value }
            if kind == 2 { state.firmware = value }
        case .returnFunctions where payload.count >= 3:
            let count = min(Int(payload[2]), payload.count - 3)
            state.functions = Set(payload[3..<(3 + count)])
        case .returnBattery, .notifyBattery where payload.count >= 4:
            state.battery = min(100, Int(payload[2]))
            state.charging = payload[3] != 0
        case .returnNC, .notifyNC where payload.count >= 4 && payload[1] == 1:
            state.noiseCancelling = payload[3] != 0
        case .returnBass, .notifyBass where payload.count >= 3 && payload[1] == 2:
            state.clearBassLevel = max(-10, min(10, Int(Int8(bitPattern: payload[2]))))
        case .returnVPT, .notifyVPT where payload.count >= 3 && payload[1] == 1:
            state.surround = SurroundMode(rawValue: payload[2])
        default:
            return
        }
        emitState()
    }

    private func didDisconnect(_ error: Error?) {
        pending.removeAll()
        active = nil
        state.connected = false
        emitState()
        if let error { emitError(error) }
    }

    private func failConnection(_ error: Error) {
        DispatchQueue.main.async { self.transport.disconnect() }
        didDisconnect(error)
    }

    private func emitState() {
        let snapshot = state
        DispatchQueue.main.async { [weak self] in self?.onState?(snapshot) }
    }

    private func emitError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in self?.onError?(error) }
    }
}

private enum ControllerError: LocalizedError {
    case ackTimeout(UInt8)

    var errorDescription: String? {
        switch self {
        case .ackTimeout(let command):
            "The headphones did not acknowledge command 0x\(String(format: "%02X", command))."
        }
    }
}
