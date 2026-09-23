import XCTest
@testable import SwiftSoup

final class SourceReuseFragmentMutationTest: XCTestCase {
    private func paragraphs(_ doc: Document) throws -> [String] {
        try doc.select("p").array().map { try $0.text() }
    }

    private func assertRoundTrip(_ doc: Document, _ expected: [String],
                                 file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try paragraphs(doc), expected, file: file, line: line)
        for output in [String(decoding: try doc.outerHtmlUTF8(), as: UTF8.self), try doc.outerHtml()] {
            XCTAssertEqual(try paragraphs(SwiftSoup.parse(output)), expected, file: file, line: line)
        }
    }

    func testInsertionsAndRemovalsInSyntheticBodySurviveCompactOutput() throws {
        for source in ["", "<p>Before</p>", "<html><head></head><body><p>Before</p></body></html>"] {
            let doc = try SwiftSoup.parse(source)
            doc.outputSettings().prettyPrint(pretty: false)
            let body = try XCTUnwrap(doc.body())
            let original = try paragraphs(doc)
            try body.appendElement("p").text("After")
            try assertRoundTrip(doc, original + ["After"])
            try body.prependElement("p").text("First")
            try assertRoundTrip(doc, ["First"] + original + ["After"])
            try doc.select("p").remove()
            try assertRoundTrip(doc, [])
        }
    }

    func testReplacingAndEmptyingSyntheticBodyPreserveTheNewTree() throws {
        let doc = try SwiftSoup.parse("<p>Before</p><p>Discard</p>")
        doc.outputSettings().prettyPrint(pretty: false)
        let body = try XCTUnwrap(doc.body())
        try body.html("<p>Replacement</p>")
        try assertRoundTrip(doc, ["Replacement"])
        body.empty()
        try assertRoundTrip(doc, [])
        try body.appendElement("p").text("Again")
        try assertRoundTrip(doc, ["Again"])
    }

    func testAttributesOnSyntheticShellElementsAreSerialized() throws {
        let doc = try SwiftSoup.parse("<p>Value</p>")
        doc.outputSettings().prettyPrint(pretty: false)
        try doc.body()?.attr("data-body", "updated")
        try doc.select("html").first()?.attr("lang", "ja")
        let reparsed = try SwiftSoup.parse(String(decoding: doc.outerHtmlUTF8(), as: UTF8.self))
        XCTAssertEqual(try reparsed.body()?.attr("data-body"), "updated")
        XCTAssertEqual(try reparsed.select("html").attr("lang"), "ja")
        XCTAssertEqual(try paragraphs(reparsed), ["Value"])
    }

    func testSparseEditStillPreservesUnchangedSourceSpelling() throws {
        let source = "<html><head></head><body><p title='keep'>&copy;</p><b>Before</b></body></html>"
        let doc = try SwiftSoup.parse(source)
        doc.outputSettings().prettyPrint(pretty: false)
        XCTAssertEqual(try doc.outerHtmlUTF8(), Array(source.utf8))
        try doc.select("b").first()?.text("After")
        let output = String(decoding: try doc.outerHtmlUTF8(), as: UTF8.self)
        XCTAssertTrue(output.contains("<p title='keep'>&copy;</p>"))
        XCTAssertEqual(try SwiftSoup.parse(output).select("b").text(), "After")
    }
}
