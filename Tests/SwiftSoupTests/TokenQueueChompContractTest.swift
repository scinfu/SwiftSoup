import XCTest
import SwiftSoup

final class TokenQueueChompContractTest: XCTestCase {
    func testMissingDelimiterConsumesAllRemainingInput() throws {
        for value in ["plain text", "日本😀e\u{301}", "partial EN"] {
            let queue = TokenQueue("prefix:" + value)
            try queue.consume("prefix:")
            XCTAssertEqual(queue.chompTo("END"), value)
            XCTAssertTrue(queue.isEmpty())
            XCTAssertEqual(queue.remainder(), "")
            XCTAssertEqual(queue.chompTo("END"), "")
        }
    }

    func testDelimiterMatchingIsCaseSensitive() {
        for value in ["ENDtail", "Endtail", "endtail"] {
            let queue = TokenQueue(value)
            if value.hasPrefix("end") {
                XCTAssertEqual(queue.chompTo("end"), "")
                XCTAssertEqual(queue.remainder(), "tail")
            } else {
                XCTAssertEqual(queue.chompTo("end"), value)
                XCTAssertTrue(queue.isEmpty())
            }
        }
        let queue = TokenQueue("END before end after")
        XCTAssertEqual(queue.chompTo("end"), "END before ")
        XCTAssertEqual(queue.remainder(), " after")
    }

    func testFoundDelimiterIsConsumedExactlyOnceAtNonzeroPosition() throws {
        let queue = TokenQueue("prefix:日本😀::tail::last")
        try queue.consume("prefix:")
        XCTAssertEqual(queue.chompTo("::"), "日本😀")
        XCTAssertEqual(queue.chompTo("::"), "tail")
        XCTAssertEqual(queue.remainder(), "last")
        let atEnd = TokenQueue("valueEND")
        XCTAssertEqual(atEnd.chompTo("END"), "value")
        XCTAssertTrue(atEnd.isEmpty())
    }

    func testEmptyDelimiterAndConsumeToLegacyBehaviorRemainUnchanged() {
        let queue = TokenQueue("日本tail")
        XCTAssertEqual(queue.chompTo(""), "")
        XCTAssertEqual(queue.toString(), "日本tail")
        XCTAssertEqual(queue.consumeTo("missing"), "")
        XCTAssertEqual(queue.consumeToSlice("missing"), "")
        XCTAssertEqual(queue.toString(), "日本tail")
        let empty = TokenQueue("")
        XCTAssertEqual(empty.chompTo(""), "")
        XCTAssertEqual(empty.chompTo("missing"), "")
        XCTAssertTrue(empty.isEmpty())
    }

    func testIgnoreCaseVariantRetainsItsExistingContract() {
        let queue = TokenQueue("before EnD tail")
        XCTAssertEqual(queue.chompToIgnoreCase("end"), "before ")
        XCTAssertEqual(queue.remainder(), " tail")
        let missing = TokenQueue("remaining 日本")
        XCTAssertEqual(missing.chompToIgnoreCase("end"), "remaining 日本")
        XCTAssertTrue(missing.isEmpty())
    }
}
