import XCTest
@testable import SwiftSoup

final class DocumentCloneStateTest: XCTestCase {
    func testDeepCopiesPreserveDocumentStateAndIndependentOutputSettings() throws {
        for xml in [false, true] {
            let parser = xml ? Parser.xmlParser() : Parser.htmlParser()
            let original = try parser.parseInput("<root><input disabled=\"disabled\" />日本</root>", "https://example.com/")
            original.outputSettings().prettyPrint(pretty: false).charset(.ascii)
                .escapeMode(.xhtml).outline(outlineMode: true).indentAmount(indentAmount: 3)
            original.quirksMode(.limitedQuirks)
            original.updateMetaCharsetElement(true)

            for clone in [original.copy() as! Document, original.copy(with: nil) as! Document] {
                XCTAssertEqual(clone.outputSettings().syntax(), original.outputSettings().syntax())
                XCTAssertEqual(clone.charset(), .ascii)
                XCTAssertEqual(clone.outputSettings().escapeMode(), .xhtml)
                XCTAssertFalse(clone.outputSettings().prettyPrint())
                XCTAssertTrue(clone.outputSettings().outline())
                XCTAssertEqual(clone.outputSettings().indentAmount(), 3)
                XCTAssertEqual(clone.quirksMode(), .limitedQuirks)
                XCTAssertTrue(clone.updateMetaCharsetElement())
                XCTAssertEqual(clone.parsedAsXml, xml)
                XCTAssertNil(clone.sourceBuffer)
                XCTAssertNil(clone.parent())
                XCTAssertFalse(clone.outputSettings() === original.outputSettings())
                XCTAssertEqual(try clone.outerHtmlUTF8WithoutSourceReuse(), try original.outerHtmlUTF8WithoutSourceReuse())

                clone.outputSettings().charset(.utf8).prettyPrint(pretty: true)
                    .escapeMode(.extended).outline(outlineMode: false).indentAmount(indentAmount: 1)
                clone.quirksMode(.noQuirks)
                clone.updateMetaCharsetElement(false)
                XCTAssertEqual(original.charset(), .ascii)
                XCTAssertFalse(original.outputSettings().prettyPrint())
                XCTAssertEqual(original.outputSettings().escapeMode(), .xhtml)
                XCTAssertTrue(original.outputSettings().outline())
                XCTAssertEqual(original.outputSettings().indentAmount(), 3)
                XCTAssertEqual(original.quirksMode(), .limitedQuirks)
                XCTAssertTrue(original.updateMetaCharsetElement())
            }
        }
    }

    func testXMLCopyRetainsEscapingAndSerializationPolicy() throws {
        let original = try Parser.xmlParser().parseInput("<root>日本 &amp; text</root>", "")
        original.outputSettings().prettyPrint(pretty: false).charset(.ascii)
        let clone = original.copy() as! Document
        let expected = "<root>&#x65e5;&#x672c; &amp; text</root>"
        XCTAssertEqual(try original.outerHtml(), expected)
        XCTAssertEqual(try clone.outerHtml(), expected)
        XCTAssertTrue(try clone.outerHtmlUTF8().allSatisfy { $0 < 128 })
    }
}
