import XCTest
@testable import SwiftSoup

final class PlaintextByteProgressTest: XCTestCase {
    func testEveryByteMakesProgressInPlaintextState() throws {
        for byte in UInt8.min...UInt8.max {
            let reader = CharacterReader([byte])
            let tokenizer = Tokeniser(reader, nil)
            // Step once so a stalled tokenizer fails without hanging the suite.
            try TokeniserState.PLAINTEXT.read(tokenizer, reader)
            XCTAssertEqual(reader.getPos(), 1, "byte=\(byte)")
        }
    }

    func testInvalidByteBetweenRunsCannotStallPlaintext() throws {
        for count in [0, 1, 15, 16, 128] {
            let input = [UInt8](repeating: 65, count: count) + [255, 66, 0, 67]
            let reader = CharacterReader(input)
            let tokenizer = Tokeniser(reader, nil)
            // Each non-EOF step must consume input; bound the loop independently.
            for _ in 0..<input.count where !reader.isEmpty() {
                let before = reader.getPos()
                try TokeniserState.PLAINTEXT.read(tokenizer, reader)
                guard reader.getPos() > before else {
                    XCTFail("PLAINTEXT stalled at byte \(input[before]) after \(count) leading bytes")
                    return
                }
            }
            XCTAssertTrue(reader.isEmpty())
        }
    }
}
