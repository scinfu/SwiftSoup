import XCTest
@testable import SwiftSoup

final class SourceReuseTableMutationTest: XCTestCase {
    private func assertSerializedParagraphs(_ doc: Document, _ expected: [String],
                                            file: StaticString = #filePath, line: UInt = #line) throws {
        let body = try XCTUnwrap(doc.body(), file: file, line: line)
        let table = try XCTUnwrap(doc.getElementsByTag("table").first(), file: file, line: line)
        let expectedBody = try body.htmlUTF8WithoutSourceReuse()
        let outputs = [
            try body.html(), String(decoding: try body.htmlUTF8(), as: UTF8.self),
            try table.outerHtml(), String(decoding: try table.outerHtmlUTF8Internal(), as: UTF8.self),
            try doc.outerHtml(), String(decoding: try doc.outerHtmlUTF8(), as: UTF8.self)
        ]
        XCTAssertEqual(try doc.getElementsByTag("p").array().map { try $0.text() }, expected,
                       file: file, line: line)
        for output in outputs {
            let reparsed = try SwiftSoup.parse(output)
            XCTAssertEqual(try reparsed.getElementsByTag("p").array().map { try $0.text() }, expected,
                           output, file: file, line: line)
            if !doc.outputSettings().prettyPrint() {
                reparsed.outputSettings().prettyPrint(pretty: false)
                XCTAssertEqual(try reparsed.body()?.htmlUTF8WithoutSourceReuse(), expectedBody,
                               output, file: file, line: line)
            }
        }
    }

    func testRemovalInsideImpliedTbodyIsVisibleInCompactHTML() throws {
        let doc = try SwiftSoup.parse("<table><tr><td><p>KEEP</p><p>STRIP</p></td></tr></table>")
        doc.outputSettings().prettyPrint(pretty: false)
        try doc.getElementsByTag("p").get(1).remove()
        XCTAssertEqual(try doc.body()?.html(), "<table><tbody><tr><td><p>KEEP</p></td></tr></tbody></table>")
        try assertSerializedParagraphs(doc, ["KEEP"])
    }

    func testRemovalWithExplicitAndImpliedTbodyAcrossQueryRoutes() throws {
        for explicitTbody in [false, true] {
            for tableAttributes in ["", " class='data' id='table'"] {
                for pretty in [false, true] {
                    for query in ["tag", "p", "p.strip", "#strip"] {
                        let row = "<tr><td><p>KEEP</p><p class='strip' id='strip'>STRIP</p></td></tr>"
                        let contents = explicitTbody ? "<tbody>\(row)</tbody>" : row
                        let doc = try SwiftSoup.parse("<table\(tableAttributes)>\(contents)</table>")
                        doc.outputSettings().prettyPrint(pretty: pretty)
                        let target = query == "tag" ? try doc.getElementsByTag("p").get(1)
                            : try doc.select(query).get(query == "p" ? 1 : 0)
                        try target.remove()
                        try assertSerializedParagraphs(doc, ["KEEP"])
                    }
                }
            }
        }
    }

    func testNestedImpliedTbodiesDoNotHideRemoval() throws {
        let doc = try SwiftSoup.parse(
            "<table><tr><td><p>OUTER</p><table><tr><td><p>KEEP</p><p>STRIP</p>" +
            "</td></tr></table></td></tr></table>"
        )
        doc.outputSettings().prettyPrint(pretty: false)
        try doc.getElementsByTag("p").get(2).remove()
        try assertSerializedParagraphs(doc, ["OUTER", "KEEP"])
    }

