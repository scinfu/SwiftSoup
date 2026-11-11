import XCTest
@testable import SwiftSoup

final class HtmlScopeRegressionTest: XCTestCase {
    private let boundaries = ["applet", "caption", "html", "table", "td", "th", "marquee", "object", "button"]

    private func parse(_ html: String, sourceRanges: Bool = true) throws -> Document {
        let doc = try Parser.htmlParser().settings(ParseSettings(false, false, sourceRanges)).parseInput(html, "")
        doc.outputSettings().prettyPrint(pretty: false)
        return doc
    }

    func testParagraphScopeStopsAtObjectAppletAndMarquee() throws {
        for boundary in ["object", "applet", "marquee"] {
            for sourceRanges in [false, true] {
                let doc = try parse("<p id=outer>a<\(boundary) id=boundary><p id=inner>b", sourceRanges: sourceRanges)
                let inner = try XCTUnwrap(doc.getElementById("inner"))
                let container = try XCTUnwrap(doc.getElementById("boundary"))
                XCTAssertTrue(inner.parent() === container, "\(boundary), sourceRanges=\(sourceRanges)")
            }
        }
    }

    func testManualRenameWithoutInterveningStackTruncation() throws {
        for sourceRanges in [false, true] {
            let parser = Parser.htmlParser().settings(ParseSettings(false, false, sourceRanges))
            let doc = try parser.parseInput("<p id=outer>a<button id=renamed>b", "")
            try XCTUnwrap(doc.getElementById("renamed")).tagName("i")
            try parser.getTreeBuilder().processStartTag("p")
            let paragraphs = try doc.select("p").array()
            XCTAssertEqual(paragraphs.count, 2)
            XCTAssertTrue(paragraphs.last?.parent() === doc.body(), "sourceRanges=\(sourceRanges)")
        }
    }

    func testManualRenameIntoBoundaryAndDirectStackEdits() throws {
        let builder = HtmlTreeBuilder()
        let html = Element(try Tag.valueOf("html"), "")
        let p = Element(try Tag.valueOf("p"), "")
        let boundary = Element(try Tag.valueOf("i"), "")
        builder.push(html)
        builder.push(p)
        builder.push(boundary)
        XCTAssertTrue(try builder.inButtonScope("p"))
        try boundary.tagName("button")
        XCTAssertFalse(try builder.inButtonScope("p"))
        builder.stack.removeLast()
        XCTAssertTrue(try builder.inButtonScope("p"))
        builder.stack.append(boundary)
        XCTAssertFalse(try builder.inButtonScope("p"))
        builder.stack = [html, boundary, p]
        XCTAssertTrue(try builder.inButtonScope("p"))
        builder.stack = [html, boundary]
        XCTAssertFalse(try builder.inButtonScope("p"))
    }

    func testPrivateTrackingMatchesCanonicalScopeAcrossEveryBoundary() throws {
        for boundary in boundaries {
            for preserveCase in [false, true] {
                let builder = HtmlTreeBuilder()
                builder.beginBulkAppend()
                defer { builder.endBulkAppend() }
                let settings = preserveCase ? ParseSettings.preserveCase : ParseSettings.htmlDefault
                func element(_ name: String) throws -> Element {
                    return Element(try Tag.valueOf(preserveCase ? name.uppercased() : name, settings), "")
                }
                func check(file: StaticString = #filePath, line: UInt = #line) throws {
                    XCTAssertEqual(try builder.inButtonScope("p"),
                                   try builder.inScope(Array("p".utf8), ParsingStrings(["button"])),
                                   boundary, file: file, line: line)
                }
                builder.push(try element("html"))
                builder.push(try element("p"))
                let scopeBoundary = try element(boundary)
                builder.push(scopeBoundary)
                try check()
                let ordinary = try element("span")
                builder.push(ordinary)
                builder.push(try element("p"))
                try check()
                builder.pop()
                try check()
                // A middle removal dirties positions; truncation must preserve
                // that state until the canonical rebuild is actually needed.
                builder.removeFromStack(ordinary)
                let closing = try element("i")
                builder.push(closing)
                builder.popStackToClose(closing.nodeNameUTF8())
                try check()
                builder.push(try element("x-custom"))
                try check()
                builder.pop()
                builder.popStackToClose(scopeBoundary.nodeNameUTF8())
                try check()
                builder.push(try element("table"))
                builder.clearStackToTableContext() // no-op clear
                try check()
                builder.clearStackToTableContext()
                try check()
                builder.pop()
                try check()
            }
        }
    }

    func testPrivateFragmentParsingKeepsParagraphInsideScopeBoundary() throws {
        for boundary in ["object", "applet", "marquee"] {
            for sourceRanges in [false, true] {
                let builder = HtmlTreeBuilder()
                let context = Element(try Tag.valueOf("div"), "")
                _ = try builder.parseFragment(Array("<p id=outer>a<\(boundary) id=boundary><p id=inner>b".utf8),
                                              context, [], .noTracking(), ParseSettings(false, false, sourceRanges))
                let container = try XCTUnwrap(builder.doc.getElementById("boundary"))
                let inner = try XCTUnwrap(builder.doc.getElementById("inner"))
                XCTAssertTrue(inner.parent() === container)
                // The fragment construction flag must end when the parse returns.
                try container.tagName("i")
                builder.stack = [try XCTUnwrap(builder.doc.select("html").first()), container]
                XCTAssertFalse(try builder.inButtonScope("p"))
            }
        }
    }

    func testParserReuseResetsTrackingAfterManualMutation() throws {
        let parser = Parser.htmlParser()
        let first = try parser.parseInput("<p>a<button>b", "")
        try XCTUnwrap(first.select("button").first()).tagName("x-custom")
        parser.getTreeBuilder().stack.removeLast()
        try parser.getTreeBuilder().processStartTag("p")
        let second = try parser.parseInput("<p id=outer><object id=boundary><p id=inner>", "")
        XCTAssertTrue(try XCTUnwrap(second.getElementById("inner")).parent() === second.getElementById("boundary"))
        XCTAssertFalse(second === first)
    }

    func testDeepTreeParentLinksRatherThanSourceSerialization() throws {
        let depth = 128
        for sourceRanges in [false, true] {
            let tables = try parse(String(repeating: "<table><tr><td>", count: depth), sourceRanges: sourceRanges)
            let tableNodes = try tables.select("table").array()
            let cells = try tables.select("td").array()
            XCTAssertEqual(tableNodes.count, depth)
            XCTAssertEqual(cells.count, depth)
            for (table, cell) in zip(tableNodes.dropFirst(), cells) { XCTAssertTrue(table.parent() === cell) }
            let paragraphs = try parse(String(repeating: "<font>", count: depth) + String(repeating: "<p>x", count: depth), sourceRanges: sourceRanges)
            let fonts = try paragraphs.select("font").array()
            let ps = try paragraphs.select("p").array()
            XCTAssertEqual(fonts.count, depth)
            XCTAssertEqual(ps.count, depth)
            for (font, parent) in zip(fonts.dropFirst(), fonts) { XCTAssertTrue(font.parent() === parent) }
            for p in ps { XCTAssertTrue(p.parent() === fonts.last) }
        }
    }
}
