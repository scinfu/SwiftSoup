import XCTest
@testable import SwiftSoup

final class XmlBorrowedInitializationTest: XCTestCase {
    func testBorrowedXmlPreservesSyntaxAndSerialization() throws {
        let xml = "<Root><script>A&amp;B&lt;C</script><link>one</link><empty /></Root>"
        let bytes = Array(xml.utf8)
        for trackSource in [false, true] {
            let settings = ParseSettings(true, true, trackSource)
            let owned = try Parser.xmlParser().settings(settings).parseInput(bytes, "")
            try bytes.withUnsafeBufferPointer { buffer in
                let builder = XmlTreeBuilder()
                builder.initialiseParse(buffer, owner: nil, [], ParseErrorList.noTracking(), settings)
                XCTAssertEqual(builder.stack.count, 1)
                XCTAssertTrue(builder.stack.first === builder.doc)
                try builder.runParser()
                let borrowed = builder.doc
                XCTAssertEqual(borrowed.outputSettings().syntax(), .xml)
                XCTAssertTrue(borrowed.parsedAsXml)
                for doc in [owned, borrowed] {
                    doc.outputSettings().prettyPrint(pretty: false)
                }
                XCTAssertEqual(try borrowed.outerHtml(), try owned.outerHtml())
                XCTAssertEqual(try borrowed.outerHtmlUTF8WithoutSourceReuse(), try owned.outerHtmlUTF8WithoutSourceReuse())
                XCTAssertEqual(try borrowed.select("script").text(), "A&B<C")
                try borrowed.select("script").first()?.text("D&E<F")
                try owned.select("script").first()?.text("D&E<F")
                XCTAssertEqual(try borrowed.outerHtml(), try owned.outerHtml())
                XCTAssertTrue(try borrowed.outerHtml().contains("D&amp;E&lt;F"))
            }
        }
    }

    func testBuilderReuseAcrossOwnedAndBorrowedInputs() throws {
        let builder = XmlTreeBuilder()
        let bytes = Array("<Root><script>A&amp;B</script><empty /></Root>".utf8)
        for trackSource in [true, false, true] {
            let settings = ParseSettings(true, true, trackSource)
            let owned = try builder.parse(bytes, [], ParseErrorList.noTracking(), settings)
            try bytes.withUnsafeBufferPointer { buffer in
                let borrowed = try builder.parse(buffer, owner: nil, [], ParseErrorList.noTracking(), settings)
                XCTAssertEqual(borrowed.outputSettings().syntax(), .xml)
                XCTAssertTrue(borrowed.parsedAsXml)
                XCTAssertEqual(try borrowed.outerHtml(), try owned.outerHtml())
                XCTAssertEqual(borrowed.children().count, 1)
            }
        }
    }
}
