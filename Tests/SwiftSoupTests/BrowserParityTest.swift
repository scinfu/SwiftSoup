import XCTest
@testable import SwiftSoup

/// BrowseCraft: the rule engine (html5lib) and the app (SwiftSoup, WebKit) must build the
/// same tree from the same page, or a selector learned on one side matches nothing on the other.
final class BrowserParityTest: XCTestCase {
    func testRepeatedAttributeNameKeepsTheFirstOccurrence() throws {
        let doc = try SwiftSoup.parse(#"<a class="movie-list-subject cr2" href="/s" class="hot-item">t</a><input class="first" class="second">"#)
        XCTAssertEqual(try doc.select("a").first()?.className(), "movie-list-subject cr2")
        XCTAssertEqual(try doc.select("input").first()?.className(), "first")
        XCTAssertEqual(try doc.select(".hot-item, .second").size(), 0)
    }

    func testBlockStartTagClosesAnOpenParagraph() throws {
        let doc = try SwiftSoup.parse(#"<li><p class="vodlist_title"><center><a href="/voddetail/1/">t</a></center></p></li>"#)
        XCTAssertEqual(try doc.select("[class*='title'] a").size(), 0)
        XCTAssertEqual(try doc.select("p.vodlist_title").first()?.children().size(), 0)
        XCTAssertEqual(try doc.select("li > center > a").size(), 1)
    }
}
