import Foundation
import XCTest
import SwiftSoup

final class RawTextBodyModeTest: XCTestCase {
    private let payload = "one<b>literal</b>&amp;日本😀\n  two"

    private func wholeText(_ element: Element) -> String {
        element.textNodes().map { $0.getWholeText() }.joined()
    }

    func testBodyRawTextTagsKeepMarkupAndEntitiesLiteral() throws {
        for tag in ["iframe", "noembed", "xmp"] {
            for trackSource in [false, true] {
                for preserveCase in [false, true] {
                    let parser = Parser.htmlParser().settings(ParseSettings(preserveCase, false, trackSource))
                    let document = try parser.parseInput("<\(tag.uppercased()) id='raw'>\(payload)</\(tag.uppercased())><p id='after'>tail</p>", "")
                    let raw = try XCTUnwrap(document.getElementById("raw"))
                    XCTAssertEqual(wholeText(raw), payload, tag)
                    XCTAssertTrue(raw.children().isEmpty, tag)
                    XCTAssertTrue(try document.select("b").isEmpty, tag)
                    XCTAssertTrue(try document.getElementById("after")?.parent() === document.body(), tag)
                }
            }
        }
    }

    func testRawTextMutationSurvivesBothSerializersAndPrettyPolicies() throws {
        for tag in ["iframe", "noembed", "xmp", "noframes"] {
            for trackSource in [false, true] {
                let parser = Parser.htmlParser().settings(ParseSettings(false, false, trackSource))
                let document = try parser.parseInput("<body><\(tag) id='raw'>before</\(tag)><p>after</p>", "")
                let raw = try XCTUnwrap(document.getElementById("raw"))
                try raw.text(payload)
                try raw.attr("data-edited", "yes")
                for pretty in [false, true] {
                    document.outputSettings().prettyPrint(pretty: pretty)
                    for bytes in [try document.outerHtmlUTF8(), try document.outerHtmlUTF8WithoutSourceReuse()] {
                        let reparsed = try SwiftSoup.parse(String(decoding: bytes, as: UTF8.self))
                        let result = try XCTUnwrap(reparsed.getElementById("raw"))
                        XCTAssertEqual(wholeText(result), payload, "\(tag), pretty=\(pretty)")
                        XCTAssertTrue(result.children().isEmpty, tag)
                        XCTAssertEqual(try result.attr("data-edited"), "yes")
                    }
                }
            }
        }
    }

    func testXmpClosesParagraphAndRestoresTheBodyMode() throws {
        let document = try SwiftSoup.parse("<p id='paragraph'>before<xmp id='raw'>a<i>b</i></xmp><p id='after'>after</p>")
        let raw = try XCTUnwrap(document.getElementById("raw"))
        XCTAssertTrue(raw.parent() === document.body())
        XCTAssertEqual(wholeText(raw), "a<i>b</i>")
        XCTAssertEqual(try document.getElementById("paragraph")?.text(), "before")
        XCTAssertTrue(try document.getElementById("after")?.parent() === document.body())
    }

    func testOnlyTheMatchingEndTagExitsRawText() throws {
        for (tag, closing) in [("iframe", "iFrAmE"), ("noembed", "nOeMbEd"), ("xmp", "xMp")] {
            let value = "a</\(tag)-other><b>literal</b>&copy;"
            let document = try SwiftSoup.parse("<\(tag) id='raw'>\(value)</\(closing)><p id='after'>after</p>")
            XCTAssertEqual(wholeText(try XCTUnwrap(document.getElementById("raw"))), value)
            XCTAssertTrue(try document.getElementById("after")?.parent() === document.body())
            let atEOF = try SwiftSoup.parse("<\(tag) id='raw'>\(value)")
            XCTAssertEqual(wholeText(try XCTUnwrap(atEOF.getElementById("raw"))), value)
            XCTAssertTrue(try atEOF.select("b").isEmpty)
        }
    }

    func testXMLAndOrdinaryTextStillEscapeMarkup() throws {
        for tag in ["iframe", "noembed", "xmp", "noframes", "p", "textarea"] {
            let xml = try Parser.xmlParser().parseInput("<\(tag) />", "")
            let element = try XCTUnwrap(xml.children().first())
            try element.text("<b>&amp;日本")
            xml.outputSettings().prettyPrint(pretty: false)
            let output = String(decoding: try xml.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self)
            XCTAssertTrue(output.contains("&lt;b&gt;&amp;amp;日本"), tag)
            XCTAssertEqual(wholeText(try XCTUnwrap(Parser.xmlParser().parseInput(output, "").children().first())), "<b>&amp;日本")
        }
        let html = try SwiftSoup.parse("<p id='p'></p><textarea id='t'></textarea>")
        for id in ["p", "t"] { try html.getElementById(id)?.text("<i>&日本") }
        html.outputSettings().prettyPrint(pretty: false)
        let reparsed = try SwiftSoup.parse(String(decoding: try html.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self))
        for id in ["p", "t"] {
            let element = try XCTUnwrap(reparsed.getElementById(id))
            XCTAssertEqual(wholeText(element), "<i>&日本")
            XCTAssertTrue(element.children().isEmpty)
        }
    }
}
