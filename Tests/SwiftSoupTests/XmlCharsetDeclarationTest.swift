import Foundation
import XCTest
import SwiftSoup

final class XmlCharsetDeclarationTest: XCTestCase {
    private func declaration(_ document: Document) throws -> XmlDeclaration {
        let value = try XCTUnwrap(document.getChildNodes().first as? XmlDeclaration)
        XCTAssertEqual(value.name(), "xml")
        return value
    }

    func testCharsetUpdatePreservesExistingVersionAndOtherAttributes() throws {
        for version in ["1.0", "1.1"] {
            let document = try Parser.xmlParser().parseInput(
                "<?xml version='" + version + "' encoding='old' standalone='yes'?><root>日本</root>", "")
            let original = try declaration(document)
            for charset in [String.Encoding.utf8, .ascii] {
                try document.charset(charset)
                let updated = try declaration(document)
                XCTAssertTrue(updated === original)
                XCTAssertEqual(try updated.attr("version"), version)
                XCTAssertEqual(try updated.attr("encoding"), charset.displayName())
                XCTAssertEqual(try updated.attr("standalone"), "yes")
                XCTAssertEqual(document.charset(), charset)
                XCTAssertEqual(document.getChildNodes().compactMap { $0 as? XmlDeclaration }.count, 1)
                let roundTrip = try Parser.xmlParser().parseInput(document.outerHtml(), "")
                XCTAssertEqual(try declaration(roundTrip).attr("version"), version)
            }
        }
    }

    func testMissingOrEmptyVersionDefaultsToOnePointZero() throws {
        for versionAttribute in ["", " version=''"] {
            let document = try Parser.xmlParser().parseInput(
                "<?xml" + versionAttribute + " encoding='old'?><root />", "")
            try document.charset(.utf8)
            XCTAssertEqual(try declaration(document).attr("version"), "1.0")
            XCTAssertEqual(try declaration(document).attr("encoding"), String.Encoding.utf8.displayName())
        }
    }

    func testEmptyXmlDocumentsReceiveOneDeclaration() throws {
        for document in [Document(""), try Parser.xmlParser().parseInput("", "")] {
            document.outputSettings().syntax(syntax: .xml)
            try document.charset(.utf8)
            let first = try declaration(document)
            XCTAssertEqual(try first.attr("version"), "1.0")
            XCTAssertEqual(document.getChildNodes().count, 1)
            try document.charset(.ascii)
            XCTAssertTrue(try declaration(document) === first)
            XCTAssertEqual(try first.attr("encoding"), String.Encoding.ascii.displayName())
            XCTAssertEqual(document.getChildNodes().count, 1)
        }
    }

    func testNewDeclarationPreservesExistingLeadingNodes() throws {
        for source in ["<root />", "<!--keep--><root />", "<?other value='keep'?><root />"] {
            let document = try Parser.xmlParser().parseInput(source, "")
            let original = document.getChildNodes()
            try document.charset(.utf8)
            XCTAssertEqual(try declaration(document).attr("version"), "1.0")
            XCTAssertEqual(document.getChildNodes().count, original.count + 1)
            for (left, right) in zip(document.getChildNodes().dropFirst(), original) {
                XCTAssertTrue(left === right)
            }
        }
    }
}
