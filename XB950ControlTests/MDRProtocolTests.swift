import XCTest
@testable import XB950Control

final class MDRProtocolTests: XCTestCase {
    func testKnownNegativeBassFrame() throws {
        let payload = MDRProtocol.setClearBass(-2)
        let packet = MDRProtocol.encode(messageType: .command1, sequence: 1, payload: payload)
        XCTAssertEqual(packet, Data([0x3e, 0x0c, 0x01, 0, 0, 0, 3, 0x58, 0x02, 0xfe, 0x68, 0x3c]))
    }

    func testSpecialBytesRoundTrip() throws {
        let original = Data([0x3c, 0x3d, 0x3e, 0x00])
        let encoded = MDRProtocol.encode(messageType: .command1, sequence: 0, payload: original)
        let frame = try MDRProtocol.decode(encodedBody: Data(encoded.dropFirst().dropLast()))
        XCTAssertEqual(frame.payload, original)
    }

    func testParserAcceptsFragmentedInput() throws {
        let encoded = MDRProtocol.encode(
            messageType: .command1,
            sequence: 0,
            payload: MDRProtocol.getBattery()
        )
        let parser = MDRFrameParser()
        XCTAssertTrue(try parser.feed(encoded.prefix(4)).isEmpty)
        let frames = try parser.feed(encoded.dropFirst(4))
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].payload, MDRProtocol.getBattery())
    }

    func testClearBassRangeEncoding() {
        XCTAssertEqual(MDRProtocol.setClearBass(-10).last, 0xf6)
        XCTAssertEqual(MDRProtocol.setClearBass(0).last, 0x00)
        XCTAssertEqual(MDRProtocol.setClearBass(10).last, 0x0a)
    }
}
