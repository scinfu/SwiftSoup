import Foundation
import XCTest
import SwiftSoup

final class XmlFormatDetectionTest: XCTestCase {
    func testUtf8BomBeforeXmlDeclaration() throws {
        for whitespace in ["", " \t\r\n"] {
            let xml = "\u{FEFF}\(whitespace)<?xml version=\"1.0\"?><Root><link>one</link><img>two</img></Root>"
            let explicit = try SwiftSoup.parseXML(xml)
            for doc in [try SwiftSoup.parse(xml), try SwiftSoup.parse(Data(xml.utf8))] {
                XCTAssertEqual(doc.outputSettings().syntax(), .xml)
                XCTAssertEqual(try doc.select("link").text(), "one")
                XCTAssertEqual(try doc.select("img").text(), "two")
                XCTAssertEqual(try doc.outerHtml(), try explicit.outerHtml())
            }
        }
    }

    func testProcessingInstructionsWithXmlPrefixDoNotSelectXmlParser() throws {
        for target in ["xml-stylesheet", "xmlfoo", "xml:foo", "xml_foo", "xml日本"] {
            let html = "<?\(target) href=\"style.css\"?><DIV><P>one<P>two</DIV>"
            let explicit = try SwiftSoup.parseHTML(html)
            for doc in [try SwiftSoup.parse(html), try SwiftSoup.parse(Data(html.utf8))] {
                XCTAssertEqual(doc.outputSettings().syntax(), .html, target)
                XCTAssertEqual(try doc.outerHtml(), try explicit.outerHtml(), target)
                XCTAssertEqual(try doc.select("div > p").count, 2, target)
            }
        }
    }

    func testDeclarationWhitespaceAndToleratedEndings() throws {
        for ending in [" version=\"1.0\"?>", "\tversion=\"1.0\"?>", "\rversion=\"1.0\"?>", "\nversion=\"1.0\"?>", "?>", ">", ""] {
            let xml = "<?xml\(ending)"
            for doc in [try SwiftSoup.parse(xml), try SwiftSoup.parse(Data(xml.utf8))] {
                XCTAssertEqual(doc.outputSettings().syntax(), .xml, xml)
            }
        }
    }

    func testShortAndNonXmlBomInputStaysHtml() throws {
        for html in ["", " ", "<", "<?", "<?x", "<?xm", "\u{FEFF}", "\u{FEFF}<P>one", "\u{FEFF}<?xml-stylesheet?>"] {
            for doc in [try SwiftSoup.parse(html), try SwiftSoup.parse(Data(html.utf8))] {
                XCTAssertEqual(doc.outputSettings().syntax(), .html, html)
            }
        }
    }

    func testExplicitHtmlStillOverridesBomAndXmlDeclaration() throws {
        let xml = "\u{FEFF}<?xml version=\"1.0\"?><Root><link>one</link></Root>"
        for doc in [try SwiftSoup.parseHTML(xml), try SwiftSoup.parseHTML(Data(xml.utf8))] {
            XCTAssertEqual(doc.outputSettings().syntax(), .html)
            XCTAssertNotEqual(try doc.select("link").text(), "one")
        }
    }
}
