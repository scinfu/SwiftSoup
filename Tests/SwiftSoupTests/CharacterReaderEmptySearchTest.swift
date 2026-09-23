import XCTest
import SwiftSoup

final class CharacterReaderEmptySearchTest: XCTestCase {
    func testEmptyByteNeedleAtEveryPosition() {
        for input in ["", "a日本😀z"] {
            let reader = CharacterReader(input)
            for offset in 0...input.utf8.count {
                XCTAssertEqual(reader.nextIndexOf([UInt8]()), offset)
                XCTAssertEqual(reader.getPos(), offset)
                _ = reader.consumeByte()
            }
        }
    }

    func testEmptyStringNeedleAtScalarBoundaries() {
        for input in ["", "a日本😀z"] {
            let reader = CharacterReader(input)
            var offsets = [0]
            for scalar in input.unicodeScalars { offsets.append(offsets.last! + scalar.utf8.count) }
            for offset in offsets {
                XCTAssertEqual(reader.nextIndexOf(""), input.utf8.index(input.utf8.startIndex, offsetBy: offset))
                XCTAssertEqual(reader.getPos(), offset)
                _ = reader.consume()
            }
        }
    }

    func testEmptyConsumptionPreservesMarkPositionAndRemainder() {
        let reader = CharacterReader("x日本")
        _ = reader.consume()
        reader.markPos()
        for _ in 0..<3 {
            XCTAssertTrue(reader.consumeTo([UInt8]()).isEmpty)
            XCTAssertEqual(reader.consumeTo(""), "")
            XCTAssertEqual(reader.getPos(), 1)
            XCTAssertEqual(reader.toString(), "日本")
        }
        XCTAssertEqual(reader.consume(), "日")
        reader.rewindToMark()
        XCTAssertEqual(reader.getPos(), 1)
        _ = reader.consumeToEnd()
        XCTAssertTrue(reader.consumeTo([UInt8]()).isEmpty)
        XCTAssertEqual(reader.consumeTo(""), "")
        XCTAssertTrue(reader.isEmpty())
    }

    func testNonemptySearchesRetainOffsetsAndMissBehavior() {
        let reader = CharacterReader("_ab日本abcd")
        _ = reader.consume()
        for needle in ["a", "ab", "abc", "abcd", "日本"] {
            XCTAssertNotNil(reader.nextIndexOf(Array(needle.utf8)))
            XCTAssertEqual(reader.getPos(), 1)
        }
        XCTAssertNil(reader.nextIndexOf(Array("missing".utf8)))
        XCTAssertEqual(reader.consumeTo("日本"), "ab")
        XCTAssertEqual(reader.toString(), "日本abcd")
        XCTAssertEqual(reader.consumeTo("missing"), "日本abcd")
        XCTAssertNil(reader.nextIndexOf([65]))
    }
}
