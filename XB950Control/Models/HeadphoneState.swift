import Foundation

struct PairedHeadphones: Identifiable, Hashable {
    let name: String
    let address: String

    var id: String { address }
}

enum SurroundMode: UInt8, CaseIterable, Identifiable, Sendable {
    case off = 0
    case outdoorStage = 1
    case arena = 2
    case concertHall = 3
    case club = 4

    var id: UInt8 { rawValue }

    var label: String {
        switch self {
        case .off: "Off"
        case .outdoorStage: "Outdoor Stage"
        case .arena: "Arena"
        case .concertHall: "Concert Hall"
        case .club: "Club"
        }
    }
}

struct HeadphoneState: Equatable, Sendable {
    var connected = false
    var address = ""
    var model = ""
    var firmware = ""
    var protocolVersion: UInt16?
    var functions = Set<UInt8>()
    var battery: Int?
    var charging = false
    var noiseCancelling: Bool?
    var clearBassLevel: Int?
    var surround: SurroundMode?

    static let preview = HeadphoneState(
        connected: true,
        address: "00-11-22-33-44-55",
        model: "MDR-XB950N1",
        firmware: "1.0.3",
        protocolVersion: 1,
        functions: [0x11, 0x41, 0x52, 0x61],
        battery: 70,
        charging: false,
        noiseCancelling: true,
        clearBassLevel: 2,
        surround: .off
    )
}
