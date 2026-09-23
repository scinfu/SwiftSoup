import Foundation
import XCTest
import SwiftSoup

final class CharacterReaderUnicodeCursorTest: XCTestCase {
    private func checkScanners(_ input: String, file: StaticString = #filePath, line: UInt = #line) {
        let scalars = Array(input.unicodeScalars)
        let letters = scalars.prefix { CharacterSet.letters.contains($0) }
        let digits = scalars.dropFirst(letters.count).prefix { CharacterSet.decimalDigits.contains($0) }
        let letterBytes = letters.flatMap { Array($0.utf8) }
        let combinedBytes = letterBytes + digits.flatMap { Array($0.utf8) }
        let bytes = Array(input.utf8)
        let label = input.debugDescription
        let reader = CharacterReader(input)
        XCTAssertEqual(Array(reader.consumeLetterSequence()), letterBytes, label, file: file, line: line)
        XCTAssertEqual(reader.getPos(), letterBytes.count, label, file: file, line: line)
        XCTAssertEqual(Array(reader.input[reader.getPos()...]), Array(bytes.dropFirst(letterBytes.count)), label, file: file, line: line)
        let combined = CharacterReader(bytes)
        XCTAssertEqual(Array(combined.consumeLetterThenDigitSequence()), combinedBytes, label, file: file, line: line)
        XCTAssertEqual(combined.getPos(), combinedBytes.count, label, file: file, line: line)
        XCTAssertEqual(Array(combined.input[combined.getPos()...]), Array(bytes.dropFirst(combinedBytes.count)), label, file: file, line: line)
    }

    func testUnconsumeSingleMultibyteScalar() {
        for scalar in "aπé日😀𝟙\u{301}\r\n".unicodeScalars {
            let reader = CharacterReader(String(scalar))
            XCTAssertEqual(reader.consume(), scalar)
            reader.unconsume()
            XCTAssertEqual(reader.getPos(), 0, String(scalar))
            XCTAssertEqual(reader.current(), scalar)
        }
    }

    func testReverseTraversalPreservesScalarBoundaries() {
        for input in ["日本語", "x😀z", "日a本!", "π😀日é", "e\u{301}🇯🇵\r\n", "😀😀😀"] {
            let reader = CharacterReader(input)
            let scalars = Array(input.unicodeScalars)
            var offsets = [0]
            for scalar in scalars { offsets.append(offsets.last! + scalar.utf8.count) }
            _ = reader.consumeToEnd()
            for index in scalars.indices.reversed() {
                reader.unconsume()
                XCTAssertEqual(reader.getPos(), offsets[index], input.debugDescription)
                XCTAssertEqual(reader.current(), scalars[index])
            }
            reader.unconsume()
            XCTAssertEqual(reader.getPos(), 0)
            for scalar in scalars { XCTAssertEqual(reader.consume(), scalar) }
            XCTAssertTrue(reader.isEmpty())
        }
    }

    func testLetterAndDigitTransitionsPreserveUTF8() {
        for input in ["日本語123!", "π1日!", "é日本", "A日１２!", "é1٢!", "π1😀", "É１２!", "𝟙１２!", "日本。", "日a本!", "πa😀", "αabc１２tail"] {
            checkScanners(input)
        }
    }

    func testGeneratedScannersMatchIndependentScalarOracle() {
        let alphabet: [UnicodeScalar] = ["a", "Z", "π", "é", "日", "本", "𝔄", "0", "９", "١", "𝟙", "!", "😀", "\u{301}", "\u{0}"]
        var state: UInt64 = 0x73fbc25a
        for _ in 0..<512 {
            var scalars: [UnicodeScalar] = []
            for _ in 0..<12 {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                scalars.append(alphabet[Int((state >> 32) % UInt64(alphabet.count))])
            }
            checkScanners(String(String.UnicodeScalarView(scalars)))
        }
    }

    func testBorrowedBufferScannersAndRewind() {
        let bytes = Array("日本１２😀".utf8)
        bytes.withUnsafeBufferPointer { buffer in
            let reader = CharacterReader(buffer)
            XCTAssertEqual(Array(reader.consumeLetterThenDigitSequence()), Array("日本１２".utf8))
            XCTAssertEqual(reader.consume(), "😀")
            reader.unconsume()
            XCTAssertEqual(reader.current(), "😀")
            XCTAssertEqual(reader.getPos(), "日本１２".utf8.count)
        }
    }

    func testMalformedSuffixDoesNotGetIncludedOrSkipValidBytes() {
        for suffix: [UInt8] in [[0xff, 65], [0xe3, 0x81], [0xf0, 0x9f], [0x80, 49]] {
            let prefix = Array("日本".utf8)
            let reader = CharacterReader(prefix + suffix)
            XCTAssertEqual(Array(reader.consumeLetterSequence()), prefix)
            XCTAssertEqual(reader.getPos(), prefix.count)
            XCTAssertEqual(Array(reader.input[reader.getPos()...]), suffix)
        }
    }
}
