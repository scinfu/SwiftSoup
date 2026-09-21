import XCTest
@testable import SwiftSoup

final class ElementWrapNoOpTest: XCTestCase {
    func testNonElementWrappersLeaveTheElementAndTreeUnchanged() throws {
        for wrapper in ["plain text", "<!-- note -->", "text<div></div>"] {
            let document = try SwiftSoup.parse("<main><p id=target>value</p><b>after</b></main>")
            let target = try XCTUnwrap(document.getElementById("target"))
            let parent = target.parent()
            let before = try document.outerHtml()
            XCTAssertTrue(try target.wrap(wrapper) === target)
            XCTAssertTrue(target.parent() === parent)
            XCTAssertEqual(try document.outerHtml(), before)
        }
    }

    func testValidWrapperAndEmptyInputKeepTheirBehavior() throws {
        let document = try SwiftSoup.parse("<p id=target>value</p>")
        let target = try XCTUnwrap(document.getElementById("target"))
        XCTAssertTrue(try target.wrap("<section><div></div></section>") === target)
        XCTAssertEqual(target.parent()?.tagName(), "div")
        XCTAssertEqual(target.parent()?.parent()?.tagName(), "section")
        let before = try document.outerHtml()
        XCTAssertThrowsError(try target.wrap(""))
        XCTAssertEqual(try document.outerHtml(), before)
    }
}
