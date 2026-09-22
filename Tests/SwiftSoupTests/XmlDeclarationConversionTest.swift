import XCTest
@testable import SwiftSoup

final class XmlDeclarationConversionTest: XCTestCase {
    func testBogusInstructionsRemainComments() throws {
        for (data, tracked) in [("???", false), ("????", true)] {
            let doc = try Parser.xmlParser().settings(ParseSettings(true, true, tracked))
                .parseInput("<" + data + "><root>tail</root>", "")
            let comment = try XCTUnwrap(doc.getChildNodes().first as? Comment)
            XCTAssertEqual(comment.getData(), data)
            XCTAssertEqual(doc.getChildNodes().count, 2)
            XCTAssertEqual(try doc.select("root").text(), "tail")
        }
    }

    func testDeclarationsStillPreserveCaseAndXmlAttributeValues() throws {
        let doc = try Parser.xmlParser().parseInput("<?Target mixedCase='&#128;'?><root />", "")
        let declaration = try XCTUnwrap(doc.getChildNodes().first as? XmlDeclaration)
        XCTAssertEqual(declaration.name(), "Target")
        XCTAssertEqual(try declaration.attr("mixedCase").unicodeScalars.map(\.value), [0x80])
    }
}
