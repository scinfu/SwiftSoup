import Foundation
import XCTest
@testable import SwiftSoup

final class XmlNameStartTest: XCTestCase {
    private let names = ["_Item", ":Item", "日本", "Él", "π", "𐐀name", "\u{200C}name"]

    func testXmlNamesAcrossTrackingAndStorageModes() throws {
        for name in names {
            let element = "<\(name) key=\"value\"><child>one</child></\(name)>"
            let xml = "<root>\(element)<\(name) /><tail>two</tail></root>"
            let bytes = Array(xml.utf8)
            for trackSource in [false, true] {
                for trackAttributes in [false, true] {
                    let settings = ParseSettings(true, true, trackSource, trackAttributes)
                    let owned = try Parser.xmlParser().settings(settings).parseInput(bytes, "")
                    let borrowed = try bytes.withUnsafeBufferPointer {
                        try XmlTreeBuilder().parse($0, owner: nil, [], ParseErrorList.noTracking(), settings)
                    }
                    for doc in [owned, borrowed] {
                        let root = try XCTUnwrap(doc.children().first())
                        XCTAssertEqual(root.children().map { $0.tagName() }, [name, name, "tail"], xml)
                        guard root.children().count == 3 else { continue }
                        let first = root.child(0)
                        XCTAssertEqual(try first.text(), "one")
                        XCTAssertEqual(try first.attr("key"), trackAttributes ? "value" : "")
                        XCTAssertEqual(root.child(1).children().count, 0)
                        XCTAssertEqual(try root.child(2).text(), "two")
                        if trackSource {
                            XCTAssertEqual(first.sourceSliceUTF8().map { String(decoding: $0, as: UTF8.self) }, element)
                        }
                        doc.outputSettings().prettyPrint(pretty: false)
                        let serialized = String(decoding: try doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self)
                        let roundTrip = try SwiftSoup.parseXML(serialized)
                        XCTAssertEqual(roundTrip.children().first()?.children().map { $0.tagName() }, [name, name, "tail"])
                    }
                }
            }
        }
    }

    func testXmlNameStartRangeBoundaries() throws {
        // XML 1.0 (Fifth Edition), production [4] NameStartChar.
        let valid: [UInt32] = [0x3A, 0x41, 0x5A, 0x5F, 0x61, 0x7A, 0xC0, 0xD6, 0xD8, 0xF6,
            0xF8, 0x2FF, 0x370, 0x37D, 0x37F, 0x1FFF, 0x200C, 0x200D, 0x2070, 0x218F,
            0x2C00, 0x2FEF, 0x3001, 0xD7FF, 0xF900, 0xFDCF, 0xFDF0, 0xFFFD, 0x10000, 0xEFFFF]
        for value in valid {
            let name = String(UnicodeScalar(value)!) + "name"
            let doc = try SwiftSoup.parseXML("<\(name)>text</\(name)><tail />")
            XCTAssertEqual(doc.children().map { $0.tagName() }, [name, "tail"], "U+\(String(value, radix: 16))")
            XCTAssertEqual(try doc.children().first()?.text(), "text")
        }
    }

    func testInvalidXmlNameStartsRemainText() throws {
        let invalid: [UInt32] = [0x2D, 0x2E, 0x30, 0x39, 0xB7, 0xBF, 0xD7, 0xF7, 0x300,
            0x36F, 0x37E, 0x200B, 0x200E, 0x206F, 0x2190, 0x2BFF, 0x2FF0, 0x3000,
            0xE000, 0xF8FF, 0xFDD0, 0xFDEF, 0xFFFE, 0xFFFF, 0xF0000, 0x10FFFF]
        for value in invalid {
            let name = String(UnicodeScalar(value)!) + "name"
            for trackSource in [false, true] {
                let doc = try Parser.xmlParser().settings(ParseSettings(true, true, trackSource))
                    .parseInput("<\(name)>text</\(name)><tail />", "")
                XCTAssertEqual(doc.children().map { $0.tagName() }, ["tail"], "U+\(String(value, radix: 16))")
            }
        }
    }

    func testHtmlNameStartsStayAsciiWithPreservedCase() throws {
        for name in names {
            for trackSource in [false, true] {
                let doc = try Parser.htmlParser().settings(ParseSettings(true, true, trackSource))
                    .parseInput("<\(name)>text</\(name)><div>tail</div>", "")
                XCTAssertTrue(try doc.getElementsByTag(name).isEmpty())
                XCTAssertEqual(try doc.select("div").text(), "tail")
            }
        }
    }

    func testXmlNameRecognitionDoesNotDependOnPreservingCase() throws {
        for trackSource in [false, true] {
            let doc = try Parser.xmlParser().settings(ParseSettings(false, false, trackSource))
                .parseInput("<_ITEM>one</_ITEM><_NEXT />", "")
            XCTAssertEqual(doc.children().map { $0.tagName() }, ["_item", "_next"])
            XCTAssertEqual(try doc.children().first()?.text(), "one")
        }
    }

    func testXmlNameStartsInFragmentsAndDataInput() throws {
        let xml = "<日本>one</日本><_item />"
        let fragment = try Parser.parseXmlFragment(xml, "")
        XCTAssertEqual(fragment.compactMap { ($0 as? Element)?.tagName() }, ["日本", "_item"])
        XCTAssertEqual(try SwiftSoup.parseXML(Data(xml.utf8)).children().map { $0.tagName() }, ["日本", "_item"])
    }

    func testXmlNameStartsInExplicitTokenizerStates() throws {
        for name in names {
            for (state, prefix, isStart) in [(TokeniserState.Data, "<", true), (.TagOpen, "<", true), (.EndTagOpen, "</", false)] {
                let builder = XmlTreeBuilder()
                builder.initialiseParse(Array("\(prefix)\(name)>".utf8), [], ParseErrorList.noTracking(), .preserveCase)
                let reader = builder.reader
                let tokeniser = builder.tokeniser
                if state != .Data { reader.pos = prefix.utf8.count }
                try state.read(tokeniser, reader)
                let token = try tokeniser.read()
                if isStart {
                    XCTAssertTrue(token.isStartTag(), "\(state): \(name)")
                    if token.isStartTag() { XCTAssertEqual(try token.asStartTag().name(), Array(name.utf8)) }
                } else {
                    XCTAssertTrue(token.isEndTag(), name)
                    if token.isEndTag() { XCTAssertEqual(try token.asEndTag().name(), Array(name.utf8)) }
                }
            }
        }
    }
}
