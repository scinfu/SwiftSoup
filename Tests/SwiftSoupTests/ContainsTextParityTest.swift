import XCTest
@testable import SwiftSoup

final class ContainsTextParityTest: XCTestCase {
    private func assertParity(_ html: String, needles: [String],
                              file: StaticString = #filePath, line: UInt = #line) throws {
        let doc = try SwiftSoup.parse(html)
        let elements = try doc.getAllElements().array()
        for own in [false, true] {
            for needle in needles {
                let evaluator: Evaluator = own ? Evaluator.ContainsOwnText(needle) : Evaluator.ContainsText(needle)
                let expected = try elements.filter {
                    let text = own ? $0.ownText() : try $0.text()
                    return text.lowercased().contains(needle.lowercased())
                }
                let expectedIDs = expected.map(ObjectIdentifier.init)
                let scanned = try elements.filter { try evaluator.matches(doc, $0) }
                XCTAssertEqual(scanned.map(ObjectIdentifier.init), expectedIDs,
                               "direct own=\(own) \(html.debugDescription) needle=\(needle.debugDescription)", file: file, line: line)
                XCTAssertEqual(try Collector.collect(evaluator, doc).array().map(ObjectIdentifier.init), expectedIDs,
                               "collector own=\(own) needle=\(needle.debugDescription)", file: file, line: line)
                // CSS rejects an empty search operand, but the public evaluator
                // and direct containing-text APIs still accept one.
                if !needle.isEmpty {
                    let query = ":\(own ? "containsOwn" : "contains")(\(needle))"
                    for _ in 0..<4 {
                        XCTAssertEqual(try doc.select(query).array().map(ObjectIdentifier.init), expectedIDs,
                                       "cached \(query)", file: file, line: line)
                    }
                }
            }
        }
    }

    func testUnicodeCaseMappingAndGraphemeBoundaries() throws {
        for text in ["K", "e\u{301}", "a\u{20DD}", "İ", "日本語", "👩‍💻"] {
            try assertParity("<p>\(text)</p><div>\(text)<b>more</b></div>", needles: ["k", "e", "a", "i", text])
        }
        // A combining mark in a later node can change a preceding ASCII
        // character's grapheme boundary in the concatenated public text.
        try assertParity("<p>e<b>\u{301}</b></p>", needles: ["e", "é", "e\u{301}"])
    }

    func testPreservedWhitespaceUsesTheSameTextAsPublicGetters() throws {
        for tag in ["pre", "textarea", "plaintext"] {
            try assertParity("<\(tag)>a  b\nc\td</\(tag)>", needles: ["a  b", "a b", "b\nc", "c\td", "a "])
        }
        try assertParity("<pre><span>a  b</span> c</pre>", needles: ["a  b", "a b", "b c"])
    }

    func testTrailingWhitespaceCannotCompleteAMatchAfterTrimming() throws {
        for html in ["<p>a </p>", "<p>a<br></p>", "<p>a <b></b></p>", "<p>a<div></div></p>",
                     "<p>a&nbsp;</p>", "<p> a <b>b</b> </p>"] {
            try assertParity(html, needles: ["a ", " ", " b", "a b", "a"])
        }
    }

    func testEmptySearchAndOrdinaryAsciiAgreeWithStringGetters() throws {
        try assertParity("<p></p><p>abc</p><p>a <b>B</b> c</p>", needles: ["", "a", "ABC", "a b", "b c", "missing"])
    }

    func testLongRepeatedPrefixesAndOverlappingMatches() throws {
        let prefix = String(repeating: "a", count: 4_096)
        let needle = String(repeating: "a", count: 256)
        try assertParity("<p>\(prefix)<b></b>ab</p>", needles: [needle + "b", needle + "c", needle.uppercased()])
        try assertParity("<p>abababab<b></b>ababababac</p>", needles: ["ababababababababac", "ababababababababaa"])
    }

    func testCachedContainsResultsUpdateAfterTextMutation() throws {
        let doc = try SwiftSoup.parse("<p>a</p>")
        let p = try XCTUnwrap(doc.select("p").first())
        for text in ["a", "K", "e\u{301}", "a ", "A"] {
            try p.text(text)
            for query in ["p:contains(a)", "p:containsOwn(a)"] {
                let expected = try p.text().lowercased().contains("a")
                for _ in 0..<4 { XCTAssertEqual(try doc.select(query).size(), expected ? 1 : 0) }
            }
        }
    }
}
