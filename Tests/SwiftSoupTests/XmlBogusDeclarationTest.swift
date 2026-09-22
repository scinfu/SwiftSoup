import XCTest
@testable import SwiftSoup

final class XmlBogusDeclarationTest: XCTestCase {
    func testEmptyProcessingInstructionRemainsAComment() throws {
        for (input, data) in [("<??>", "??"), ("<? ?>", "? ?"), ("<! !>", " !"), ("<?/?>", "?/?")] {
            for tracked in [false, true] {
                let doc = try Parser.xmlParser().settings(ParseSettings(true, true, tracked))
                    .parseInput(input + "<root>tail</root>", "https://example.com/")
                XCTAssertEqual(doc.getChildNodes().count, 2, input)
                let comment = try XCTUnwrap(doc.getChildNodes().first as? Comment, input)
                XCTAssertEqual(comment.getData(), data, input)
                XCTAssertEqual(comment.getBaseUri(), "https://example.com/", input)
                doc.outputSettings().prettyPrint(pretty: false)
                let rebuilt = String(decoding: try doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self)
                XCTAssertEqual(rebuilt, "<!--" + data + "--><root>tail</root>", input)
                XCTAssertEqual(try doc.select("root").text(), "tail", input)
            }
        }
    }

    func testValidDeclarationStillRetainsNameAndAttributes() throws {
        for tracked in [false, true] {
            let doc = try Parser.xmlParser().settings(ParseSettings(true, true, tracked))
                .parseInput("<?xml version='1.0'?><root />", "")
            let declaration = try XCTUnwrap(doc.getChildNodes().first as? XmlDeclaration)
            XCTAssertEqual(declaration.name(), "xml")
            XCTAssertEqual(try declaration.attr("version"), "1.0")
            doc.outputSettings().prettyPrint(pretty: false)
            let rebuilt = String(decoding: try doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self)
            XCTAssertEqual(rebuilt, "<?xml version=\"1.0\"?><root />")
        }
    }
}
