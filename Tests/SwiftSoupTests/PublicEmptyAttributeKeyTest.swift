import XCTest
@testable import SwiftSoup

/// Public-API regression tests for #392: a vertical tab (`0x0B`) after a quoted attribute value
/// produces an attribute key that trims to empty during materialization. Parsing then `select`ing
/// must drop the malformed attribute rather than trap.
final class PublicEmptyAttributeKeyTest: XCTestCase {

    /// Boolean attribute (`.none` value).
    func testBooleanVerticalTabKeyDoesNotCrashSelect() throws {
        let doc = try SwiftSoup.parse("<div a=\"b\"\u{0B}>hi</div>")
        let matches = try doc.select("[name=x]")
        XCTAssertEqual(matches.size(), 0, "Malformed empty-key attribute must be dropped, not crash")
    }

    /// Valued attribute (`.slice` value).
    func testValuedVerticalTabKeyDoesNotCrashSelect() throws {
        let doc = try SwiftSoup.parse("<div a=\"b\"\u{0B}=x>hi</div>")
        let matches = try doc.select("[name=x]")
        XCTAssertEqual(matches.size(), 0)
    }

    /// `<meta>` + the attribute-value selector from the original report.
    func testMetaVerticalTabKeyDoesNotCrashSelect() throws {
        let doc = try SwiftSoup.parse("<meta a=\"b\"\u{0B}=og:title>")
        let matches = try doc.select("meta[property=og:title]")
        XCTAssertEqual(matches.size(), 0)
    }
}
