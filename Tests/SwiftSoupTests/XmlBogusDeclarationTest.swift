import XCTest
@testable import SwiftSoup

final class XmlBogusDeclarationTest: XCTestCase {
    func testEmptyProcessingInstructionRemainsAComment() throws {
        for input in ["<??>", "<? ?>", "<! !>", "<?/?>"] {
            for tracked in [false, true] {
                let doc = try Parser.xmlParser().settings(ParseSettings(true, true, tracked))
                    .parseInput(input + "<root>tail</root>", "")
                XCTAssertEqual(doc.getChildNodes().count, 2, input)
                XCTAssertTrue(doc.childNode(0) is Comment, input)
                XCTAssertEqual(try doc.select("root").text(), "tail", input)
            }
        }
    }

    func testValidDeclarationStillRetainsNameAndAttributes() throws {
        let doc = try Parser.xmlParser().parseInput("<?xml version='1.0'?><root />", "")
        let declaration = try XCTUnwrap(doc.childNode(0) as? XmlDeclaration)
        XCTAssertEqual(declaration.name(), "xml")
        XCTAssertEqual(try declaration.attr("version"), "1.0")
    }
}
