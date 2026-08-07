import Foundation

enum MDRError: LocalizedError {
    case truncatedEscape
    case invalidEscape(UInt8)
    case shortFrame
    case badChecksum
    case badLength

    var errorDescription: String? {
        switch self {
        case .truncatedEscape: "The headphones sent a truncated escape sequence."
        case .invalidEscape(let byte): "The headphones sent an invalid escaped byte (0x\(String(byte, radix: 16)))."
        case .shortFrame: "The headphones sent a frame that was too short."
        case .badChecksum: "A Bluetooth frame failed its checksum."
        case .badLength: "A Bluetooth frame had an invalid payload length."
        }
    }
}

enum MDRMessageType: UInt8 {
    case acknowledgement = 0x01
    case command1 = 0x0c
    case command2 = 0x0e
}

enum MDRCommand: UInt8 {
    case getProtocol = 0x00
    case returnProtocol = 0x01
    case getDeviceInfo = 0x04
    case returnDeviceInfo = 0x05
    case getFunctions = 0x06
    case returnFunctions = 0x07
    case getBattery = 0x10
    case returnBattery = 0x11
    case notifyBattery = 0x13
    case getVPT = 0x46
    case returnVPT = 0x47
    case setVPT = 0x48
    case notifyVPT = 0x49
    case getBass = 0x56
    case returnBass = 0x57
    case setBass = 0x58
    case notifyBass = 0x59
    case getNC = 0x66
    case returnNC = 0x67
    case setNC = 0x68
    case notifyNC = 0x69
}

struct MDRFrame: Equatable {
    let messageType: UInt8
    let sequence: UInt8
    let payload: Data
}

enum MDRProtocol {
    static let start: UInt8 = 0x3e
    static let end: UInt8 = 0x3c
    static let escape: UInt8 = 0x3d
    private static let special: Set<UInt8> = [start, end, escape]

    static func encode(messageType: MDRMessageType, sequence: UInt8, payload: Data = Data()) -> Data {
        var body = Data([messageType.rawValue, sequence])
        let length = UInt32(payload.count).bigEndian
        withUnsafeBytes(of: length) { body.append(contentsOf: $0) }
        body.append(payload)
        body.append(body.reduce(0) { $0 &+ $1 })

        var result = Data([start])
        for byte in body {
            if special.contains(byte) {
                result.append(escape)
                result.append(byte & 0xef)
            } else {
                result.append(byte)
            }
        }
        result.append(end)
        return result
    }

    static func decode(encodedBody: Data) throws -> MDRFrame {
        var body = Data()
        var iterator = encodedBody.makeIterator()
        while let byte = iterator.next() {
            guard byte == escape else {
                body.append(byte)
                continue
            }
            guard let escaped = iterator.next() else { throw MDRError.truncatedEscape }
            let decoded = escaped | 0x10
            guard special.contains(decoded) else { throw MDRError.invalidEscape(escaped) }
            body.append(decoded)
        }

        guard body.count >= 7 else { throw MDRError.shortFrame }
        guard let checksum = body.last,
              body.dropLast().reduce(0, { $0 &+ $1 }) == checksum else {
            throw MDRError.badChecksum
        }
        let payloadLength = body[2..<6].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let payload = body.subdata(in: 6..<(body.count - 1))
        guard payload.count == Int(payloadLength) else { throw MDRError.badLength }
        return MDRFrame(messageType: body[0], sequence: body[1], payload: payload)
    }

    static func getProtocol() -> Data { Data([MDRCommand.getProtocol.rawValue, 0x00]) }
    static func getModel() -> Data { Data([MDRCommand.getDeviceInfo.rawValue, 0x01]) }
    static func getFirmware() -> Data { Data([MDRCommand.getDeviceInfo.rawValue, 0x02]) }
    static func getFunctions() -> Data { Data([MDRCommand.getFunctions.rawValue, 0x00]) }
    static func getBattery() -> Data { Data([MDRCommand.getBattery.rawValue, 0x00]) }
    static func getNoiseCancelling() -> Data { Data([MDRCommand.getNC.rawValue, 0x01]) }
    static func setNoiseCancelling(_ enabled: Bool) -> Data {
        Data([MDRCommand.setNC.rawValue, 0x01, 0x01, enabled ? 1 : 0])
    }
    static func getClearBass() -> Data { Data([MDRCommand.getBass.rawValue, 0x02]) }
    static func setClearBass(_ level: Int) -> Data {
        precondition((-10...10).contains(level))
        return Data([MDRCommand.setBass.rawValue, 0x02, UInt8(bitPattern: Int8(level))])
    }
    static func getSurround() -> Data { Data([MDRCommand.getVPT.rawValue, 0x01]) }
    static func setSurround(_ mode: SurroundMode) -> Data {
        Data([MDRCommand.setVPT.rawValue, 0x01, mode.rawValue])
    }
}

final class MDRFrameParser {
    private var inside = false
    private var body = Data()

    func feed(_ data: Data) throws -> [MDRFrame] {
        var frames: [MDRFrame] = []
        for byte in data {
            if byte == MDRProtocol.start {
                inside = true
                body.removeAll(keepingCapacity: true)
            } else if byte == MDRProtocol.end, inside {
                let encoded = body
                inside = false
                body.removeAll(keepingCapacity: true)
                frames.append(try MDRProtocol.decode(encodedBody: encoded))
            } else if inside {
                body.append(byte)
            }
        }
        return frames
    }
}
