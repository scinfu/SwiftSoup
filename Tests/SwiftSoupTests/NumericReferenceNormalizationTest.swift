import Foundation
import XCTest
@testable import SwiftSoup

final class NumericReferenceNormalizationTest: XCTestCase {
    // WHATWG numeric-character-reference-end-state. Undefined Windows-1252
    // positions remain their original control scalars, rather than being dropped.
    private let replacements: [Int: UInt32] = [
        0: 0xFFFD, 0x80: 0x20AC, 0x82: 0x201A, 0x83: 0x0192, 0x84: 0x201E,
        0x85: 0x2026, 0x86: 0x2020, 0x87: 0x2021, 0x88: 0x02C6, 0x89: 0x2030,
        0x8A: 0x0160, 0x8B: 0x2039, 0x8C: 0x0152, 0x8E: 0x017D,
        0x91: 0x2018, 0x92: 0x2019, 0x93: 0x201C, 0x94: 0x201D, 0x95: 0x2022,
        0x96: 0x2013, 0x97: 0x2014, 0x98: 0x02DC, 0x99: 0x2122,
        0x9A: 0x0161, 0x9B: 0x203A, 0x9C: 0x0153, 0x9E: 0x017E, 0x9F: 0x0178
    ]

    private func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    func testAllCachedValuesAcrossFastDecimalAndGeneralNumericPaths() throws {
        for value in 0..<256 {
            let expected = [replacements[value] ?? UInt32(value)]
            for number in ["\(value)", "00000\(value)", "x" + String(value, radix: 16),
                           "X" + String(value, radix: 16).uppercased()] {
                for terminator in [";", ""] {
                    let input = "&#" + number + terminator
                    for strict in [false, true] {
                        XCTAssertEqual(scalars(try Entities.unescape(string: input, strict: strict)), expected,
                                       "strict=\(strict), \(input)")
                    }
                }
            }
        }
    }

    func testUndefinedC1ControlsAndValidScalarBoundariesArePreserved() throws {
        for value in [0x81, 0x8D, 0x8F, 0x90, 0x9D, 0xA0, 255, 256, 999, 1000,
                      0xD7FF, 0xE000, 0xFDD0, 0xFFFE, 0xFFFF, 0x10000, 0x1F600, 0x10FFFF] {
            XCTAssertEqual(scalars(try Entities.unescape("&#\(value);")), [UInt32(value)])
            XCTAssertEqual(scalars(try Entities.unescape("&#x\(String(value, radix: 16));")), [UInt32(value)])
        }
    }

    func testInvalidScalarAndOverflowControlsStillProduceReplacementCharacters() throws {
        for number in ["55296", "57343", "1114112", "xD800", "xDFFF", "x110000",
                       String(repeating: "9", count: 128), "x" + String(repeating: "F", count: 128)] {
            XCTAssertEqual(scalars(try Entities.unescape("&#\(number);")), [0xFFFD], number)
        }
        for input in ["&#;", "&#x;", "&#X;", "&#", "&#x"] {
            XCTAssertEqual(try Entities.unescape(input), input)
        }
    }

    func testParserTextAttributesFragmentsAndSerializationAgree() throws {
        let refs = "&#0;&#128;&#130;&#x91;&#159;"
        let expected = "�€‚‘Ÿ"
        let html = "<p title='\(refs)'>\(refs)</p><textarea>\(refs)</textarea>"
        let bytes = Array(html.utf8)
        let documents = try [SwiftSoup.parse(html), SwiftSoup.parse(Data(bytes)),
            SwiftSoup.parse(withBytes: { parse in try bytes.withUnsafeBufferPointer { try parse($0) } })]
        for doc in documents {
            let p = try XCTUnwrap(doc.select("p").first())
            XCTAssertEqual(try p.attr("title"), expected)
            XCTAssertEqual(try p.text(), expected)
            XCTAssertEqual(try doc.select("textarea").text(), expected)
            let roundTrip = try SwiftSoup.parse(String(decoding: doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self))
            XCTAssertEqual(try roundTrip.select("p").text(), expected)
            try p.html(refs)
            XCTAssertEqual(try p.text(), expected)
        }
    }
    func testHtmlRemappingDoesNotChangeXmlNumericReferences() throws {
        let refs = "&#128;&#0130;&#x91;&#X9F;"
        let expected: [UInt32] = [0x80, 0x82, 0x91, 0x9F]
        let xml = "<?xml version='1.0'?><root title='\(refs)'>\(refs)</root>"
        let bytes = Array(xml.utf8)
        let documents = try [SwiftSoup.parseXML(xml), SwiftSoup.parseXML(Data(bytes)),
                             SwiftSoup.parse(xml), SwiftSoup.parse(Data(bytes)),
                             Parser.xmlParser().parseInput(bytes, "")]
        for doc in documents {
            let root = try XCTUnwrap(doc.select("root").first())
            XCTAssertEqual(scalars(try root.attr("title")), expected)
            XCTAssertEqual(scalars(try root.text()), expected)
            let roundTrip = try SwiftSoup.parseXML(String(decoding: doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self))
            XCTAssertEqual(scalars(try roundTrip.select("root").text()), expected)
        }
        let fragment = try Parser.parseXmlFragment("<root>\(refs)</root>", "")
        XCTAssertEqual(scalars(try XCTUnwrap(fragment.first as? Element).text()), expected)
    }

    func testHtmlMappingDoesNotDependOnCasePreservationOrSourceTracking() throws {
        for preserveCase in [false, true] {
            for trackSource in [false, true] {
                let parser = Parser.htmlParser().settings(ParseSettings(preserveCase, preserveCase, trackSource))
                let doc = try parser.parseInput("<p title='&#128;'>&#128;</p>", "")
                XCTAssertEqual(try doc.select("p").text(), "€")
                XCTAssertEqual(try doc.select("p").attr("title"), "€")
            }
        }
    }

    func testReplacingTheTreeBuilderDoesNotRetainThePreviousNumericPolicy() throws {
        let parser = Parser.htmlParser()
        let input = "<p>&#128;</p>"
        XCTAssertEqual(scalars(try parser.parseInput(input, "").select("p").text()), [0x20AC])
        parser.setTreeBuilder(XmlTreeBuilder())
        XCTAssertEqual(scalars(try parser.parseInput(input, "").select("p").text()), [0x80])
        parser.setTreeBuilder(HtmlTreeBuilder())
        XCTAssertEqual(scalars(try parser.parseInput(input, "").select("p").text()), [0x20AC])
    }

}
