import XCTest
import SwiftSoup

final class DocumentTypeSystemIdentifierTest: XCTestCase {
    private let systemID = "https://example.com/example.dtd"

    func testStringAndByteConstructorsInferSystemKeyword() throws {
        let expected = "<!DOCTYPE root SYSTEM \"" + systemID + "\">"
        for node in [
            DocumentType("root", "", systemID, ""),
            DocumentType(Array("root".utf8), [], Array(systemID.utf8), [])
        ] {
            XCTAssertEqual(try node.attr("pubSysKey"), "SYSTEM")
            XCTAssertEqual(try node.outerHtml(), expected)
        }
    }

    func testSystemIdentifierSurvivesHtmlAndXmlRoundTrips() throws {
        let source = try DocumentType("root", "", systemID, "").outerHtml() + "<root></root>"
        for parser in [Parser.htmlParser(), Parser.xmlParser()] {
            let document = try parser.parseInput(source, "")
            let node = try XCTUnwrap(document.getChildNodes().first as? DocumentType)
            XCTAssertEqual(try node.attr("name"), "root")
            XCTAssertEqual(try node.attr("pubSysKey"), "SYSTEM")
            XCTAssertEqual(try node.attr("publicId"), "")
            XCTAssertEqual(try node.attr("systemId"), systemID)
            XCTAssertEqual(try node.outerHtml(), "<!DOCTYPE root SYSTEM \"" + systemID + "\">")
        }
    }

    func testPublicIdentifierKeepsPrecedenceAndBlankIdentifiersStayHtml5() throws {
        for systemID in ["", self.systemID] {
            let node = DocumentType("html", "-//Example//DTD Example//EN", systemID, "")
            XCTAssertEqual(try node.attr("pubSysKey"), "PUBLIC")
            XCTAssertTrue(try node.outerHtml().contains(" PUBLIC "))
        }
        for blank in ["", " \t\n"] {
            let node = DocumentType("html", blank, blank, "")
            XCTAssertEqual(try node.attr("pubSysKey"), "")
            XCTAssertEqual(try node.outerHtml(), "<!doctype html>")
        }
    }

    func testClonesAndDocumentSerializationRetainSystemKeyword() throws {
        let node = DocumentType("root", "", systemID, "")
        let clone = try XCTUnwrap(node.copy() as? DocumentType)
        let expected = "<!DOCTYPE root SYSTEM \"" + systemID + "\">"
        XCTAssertEqual(try clone.outerHtml(), expected)
        let document = Document("")
        document.outputSettings().syntax(syntax: .xml).prettyPrint(pretty: false)
        try document.appendChild(node)
        try document.appendElement("root")
        XCTAssertTrue(try document.outerHtml().hasPrefix(expected))
        let copiedDocument = try XCTUnwrap(document.copy() as? Document)
        XCTAssertTrue(try copiedDocument.outerHtml().hasPrefix(expected))
    }
}