    func testRepeatedMutationsOfAlreadyDirtySyntheticTbodyAreVisible() throws {
        let doc = try SwiftSoup.parse("<table><tr><td><p>KEEP</p><p>STRIP</p></td></tr></table>")
        doc.outputSettings().prettyPrint(pretty: false)
        let tbody = try XCTUnwrap(doc.getElementsByTag("tbody").first())
        try tbody.attr("data-state", "first")
        try assertSerializedParagraphs(doc, ["KEEP", "STRIP"])
        XCTAssertTrue(try doc.body()!.html().contains("data-state=\"first\""))
        try doc.getElementsByTag("p").get(1).remove()
        try tbody.attr("data-state", "second")
        try doc.getElementsByTag("p").get(0).text("UPDATED")
        try assertSerializedParagraphs(doc, ["UPDATED"])
        XCTAssertTrue(try doc.body()!.html().contains("data-state=\"second\""))
    }

    func testUnmutatedTableKeepsOriginalSourceAfterAttributeQueries() throws {
        let source = "<table class='data'><tr><td><p class='keep'>&copy;</p></td></tr></table>"
        let doc = try SwiftSoup.parse(source)
        doc.outputSettings().prettyPrint(pretty: false)
        let originalBytes = try doc.outerHtmlUTF8()
        XCTAssertEqual(try doc.body()?.html(), source)
        XCTAssertEqual(try doc.select("p.keep").size(), 1)
        XCTAssertEqual(try doc.getElementsByTag("table").first()?.attr("class"), "data")
        XCTAssertEqual(try doc.body()?.html(), source)
        XCTAssertEqual(try doc.outerHtmlUTF8(), originalBytes)
    }

    func testCellAndSyntheticTbodyEditsPreserveTheCompleteSerializedTree() throws {
        let edits: [(String, [String], (Document, Element) throws -> Void)] = [
            ("append", ["KEEP", "STRIP", "AFTER"], { _, cell in try cell.append("<p>AFTER</p>") }),
            ("prepend", ["BEFORE", "KEEP", "STRIP"], { _, cell in try cell.prepend("<p>BEFORE</p>") }),
            ("replace", ["KEEP", "UPDATED"], { doc, _ in
                let replacement = try Element(Tag.valueOf("p"), "").text("UPDATED")
                try doc.getElementsByTag("p").get(1).replaceWith(replacement)
            }),
            ("empty", [], { _, cell in cell.empty() }),
            ("wrap", ["KEEP", "STRIP"], { doc, _ in
                try doc.getElementsByTag("p").get(1).wrap("<div class='wrapper'></div>")
            }),
            ("unwrap", ["KEEP"], { doc, _ in try doc.getElementsByTag("p").get(1).unwrap() }),
            ("synthetic attribute", ["KEEP", "STRIP"], { doc, _ in
                try doc.getElementsByTag("tbody").get(0).attr("data-state", "updated")
            }),
            ("retained attribute", ["KEEP", "STRIP"], { _, cell in
                let attribute = try XCTUnwrap(cell.getAttributes()?.asList().first)
                _ = attribute.setValue(value: Array("updated".utf8))
            }),
            ("retained text", ["UPDATED", "STRIP"], { doc, _ in
                let text = try XCTUnwrap(doc.getElementsByTag("p").get(0).textNodes().first)
                text.text("UPDATED")
            })
        ]
        for (_, expected, edit) in edits {
            let doc = try SwiftSoup.parse("<table><tr><td data-state='original'><p>KEEP</p><p>STRIP</p></td></tr></table>")
            doc.outputSettings().prettyPrint(pretty: false)
            let cell = try doc.getElementsByTag("td").get(0)
            try edit(doc, cell)
            try assertSerializedParagraphs(doc, expected)
        }
    }

    func testMovingParagraphBetweenCellsDoesNotReplayTheOldTree() throws {
        let doc = try SwiftSoup.parse(
            "<table><tr><td><p>ONE</p><p>TWO</p></td><td><p>THREE</p></td></tr></table>"
        )
        doc.outputSettings().prettyPrint(pretty: false)
        let moved = try doc.getElementsByTag("p").get(1)
        try doc.getElementsByTag("td").get(1).appendChild(moved)
        try assertSerializedParagraphs(doc, ["ONE", "THREE", "TWO"])
    }
}
