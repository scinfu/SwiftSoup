import XCTest
@testable import SwiftSoup

final class ParserReuseIsolationTest: XCTestCase {
    func testReusedParserDoesNotCarryActiveFormattingElementsIntoNextDocument() throws {
        let parser = Parser.htmlParser()

        let first = try parser.parseInput("<b>first", "")
        XCTAssertEqual(try first.body()?.html(), "<b>first</b>")

        let second = try parser.parseInput("<p>second</p>", "")
        XCTAssertEqual(try second.body()?.html(), "<p>second</p>")
        XCTAssertEqual(try second.select("b").size(), 0)
    }

    func testReusedParserDoesNotCarryFormPointerIntoNextDocument() throws {
        let parser = Parser.htmlParser()

        let first = try parser.parseInput("<form id=first><input name=a>", "")
        let firstForm = try XCTUnwrap(first.getElementById("first") as? FormElement)
        XCTAssertEqual(firstForm.elements().size(), 1)

        let second = try parser.parseInput("<form id=second><input name=b>", "")
        let secondForm = try XCTUnwrap(second.getElementById("second") as? FormElement)
        XCTAssertEqual(secondForm.elements().size(), 1)
        XCTAssertEqual(try secondForm.elements().first()?.attr("name"), "b")

        XCTAssertEqual(firstForm.elements().size(), 1)
        XCTAssertEqual(try firstForm.elements().first()?.attr("name"), "a")
    }

    func testFullParseAfterFragmentParseResetsFragmentAndFormattingState() throws {
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(
            Array("<b>fragment".utf8),
            context,
            [],
            .noTracking(),
            .htmlDefault
        )

        let document = try builder.parse(
            Array("<p>document</p>".utf8),
            [],
            .noTracking(),
            .htmlDefault
        )

        XCTAssertFalse(builder.isFragmentParsing())
        XCTAssertEqual(try document.body()?.html(), "<p>document</p>")
        XCTAssertEqual(try document.select("b").size(), 0)
    }

    func testUnsafeBufferParseReuseRunsTheSameStateReset() throws {
        let builder = HtmlTreeBuilder()

        func parse(_ html: String) throws -> Document {
            let bytes = Array(html.utf8)
            return try bytes.withUnsafeBufferPointer { buffer in
                try builder.parse(
                    buffer,
                    owner: nil,
                    [],
                    .noTracking(),
                    .htmlDefault
                )
            }
        }

        _ = try parse("<b>first")
        let second = try parse("<p>second</p>")

        XCTAssertEqual(try second.body()?.html(), "<p>second</p>")
        XCTAssertEqual(try second.select("b").size(), 0)
    }
}
