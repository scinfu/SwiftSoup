import XCTest
@testable import SwiftSoup

final class RawTextRetagSourceReuseTest: XCTestCase {
    private func wholeText(_ element: Element) -> String {
        element.textNodes().map { $0.getWholeText() }.joined()
    }

    func testRetaggingRawTextEscapesPreviouslyReusableCharacterReferences() throws {
        for tag in ["iframe", "noembed", "xmp", "noframes"] {
            for replacement in ["p", "div", "textarea"] {
                for value in ["A&amp;B", "&lt;日本&gt;", "&#65; &copy;"] {
                    for trackSource in [false, true] {
                        let parser = Parser.htmlParser().settings(ParseSettings(false, false, trackSource))
                        let document = try parser.parseInput("<body><\(tag) id='value'>\(value)</\(tag)>", "")
                        document.outputSettings().prettyPrint(pretty: false)
                        let target = try XCTUnwrap(document.getElementById("value"))
                        XCTAssertEqual(wholeText(target), value)
                        XCTAssertEqual(try document.select(tag + "#value").size(), 1)
                        try target.tagName(replacement)
                        XCTAssertEqual(try document.select(replacement + "#value").size(), 1)
                        for output in [try target.outerHtml(),
                                       String(decoding: try document.outerHtmlUTF8(), as: UTF8.self),
                                       String(decoding: try document.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self)] {
                            let reparsed = try SwiftSoup.parse(output)
                            let result = try XCTUnwrap(reparsed.getElementById("value"))
                            XCTAssertEqual(wholeText(result), value, "\(tag) -> \(replacement), source=\(trackSource)")
                            XCTAssertTrue(result.children().isEmpty)
                        }
                    }
                }
            }
        }
    }

    func testRawToRawRetaggingRetainsCleanChildSourceRanges() throws {
        for replacement in ["IFRAME", "noembed", "xmp", "noframes"] {
            let document = try Parser.htmlParser().settings(ParseSettings(false, false, true)).parseInput("<body><iframe id='value'>A&amp;B</iframe>", "")
            document.outputSettings().prettyPrint(pretty: false)
            let target = try XCTUnwrap(document.getElementById("value"))
            let child = try XCTUnwrap(target.textNodes().first)
            XCTAssertTrue(child.sourceRangeIsComplete)
            XCTAssertFalse(child.sourceRangeDirty)
            try target.tagName(replacement)
            XCTAssertFalse(child.sourceRangeDirty)
            let result = try SwiftSoup.parse(target.outerHtml()).getElementById("value")
            XCTAssertEqual(wholeText(try XCTUnwrap(result)), "A&amp;B")
        }
    }

    func testOrdinaryRetaggingAndXMLKeepTheirExistingOutput() throws {
        let document = try Parser.htmlParser().settings(ParseSettings(false, false, true)).parseInput("<p id='value'>literal</p>", "")
        let target = try XCTUnwrap(document.getElementById("value"))
        let child = try XCTUnwrap(target.textNodes().first)
        try target.tagName("span")
        XCTAssertFalse(child.sourceRangeDirty)
        XCTAssertEqual(wholeText(target), "literal")
        let xml = try Parser.xmlParser().parseInput("<iframe id='value'>A&amp;B</iframe>", "")
        let xmlTarget = try XCTUnwrap(xml.getElementById("value"))
        try xmlTarget.tagName("p")
        xml.outputSettings().prettyPrint(pretty: false)
        let roundTrip = try Parser.xmlParser().parseInput(xml.outerHtml(), "")
        XCTAssertEqual(wholeText(try XCTUnwrap(roundTrip.getElementById("value"))), "A&B")
    }

    func testRejectedTagChangeDoesNotDirtyOrModifyTheElement() throws {
        let document = try Parser.htmlParser().settings(ParseSettings(false, false, true)).parseInput("<body><iframe id='value'>A&amp;B</iframe>", "")
        let target = try XCTUnwrap(document.getElementById("value"))
        let child = try XCTUnwrap(target.textNodes().first)
        let before = try target.outerHtml()
        XCTAssertThrowsError(try target.tagName(""))
        XCTAssertEqual(target.tagName(), "iframe")
        XCTAssertFalse(child.sourceRangeDirty)
        XCTAssertEqual(try target.outerHtml(), before)
    }
}
