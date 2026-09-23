import XCTest
import Foundation
import Dispatch
@testable import SwiftSoup

final class PatternReuseTest: XCTestCase {
    func testRepeatedMatchesAgreeWithFoundationRanges() throws {
        let patterns = ["[a-z]+", "(?i)(ab)+", "(?m)^.+$", "(?=a)", "(a)?b", "日本語|😀|é", "\\p{L}+", "^$", "a*", "(.)\\1"]
        let inputs = ["", "a ab abab", "abc\ndef\n", "bbb", "😀 日本語 e\u{301} é", "aa cc 123"]
        for source in patterns {
            let pattern = Pattern.compile(source)
            let reference = try NSRegularExpression(pattern: source)
            for _ in 0..<3 {
                try pattern.validate()
                XCTAssertEqual(pattern.toString(), source)
                for input in inputs {
                    let expected = reference.matches(in: input, range: NSRange(location: 0, length: (input as NSString).length))
                    let actual = pattern.matcher(in: input)
                    XCTAssertEqual(actual.count, expected.count)
                    for (lhs, rhs) in zip(actual.matches, expected) {
                        XCTAssertEqual(lhs.numberOfRanges, rhs.numberOfRanges)
                        for group in 0..<rhs.numberOfRanges {
                            XCTAssertEqual(lhs.range(at: group), rhs.range(at: group))
                        }
                    }
                    var found = 0
                    while actual.find() { found += 1 }
                    XCTAssertEqual(found, expected.count)
                    XCTAssertFalse(actual.find())
                    XCTAssertEqual(actual.count, expected.count)
                }
            }
        }
    }

    func testCopiesAndMatchersHaveIndependentCursors() throws {
        let original = Pattern.compile("(a)?b")
        let copy = original
        let first = original.matcher(in: "ab b")
        let second = copy.matcher(in: "b ab")
        XCTAssertTrue(first.find())
        XCTAssertEqual(first.group(), "ab")
        XCTAssertEqual(first.group(1), "a")
        XCTAssertTrue(second.find())
        XCTAssertEqual(second.group(), "b")
        XCTAssertNil(second.group(1))
        try copy.validate()
        XCTAssertTrue(first.find())
        XCTAssertEqual(first.group(), "b")
        XCTAssertNil(first.group(1))
        XCTAssertFalse(first.find())
        XCTAssertTrue(second.find())
        XCTAssertEqual(second.group(1), "a")
        XCTAssertFalse(second.find())
    }

    func testInvalidPatternRemainsNonthrowingUntilValidation() {
        for source in ["[", "(", "*", "\\"] {
            let pattern = Pattern.compile(source)
            XCTAssertEqual(pattern.toString(), source)
            let nativeError: NSError
            do {
                _ = try NSRegularExpression(pattern: source)
                XCTFail("Fixture must be invalid")
                continue
            } catch { nativeError = error as NSError }
            for _ in 0..<3 {
                XCTAssertThrowsError(try pattern.validate()) { error in
                    XCTAssertEqual((error as NSError).domain, nativeError.domain)
                    XCTAssertEqual((error as NSError).code, nativeError.code)
                }
                let matcher = pattern.matcher(in: "input")
                XCTAssertEqual(matcher.count, 0)
                XCTAssertFalse(matcher.find())
            }
        }
    }

    func testOptionOverloadAndEmbeddedFlagsEnableCaseInsensitiveMatching() {
        XCTAssertTrue(Pattern.compile("abc", Pattern.CASE_INSENSITIVE).matcher(in: "ABC").find())
        XCTAssertTrue(Pattern.compile("(?i)abc").matcher(in: "ABC").find())
    }

    func testZeroWidthMatchesRemainEagerAndComplete() {
        let pattern = Pattern.compile("(?=a)")
        let matcher = pattern.matcher(in: "aaa")
        XCTAssertEqual(matcher.count, 3)
        for _ in 0..<3 {
            XCTAssertTrue(matcher.find())
            XCTAssertEqual(matcher.group(), "")
        }
        XCTAssertFalse(matcher.find())
        XCTAssertFalse(pattern.matcher(in: "bbb").find())
    }

    func testSharedPatternAcrossConcurrentInputs() {
        final class Results: @unchecked Sendable {
            let lock = NSLock()
            var failures = 0
            func fail() { lock.lock(); failures += 1; lock.unlock() }
        }
        let results = Results()
        let pattern = Pattern.compile("^(日本語|word)-[0-9]+$")
        DispatchQueue.concurrentPerform(iterations: 128) { index in
            for offset in 0..<16 {
                let input = index.isMultiple(of: 2) ? "日本語-\(offset)" : "word-\(offset)"
                if !pattern.matcher(in: input).find() || pattern.matcher(in: "no match").find() {
                    results.fail()
                }
            }
        }
        XCTAssertEqual(results.failures, 0)
    }

    func testRegexSelectorsObserveNewInputsAfterMutation() throws {
        let document = try SwiftSoup.parse("<main><p id='a' data-probe='word-2'>word-2</p><p id='b' data-probe='word-3'>word-3</p></main>")
        let pattern = Pattern.compile("^word-(2|4)$")
        let b = try XCTUnwrap(document.getElementById("b"))
        for pass in 0..<8 {
            let value = pass.isMultiple(of: 2) ? "word-3" : "word-4"
            try b.attr("data-probe", value)
            try b.text(value)
            let expected = pass.isMultiple(of: 2) ? ["a"] : ["a", "b"]
            XCTAssertEqual(try document.getElementsByAttributeValueMatching("data-probe", pattern).array().map { $0.id() }, expected)
            XCTAssertEqual(try document.getElementsByAttributeValueMatching("data-probe", pattern.toString()).array().map { $0.id() }, expected)
            XCTAssertEqual(try document.getElementsMatchingOwnText(pattern).array().map { $0.id() }, expected)
            XCTAssertEqual(try document.select("p[data-probe~=^word-(2|4)$]").array().map { $0.id() }, expected)
        }
    }

    func testPublicRegexOverloadsStillRejectInvalidExpressions() throws {
        let document = try SwiftSoup.parse("<p data-probe='value'>text</p>")
        XCTAssertThrowsError(try document.getElementsByAttributeValueMatching("data-probe", "["))
        XCTAssertThrowsError(try document.getElementsMatchingText("["))
        XCTAssertThrowsError(try document.getElementsMatchingOwnText("["))
    }
}
