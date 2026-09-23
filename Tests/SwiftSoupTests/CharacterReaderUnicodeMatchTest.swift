import Foundation
import XCTest
import SwiftSoup

final class CharacterReaderUnicodeMatchTest: XCTestCase {
    func testUnicodePrefixesMatchWholeScalars() {
        for (input, needle) in [("日本語!", "日本"), ("πÉ日!", "Πé日"), ("😀🇯🇵!", "😀🇯🇵"), ("a日π!", "A日Π"), ("é\u{301}!", "É\u{301}")] {
            let reader = CharacterReader(input)
            XCTAssertTrue(reader.matchesIgnoreCase(needle), input)
            XCTAssertTrue(reader.matchesIgnoreCase(Array(needle.utf8)), input)
            XCTAssertEqual(reader.getPos(), 0)
            XCTAssertTrue(reader.matchConsumeIgnoreCase(Array(needle.utf8)), input)
            let count = input.unicodeScalars.prefix(needle.unicodeScalars.count).reduce(0) { $0 + $1.utf8.count }
            XCTAssertEqual(reader.getPos(), count)
            XCTAssertEqual(Array(reader.input[reader.getPos()...]), Array(input.utf8.dropFirst(count)))
        }
    }

    func testCaseMappingsMayChangeUTF8Width() {
        for (input, needle) in [("I!", "ı"), ("ȿ!", "Ȿ"), ("Ȿ!", "ȿ")] {
            XCTAssertEqual(input.unicodeScalars.first!.properties.uppercaseMapping, needle.unicodeScalars.first!.properties.uppercaseMapping)
            let reader = CharacterReader(input)
            XCTAssertTrue(reader.matchConsumeIgnoreCase(Array(needle.utf8)), input)
            XCTAssertEqual(reader.getPos(), input.unicodeScalars.first!.utf8.count)
            XCTAssertEqual(reader.current(), "!")
        }
    }

    func testFailedMatchDoesNotConsumeOrChangeMark() {
        for needle in ["日本X", "日😀", "日本語語", "日É"] {
            let reader = CharacterReader("_日本語")
            reader.advanceAscii()
            reader.markPos()
            XCTAssertFalse(reader.matchConsumeIgnoreCase(Array(needle.utf8)))
            XCTAssertEqual(reader.getPos(), 1)
            XCTAssertTrue(reader.matchConsumeIgnoreCase(Array("日本".utf8)))
            XCTAssertEqual(reader.current(), "語")
            reader.rewindToMark()
            XCTAssertEqual(reader.getPos(), 1)
            XCTAssertEqual(reader.current(), "日")
        }
    }

    func testGeneratedUnicodePrefixesMatchScalarMappingOracle() {
        let alphabet: [UnicodeScalar] = ["a", "Z", "é", "É", "π", "Π", "日", "本", "😀", "ı", "ȿ", "Ȿ", "\u{301}"]
        for first in alphabet {
            for second in alphabet {
                let input = String(first) + String(second) + "!"
                for needle in [input.dropLast().description, String(first) + "日", String(first) + "π"] where needle.utf8.contains(where: { $0 >= 128 }) {
                    let expected = zip(input.unicodeScalars, needle.unicodeScalars).allSatisfy {
                        $0.properties.uppercaseMapping == $1.properties.uppercaseMapping
                    }
                    let reader = CharacterReader(input)
                    XCTAssertEqual(reader.matchesIgnoreCase(needle), expected, "\(input.debugDescription), \(needle.debugDescription)")
                    XCTAssertEqual(reader.getPos(), 0)
                }
            }
        }
    }

    func testASCIIAndEmptyNeedleBehaviorIsUnchanged() {
        let reader = CharacterReader("AbC日本")
        XCTAssertTrue(reader.matchesIgnoreCase("aBc"))
        XCTAssertTrue(reader.matchConsumeIgnoreCase(Array("ABC".utf8)))
        XCTAssertEqual(reader.getPos(), 3)
        XCTAssertTrue(reader.matchesIgnoreCase(""))
        XCTAssertFalse(reader.matchesIgnoreCase("longer than the remainder"))
        XCTAssertEqual(reader.getPos(), 3)
        XCTAssertFalse(CharacterReader("ſ").matchesIgnoreCase("s")) // ASCII-needle byte-folding contract.
        XCTAssertFalse(CharacterReader("ß").matchesIgnoreCase("SS")) // Not full-string case folding.
    }

    func testMalformedInputsReturnFalseWithoutConsuming() {
        for (input, needle): ([UInt8], [UInt8]) in [([0xff], [0xc3, 0xa9]), ([0xe6, 0x97], Array("日".utf8)), (Array("日本".utf8), [0xe6, 0x97]), (Array("日".utf8), [0xff])] {
            let reader = CharacterReader(input)
            XCTAssertFalse(reader.matchConsumeIgnoreCase(needle))
            XCTAssertEqual(reader.getPos(), 0)
        }
    }
}
