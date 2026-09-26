import XCTest
@testable import SwiftSoup

final class PreservedTextWhitespaceTest: XCTestCase {
    func testPreWhitespaceSurvivesDeepInlineMarkupAndSerialization() throws {
        let text = "a  b\nc\td"
        for depth in [2, 8, 64] {
            let html = "<pre>" + String(repeating: "<span>", count: depth) + text + String(repeating: "</span>", count: depth) + "</pre>"
            for trackSource in [false, true] {
                let doc = try Parser.htmlParser().settings(ParseSettings(false, false, trackSource)).parseInput(html, "")
                let pre = try XCTUnwrap(doc.select("pre").first())
                let innermost = try XCTUnwrap(pre.select("span").last())
                XCTAssertEqual(try pre.text(), text)
                XCTAssertEqual(try doc.text(), text)
                XCTAssertEqual(innermost.ownText(), text)
                XCTAssertEqual(try pre.textUTF8(), Array(text.utf8))
                XCTAssertEqual(Array(try pre.textUTF8Slice()), Array(text.utf8))
                doc.outputSettings().prettyPrint(pretty: true)
                let output = StringBuilder()
                try pre.outerHtmlFastWithoutSourceReuse(output, 0, doc.outputSettings())
                XCTAssertEqual(output.toString(), html)
            }
        }
    }

    func testWhitespaceContextTracksRetaggingAndReparenting() throws {
        let doc = try SwiftSoup.parse("<pre><code><span>a  b\nc</span></code></pre><div id='destination'></div>")
        let pre = try XCTUnwrap(doc.select("pre").first())
        let code = try XCTUnwrap(doc.select("code").first())
        let destination = try XCTUnwrap(doc.getElementById("destination"))
        XCTAssertEqual(try code.text(), "a  b\nc")
        try pre.tagName("div")
        XCTAssertEqual(try code.text(), "a b c")
        try pre.tagName("pre")
        XCTAssertEqual(try code.text(), "a  b\nc")
        try destination.appendChild(code)
        XCTAssertEqual(try code.text(), "a b c")
        try pre.appendChild(code)
        XCTAssertEqual(try code.text(), "a  b\nc")
    }

    func testNormalizedTextGettersTrimPreservedTrailingWhitespaceConsistently() throws {
        for suffix in [" ", "\t", "\n", "\r", "\u{0C}", "\u{0B}", "\t\n "] {
            let doc = try SwiftSoup.parse("<pre id='target'></pre>")
            let target = try XCTUnwrap(doc.getElementById("target"))
            try target.text("value" + suffix)
            for scope in [target, doc] {
                XCTAssertEqual(try scope.text(), "value", suffix.debugDescription)
                XCTAssertEqual(try scope.textUTF8(), Array("value".utf8), suffix.debugDescription)
                XCTAssertEqual(Array(try scope.textUTF8Slice()), Array("value".utf8), suffix.debugDescription)
                XCTAssertEqual(try scope.text(trimAndNormaliseWhitespace: false), "value" + suffix)
            }
            XCTAssertEqual(try target.select(":contains(value\n)").size(), 0)
        }
    }
}
