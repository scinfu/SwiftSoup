import XCTest
@testable import SwiftSoup

final class Libxml2SkipFallbackSmokeTest: SwiftSoupTestCase {
    override class var allowLibxml2Only: Bool { true }

#if canImport(CLibxml2) || canImport(libxml2)
    func testBasicHtmlParse() throws {
        let doc = try SwiftSoup.parse("<div id=one><p>Hello</p></div>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let divs = try doc.getElementsByTag("div")
        XCTAssertEqual(1, divs.size())
        XCTAssertEqual("one", divs.first()?.id())
        XCTAssertEqual("Hello", try divs.first()?.text())
    }

    func testMutationRoundTrip() throws {
        let doc = try SwiftSoup.parse("<div><p>Hello</p></div>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let div = try doc.getElementsByTag("div").first()
        XCTAssertNotNil(div)
        try div?.attr("data-test", "1")
        try div?.append("<span>World</span>")
        let spans = try doc.getElementsByTag("span")
        XCTAssertEqual(1, spans.size())
        XCTAssertEqual("World", try spans.first()?.text())
        XCTAssertEqual("1", try div?.attr("data-test"))
    }

    func testBackendFlagsSet() throws {
        let doc = try SwiftSoup.parse("<div></div>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        XCTAssertTrue(doc.isLibxml2Backend)
        XCTAssertTrue(doc.libxml2SkipSwiftSoupFallbacks)
    }
#endif
}
