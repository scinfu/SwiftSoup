import XCTest
@testable import SwiftSoup

final class Libxml2SkipFallbackCompatTest: SwiftSoupTestCase {
    override class var allowLibxml2Only: Bool { true }

#if canImport(CLibxml2) || canImport(libxml2)
    func testSelectByIdAndClass() throws {
        let html = "<div id=container><p class=lead>Hello</p><p class=lead>World</p></div>"
        let doc = try SwiftSoup.parse(html, backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let container = try doc.getElementById("container")
        XCTAssertNotNil(container)
        let leads = try doc.select("p.lead")
        XCTAssertEqual(2, leads.size())
        XCTAssertEqual("Hello", try leads.first()?.text())
    }

    func testMutationUpdatesOutput() throws {
        let doc = try SwiftSoup.parse("<ul><li>One</li></ul>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let ul = try doc.select("ul").first()
        XCTAssertNotNil(ul)
        try ul?.append("<li>Two</li>")
        let items = try doc.select("li")
        XCTAssertEqual(2, items.size())
        XCTAssertEqual("Two", try items.last()?.text())
    }

    func testAttributeRoundTrip() throws {
        let doc = try SwiftSoup.parse("<a href=/path>Link</a>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let link = try doc.select("a").first()
        XCTAssertNotNil(link)
        XCTAssertEqual("/path", try link?.attr("href"))
        try link?.attr("data-test", "ok")
        XCTAssertEqual("ok", try link?.attr("data-test"))
    }

    func testGroupSelectorUsesXPathPath() throws {
        let html = "<article><p class=lead>Hi</p><span>Yo</span><a href=/x>Link</a></article>"
        let doc = try SwiftSoup.parse(html, backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let results = try doc.select("article, p.lead, a[href]")
        XCTAssertEqual(3, results.size())
        XCTAssertEqual("article", results.get(0).tagName())
        XCTAssertEqual("p", results.get(1).tagName())
        XCTAssertEqual("a", results.get(2).tagName())
    }

    
#endif
}
