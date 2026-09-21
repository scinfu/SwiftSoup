import XCTest
@testable import SwiftSoup

final class DetachedElementMatchesTest: XCTestCase {
    func testStandaloneElementMatchesStringAndParsedSelectors() throws {
        let element = try Element(Tag.valueOf("p"), "")
        try element.attr("class", "hit")
        for query in ["p", ".hit", "*", ":root"] {
            XCTAssertTrue(try element.iS(query), query)
            XCTAssertTrue(try element.iS(QueryParser.parse(query)), query)
        }
        XCTAssertFalse(try element.iS("div"))
        XCTAssertFalse(try element.iS(".missing"))
        XCTAssertTrue(try Elements([element]).iS("p.hit"))
    }

    func testRemovedSubtreeRetainsAncestorAndSiblingMatching() throws {
        let document = try SwiftSoup.parse("<section><div><p id=a>one</p><p id=b>two</p></div></section>")
        let root = try XCTUnwrap(document.select("div").first())
        let a = try XCTUnwrap(root.getElementById("a"))
        let b = try XCTUnwrap(root.getElementById("b"))
        try root.remove()
        XCTAssertNil(b.ownerDocument())
        XCTAssertTrue(try root.iS(":root"))
        XCTAssertTrue(try root.iS("div:has(> p)"))
        XCTAssertTrue(try a.iS("div > p:first-child"))
        XCTAssertTrue(try b.iS("p + p:last-child"))
        XCTAssertFalse(try b.iS(":root"))
        XCTAssertFalse(try b.iS("section p"))
    }

    func testDeepCopiedElementMatchesWithoutAParentDocument() throws {
        let document = try SwiftSoup.parse("<div><b class=hit>value</b></div>")
        let clone = try XCTUnwrap(document.select("div").first()?.copy() as? Element)
        XCTAssertTrue(try clone.iS("div:has(.hit)"))
        XCTAssertTrue(try XCTUnwrap(clone.select("b").first()).iS("div > b.hit"))
    }
}
