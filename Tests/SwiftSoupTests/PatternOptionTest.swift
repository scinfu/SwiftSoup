import XCTest
import SwiftSoup

final class PatternOptionTest: XCTestCase {
    func testCaseInsensitiveOptionMatchesAndPreservesCaptures() throws {
        let pattern = Pattern.compile("(ab)(c)", Pattern.CASE_INSENSITIVE)
        try pattern.validate()
        XCTAssertEqual(pattern.toString(), "(ab)(c)")
        let matcher = pattern.matcher(in: "ABC AbC abc")
        XCTAssertEqual(matcher.count, 3)
        for (whole, first, second) in [("ABC", "AB", "C"), ("AbC", "Ab", "C"), ("abc", "ab", "c")] {
            XCTAssertTrue(matcher.find())
            XCTAssertEqual(matcher.group(), whole)
            XCTAssertEqual(matcher.group(1), first)
            XCTAssertEqual(matcher.group(2), second)
        }
        XCTAssertFalse(matcher.find())
    }

    func testDefaultAndZeroOptionsRemainCaseSensitive() {
        for pattern in [Pattern.compile("abc"), Pattern.compile("abc", 0)] {
            XCTAssertFalse(pattern.matcher(in: "ABC").find())
            XCTAssertTrue(pattern.matcher(in: "abc").find())
        }
        let insensitive = Pattern.compile("abc", Pattern.CASE_INSENSITIVE)
        let copy = insensitive
        XCTAssertTrue(copy.matcher(in: "ABC").find())
        XCTAssertFalse(Pattern.compile("abc").matcher(in: "ABC").find())
    }

    func testEmbeddedFlagsAndUnrecognizedBitsRetainTheirBehavior() {
        XCTAssertTrue(Pattern.compile("(?i)abc", 0).matcher(in: "ABC").find())
        let locallySensitive = Pattern.compile("(?-i:abc)", Pattern.CASE_INSENSITIVE)
        XCTAssertFalse(locallySensitive.matcher(in: "ABC").find())
        XCTAssertTrue(locallySensitive.matcher(in: "abc").find())
        XCTAssertTrue(Pattern.compile("abc", Pattern.CASE_INSENSITIVE | 0x10000).matcher(in: "ABC").find())
        XCTAssertFalse(Pattern.compile("abc", 0x10000).matcher(in: "ABC").find())
    }

    func testUnicodeCaseInsensitiveMatchesUseOriginalCaptureText() {
        let matcher = Pattern.compile("(é)(ω)", Pattern.CASE_INSENSITIVE).matcher(in: "😀ÉΩ éω")
        for (whole, first, second) in [("ÉΩ", "É", "Ω"), ("éω", "é", "ω")] {
            XCTAssertTrue(matcher.find())
            XCTAssertEqual(matcher.group(), whole)
            XCTAssertEqual(matcher.group(1), first)
            XCTAssertEqual(matcher.group(2), second)
        }
        XCTAssertFalse(matcher.find())
    }

    func testCaseInsensitivePatternWorksThroughElementQueryAPIs() throws {
        let document = try SwiftSoup.parse("<main><p id='upper' data-code='ABC'>ABC</p><p id='lower' data-code='abc'>abc</p><p id='other' data-code='xyz'>xyz</p></main>")
        let pattern = Pattern.compile("^abc$", Pattern.CASE_INSENSITIVE)
        XCTAssertEqual(try document.getElementsByAttributeValueMatching("data-code", pattern).array().map { $0.id() }, ["upper", "lower"])
        XCTAssertEqual(try document.getElementsMatchingText(pattern).array().map { $0.id() }, ["upper", "lower"])
        XCTAssertEqual(try document.getElementsMatchingOwnText(pattern).array().map { $0.id() }, ["upper", "lower"])
        let upper = try XCTUnwrap(document.getElementById("upper"))
        try upper.attr("data-code", "xyz")
        try upper.text("xyz")
        XCTAssertEqual(try document.getElementsByAttributeValueMatching("data-code", pattern).array().map { $0.id() }, ["lower"])
        XCTAssertEqual(try document.getElementsMatchingOwnText(pattern).array().map { $0.id() }, ["lower"])
    }

    func testInvalidFlaggedPatternStillDefersErrorUntilValidation() {
        let pattern = Pattern.compile("[", Pattern.CASE_INSENSITIVE)
        XCTAssertEqual(pattern.toString(), "[")
        XCTAssertThrowsError(try pattern.validate())
        XCTAssertFalse(pattern.matcher(in: "ABC").find())
    }
}
