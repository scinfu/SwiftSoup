import XCTest
import SwiftSoup

final class ElementsEqBoundaryTest: XCTestCase {
    private final class LookupProbe: Elements {
        var requestedIndexes: [Int] = []
        let sentinel: Element

        init(_ sentinel: Element) {
            self.sentinel = sentinel
            super.init([sentinel])
        }

        override func get(_ index: Int) -> Element {
            requestedIndexes.append(index)
            return sentinel // Keep the baseline probe safe for negative indexes.
        }
    }

    func testInvalidIndexesDoNotCallGet() throws {
        let element = try Element(Tag.valueOf("p"), "")
        let probe = LookupProbe(element)
        for index in [Int.min, -2, -1, 1, Int.max] {
            XCTAssertTrue(probe.eq(index).isEmpty(), "index: \(index)")
        }
        XCTAssertTrue(probe.requestedIndexes.isEmpty)
    }

    func testNegativeIndexesAreEmptyForOrdinaryLists() throws {
        let document = try SwiftSoup.parse("<p>one</p><p>two</p>")
        let selected = try document.select("p")
        for elements in [Elements(), selected] {
            for index in [Int.min, -2, -1] {
                XCTAssertTrue(elements.eq(index).isEmpty())
                XCTAssertEqual(try elements.eq(index).text(), "")
                try elements.eq(index).attr("data-probe", "ignored")
            }
        }
        XCTAssertEqual(try selected.text(), "one two")
        XCTAssertFalse(selected.hasAttr("data-probe"))
    }

    func testValidIndexesRetainIdentityAndVirtualLookup() throws {
        let document = try SwiftSoup.parse("<p>one</p><p>two</p>")
        let selected = try document.select("p")
        for index in 0..<selected.size() {
            let result = selected.eq(index)
            XCTAssertEqual(result.size(), 1)
            XCTAssertTrue(result.first() === selected.get(index))
        }
        let probe = LookupProbe(selected.get(0))
        XCTAssertTrue(probe.eq(0).first() === probe.sentinel)
        XCTAssertEqual(probe.requestedIndexes, [0])
    }

    func testUpperBoundsAndEmptyListsReturnEmptyResults() throws {
        let selected = try SwiftSoup.parse("<p>one</p>").select("p")
        for index in [1, 2, Int.max] {
            XCTAssertTrue(selected.eq(index).isEmpty())
        }
        for index in [0, 1, Int.max] {
            XCTAssertTrue(Elements().eq(index).isEmpty())
        }
    }
}
