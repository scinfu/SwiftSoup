import Foundation
import XCTest
import SwiftSoup

final class RcdataMixedCaseEndTagTest: XCTestCase {
    private let content = "alpha<b>literal</b>&amp;日本😀"
    private let expectedText = "alpha<b>literal</b>&日本😀"

    private func markup(_ tag: String, _ closing: String) -> String {
        "<\(tag) id='target'>\(content)</\(closing)><p id='after'>tail</p>"
    }

    private func checkDOM(_ document: Document, file: StaticString = #filePath, line: UInt = #line) throws {
        let target = try XCTUnwrap(document.getElementById("target"), file: file, line: line)
        XCTAssertEqual(try target.text(), expectedText, file: file, line: line)
        XCTAssertTrue(target.children().isEmpty, file: file, line: line)
        XCTAssertTrue(try document.select("b").isEmpty, file: file, line: line)
        let after = try XCTUnwrap(document.getElementById("after"), file: file, line: line)
        XCTAssertEqual(try after.text(), "tail", file: file, line: line)
        XCTAssertTrue(after.parent() === document.body(), file: file, line: line)
    }

    func testEveryClosingTagCasePatternWithBothSourcePolicies() throws {
        for tag in ["title", "textarea"] {
            let bytes = Array(tag.utf8)
            for mask in 0..<(1 << bytes.count) {
                let closing = String(decoding: bytes.enumerated().map { offset, byte in
                    mask & (1 << offset) == 0 ? byte : byte - 32
                }, as: UTF8.self)
                for trackSource in [false, true] {
                    let parser = Parser.htmlParser().settings(ParseSettings(false, false, trackSource))
                    try checkDOM(parser.parseInput(markup(tag, closing), ""))
                }
            }
        }
    }

    func testStringDataAndBorrowedInputParsersPreserveLiteralMarkup() throws {
        for (tag, closing) in [("title", "TiTlE"), ("textarea", "TeXtArEa")] {
            let input = markup(tag, closing)
            try checkDOM(SwiftSoup.parse(input))
            try checkDOM(SwiftSoup.parse(Data(input.utf8)))
            try checkDOM(Parser.htmlParser().parseInput(Array(input.utf8), ""))
            let bytes = Array(input.utf8)
            let document = try SwiftSoup.parse(withBytes: { parse in
                try bytes.withUnsafeBufferPointer { try parse($0) }
            })
            try checkDOM(document)
        }
    }

    func testMutationAndBothSerializersRetainTheCorrectDOM() throws {
        for (tag, closing) in [("title", "TiTlE"), ("textarea", "TeXtArEa")] {
            let document = try SwiftSoup.parse(markup(tag, closing))
            try checkDOM(document)
            let target = try XCTUnwrap(document.getElementById("target"))
            try target.attr("data-edited", "yes")
            document.outputSettings().prettyPrint(pretty: false)
            for bytes in [try document.outerHtmlUTF8(), try document.outerHtmlUTF8WithoutSourceReuse()] {
                let reparsed = try SwiftSoup.parse(String(decoding: bytes, as: UTF8.self))
                try checkDOM(reparsed)
                XCTAssertEqual(try reparsed.getElementById("target")?.attr("data-edited"), "yes")
            }
        }
    }

    func testMissingAndUnrelatedClosingTagsRetainLegacyRecovery() throws {
        for tail in ["", "</TeXtArEa>"] {
            let document = try SwiftSoup.parse("<title>alpha<b>literal\(tail)<p id='after'>tail</p>")
            XCTAssertEqual(try document.select("title").text(), "alpha")
            XCTAssertEqual(try document.select("b").size(), 1)
            XCTAssertEqual(try document.getElementById("after")?.text(), "tail")
        }
    }

    func testPublicConsistentCaseLookaheadContractIsUnchanged() {
        let reader = CharacterReader("One TWO three")
        XCTAssertFalse(reader.containsIgnoreCase("one"))
        XCTAssertTrue(reader.containsIgnoreCase("two"))
        XCTAssertTrue(reader.containsIgnoreCase("three"))
        let closing = CharacterReader("</TiTlE>")
        XCTAssertFalse(closing.containsIgnoreCase(prefix: Array("</".utf8), suffix: Array("title".utf8)))
        XCTAssertEqual(closing.getPos(), 0)
    }

    func testTextareaPreservesLegacyInitialWhitespaceOnRoundTrip() throws {
        for trackSource in [false, true] {
            for (input, expected) in [("\n\n日本", "\n\n日本"), ("\n日本", "\n日本"),
                                      ("\n", "\n"), (" 日本\n", " 日本\n")] {
                let parser = Parser.htmlParser().settings(ParseSettings(false, false, trackSource))
                let document = try parser.parseInput("<textarea id='target'>\(input)</textarea>", "")
                let target = try XCTUnwrap(document.getElementById("target"))
                XCTAssertEqual(target.textNodes().map { $0.getWholeText() }.joined(), expected)
                try target.attr("data-edited", "yes")
                document.outputSettings().prettyPrint(pretty: false)
                for bytes in [try document.outerHtmlUTF8(), try document.outerHtmlUTF8WithoutSourceReuse()] {
                    let reparsed = try SwiftSoup.parse(String(decoding: bytes, as: UTF8.self))
                    let value = try XCTUnwrap(reparsed.getElementById("target"))
                    XCTAssertEqual(value.textNodes().map { $0.getWholeText() }.joined(), expected)
                }
            }
        }
    }

    func testTextareaReturnsToBodyAndDoesNotReconstructFormattingInsideIt() throws {
        let document = try SwiftSoup.parse("<form><b><textarea id='target' name='message'>x<i>y</i>&amp;z</TeXtArEa>after</b><input name='next'></form>")
        let target = try XCTUnwrap(document.getElementById("target"))
        XCTAssertEqual(try target.val(), "x<i>y</i>&z")
        XCTAssertTrue(target.children().isEmpty)
        XCTAssertTrue(try document.select("i").isEmpty)
        XCTAssertEqual(try document.select("form > b > textarea").size(), 1)
        XCTAssertEqual(try document.select("form > input").size(), 1)
        XCTAssertEqual(try document.select("b").text(), "x<i>y</i>&zafter")
    }
}
