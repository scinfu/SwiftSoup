import XCTest
@testable import SwiftSoup

final class UnicodeBlockSpacingTest: XCTestCase {
    func testBlockBoundaryAfterNonASCIIText() throws {
        for word in ["påse", "東京", "😀", String(repeating: "é", count: 40)] {
            let doc = try SwiftSoup.parse("<li><div>a <abbr>\(word)</abbr></div><div>grona</div></li>")
            XCTAssertEqual(try doc.select("li").first()!.text(), "a \(word) grona")
        }
    }

    func testInlineTextRemainsAdjacent() throws {
        XCTAssertEqual(try SwiftSoup.parse("<p>smör<b>gås</b>tårta</p>").text(), "smörgåstårta")
        XCTAssertEqual(try SwiftSoup.parse("<p>a <b>é</b> b</p>").text(), "a é b")
    }

    func testASCIIAndNonBreakingSpaceControls() throws {
        XCTAssertEqual(try SwiftSoup.parse("<div>a <b>pase</b></div><div>next</div>").text(), "a pase next")
        XCTAssertEqual(try SwiftSoup.parse("<div>a <b>é&nbsp;</b></div><div>next</div>").text(), "a é next")
    }
}
