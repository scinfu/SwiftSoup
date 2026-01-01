//
//  SwifSoupTests.swift
//  SwifSoupTests
//
//  Created by Nabil Chatbi on 20/04/16.
//

import XCTest
import SwiftSoup

class StringUtilTest: XCTestCase {

//	func testSite()
//	{
//		let myURLString = "http://comcast.net"
//		guard let myURL = URL(string: myURLString) else {
//			print("Error: \(myURLString) doesn't seem to be a valid URL")
//			return
//		}
//		
//		
//		do {
//			let html = try String(contentsOf: myURL, encoding: .utf8)
//			print("HTML : \(html)")
//			let doc: Document = try SwiftSoup.parse(html)
//			print(try doc.text())
//		}
//		catch {
//			print("Error")
//		}
//	}

    func testJoin() {
        XCTAssertEqual("", StringUtil.join([""], sep: " "))
        XCTAssertEqual("one", StringUtil.join(["one"], sep: " "))
        XCTAssertEqual("one two three", StringUtil.join(["one", "two", "three"], sep: " "))
    }

    func testPadding() {
        XCTAssertEqual("", StringUtil.padding(0))
        XCTAssertEqual(" ", StringUtil.padding(1))
        XCTAssertEqual("  ", StringUtil.padding(2))
        XCTAssertEqual("               ", StringUtil.padding(15))
    }

    func testIsBlank() {
        //XCTAssertTrue(StringUtil.isBlank(nil))
        XCTAssertTrue(StringUtil.isBlank(""))
        XCTAssertTrue(StringUtil.isBlank("      "))
        XCTAssertTrue(StringUtil.isBlank("   \r\n  "))

        XCTAssertFalse(StringUtil.isBlank("hello"))
        XCTAssertFalse(StringUtil.isBlank("   hello   "))
    }

    func testIsNumeric() {
//        XCTAssertFalse(StringUtil.isNumeric(nil))
        XCTAssertFalse(StringUtil.isNumeric(" "))
        XCTAssertFalse(StringUtil.isNumeric("123 546"))
        XCTAssertFalse(StringUtil.isNumeric("hello"))
        XCTAssertFalse(StringUtil.isNumeric("123.334"))

        XCTAssertTrue(StringUtil.isNumeric("1"))
        XCTAssertTrue(StringUtil.isNumeric("1234"))
    }

    func testToIntAscii() {
        XCTAssertEqual("123".utf8ArraySlice.toIntAscii(radix: 10), 123)
        XCTAssertEqual("0A1f".utf8ArraySlice.toIntAscii(radix: 16), 0x0A1F)
        XCTAssertEqual("z".utf8ArraySlice.toIntAscii(radix: 36), 35)
        XCTAssertNil("12z".utf8ArraySlice.toIntAscii(radix: 10))
        XCTAssertNil("12g".utf8ArraySlice.toIntAscii(radix: 16))
    }

    func testIsWhitespace() {
        XCTAssertTrue(StringUtil.isWhitespace("\t"))
        XCTAssertTrue(StringUtil.isWhitespace("\n"))
        XCTAssertTrue(StringUtil.isWhitespace("\r"))
        XCTAssertTrue(StringUtil.isWhitespace(Character.BackslashF))
        XCTAssertTrue(StringUtil.isWhitespace("\r\n"))
        XCTAssertTrue(StringUtil.isWhitespace(" "))

        XCTAssertFalse(StringUtil.isWhitespace("\u{00a0}"))
        XCTAssertFalse(StringUtil.isWhitespace("\u{2000}"))
        XCTAssertFalse(StringUtil.isWhitespace("\u{3000}"))
    }

    func testNormaliseWhiteSpace() {
        XCTAssertEqual(" ", StringUtil.normaliseWhitespace("    \r \n \r\n"))
        XCTAssertEqual(" hello there ", StringUtil.normaliseWhitespace("   hello   \r \n  there    \n"))
        XCTAssertEqual("hello", StringUtil.normaliseWhitespace("hello"))
        XCTAssertEqual("hello there", StringUtil.normaliseWhitespace("hello\nthere"))
    }

    func testNormaliseWhiteSpaceHandlesHighSurrogates() throws {
        let test71540chars = "\\u{d869}\\u{deb2}\\u{304b}\\u{309a}  1"
        let test71540charsExpectedSingleWhitespace = "\\u{d869}\\u{deb2}\\u{304b}\\u{309a} 1"

        XCTAssertEqual(test71540charsExpectedSingleWhitespace, StringUtil.normaliseWhitespace(test71540chars))
        let extractedText = try SwiftSoup.parse(test71540chars).text()
        XCTAssertEqual(test71540charsExpectedSingleWhitespace, extractedText)
    }

    func testAppendNormalisedWhitespaceNoWhitespaceSlice() {
        let sb = StringBuilder()
        let bytes = "alphaβ".utf8Array
        StringUtil.appendNormalisedWhitespace(sb, string: bytes[...], stripLeading: true)
        XCTAssertEqual("alphaβ", sb.toString())
    }

    func testAppendNormalisedWhitespaceWithWhitespaceSlice() {
        let sb = StringBuilder()
        let bytes = " alpha \n beta ".utf8Array
        StringUtil.appendNormalisedWhitespace(sb, string: bytes[...], stripLeading: true)
        XCTAssertEqual("alpha beta ", sb.toString())
    }

    func testAppendNormalisedWhitespaceBytes() {
        let sb = StringBuilder()
        let bytes = " alpha beta".utf8Array
        StringUtil.appendNormalisedWhitespace(sb, string: bytes, stripLeading: true)
        XCTAssertEqual("alpha beta", sb.toString())
    }

    func testAppendNormalisedWhitespaceTracking() {
        var lastWasWhite = false
        let sb1 = StringBuilder()
        let bytes1 = "alpha beta gamma".utf8Array
        StringUtil.appendNormalisedWhitespace(sb1, string: bytes1[...], stripLeading: false, lastWasWhite: &lastWasWhite)
        XCTAssertEqual("alpha beta gamma", sb1.toString())
        XCTAssertFalse(lastWasWhite)

        lastWasWhite = false
        let sb2 = StringBuilder()
        let bytes2 = " alpha beta".utf8Array
        StringUtil.appendNormalisedWhitespace(sb2, string: bytes2[...], stripLeading: true, lastWasWhite: &lastWasWhite)
        XCTAssertEqual("alpha beta", sb2.toString())
        XCTAssertFalse(lastWasWhite)

        lastWasWhite = true
        let sb3 = StringBuilder()
        let bytes3 = " alpha".utf8Array
        StringUtil.appendNormalisedWhitespace(sb3, string: bytes3[...], stripLeading: false, lastWasWhite: &lastWasWhite)
        XCTAssertEqual("alpha", sb3.toString())
        XCTAssertFalse(lastWasWhite)

        lastWasWhite = false
        let sb4 = StringBuilder()
        let bytes4 = "a  b".utf8Array
        StringUtil.appendNormalisedWhitespace(sb4, string: bytes4[...], stripLeading: false, lastWasWhite: &lastWasWhite)
        XCTAssertEqual("a b", sb4.toString())
    }

    func testResolvesRelativeUrls() {
        XCTAssertEqual("http://example.com/one/two?three", StringUtil.resolve("http://example.com", relUrl: "./one/two?three"))
        XCTAssertEqual("http://example.com/one/two?three", StringUtil.resolve("http://example.com?one", relUrl: "./one/two?three"))
        XCTAssertEqual("http://example.com/one/two?three#four", StringUtil.resolve("http://example.com", relUrl: "./one/two?three#four"))
        XCTAssertEqual("https://example.com/one", StringUtil.resolve("http://example.com/", relUrl: "https://example.com/one"))
        XCTAssertEqual("http://example.com/one/two.html", StringUtil.resolve("http://example.com/two/", relUrl: "../one/two.html"))
        XCTAssertEqual("https://example2.com/one", StringUtil.resolve("https://example.com/", relUrl: "//example2.com/one"))
        XCTAssertEqual("https://example.com:8080/one", StringUtil.resolve("https://example.com:8080", relUrl: "./one"))
        XCTAssertEqual("https://example2.com/one", StringUtil.resolve("http://example.com/", relUrl: "https://example2.com/one"))
        XCTAssertEqual("https://example.com/one", StringUtil.resolve("wrong", relUrl: "https://example.com/one"))
        XCTAssertEqual("https://example.com/one", StringUtil.resolve("https://example.com/one", relUrl: ""))
        XCTAssertEqual("", StringUtil.resolve("wrong", relUrl: "also wrong"))
        XCTAssertEqual("ftp://example.com/one", StringUtil.resolve("ftp://example.com/two/", relUrl: "../one"))
        XCTAssertEqual("ftp://example.com/one/two.c", StringUtil.resolve("ftp://example.com/one/", relUrl: "./two.c"))
        XCTAssertEqual("ftp://example.com/one/two.c", StringUtil.resolve("ftp://example.com/one/", relUrl: "two.c"))
    }
    
    func testResolveEscaping() {
        let source1 = "mailto:mail@example.com?subject=Job%20Requisition[NID]"
        let source2 = "https://example.com?foo=one%20two["
        
        // Ideally, the `mailto` example would resolve it its input (preserving `[` and `]`).
        // See https://github.com/scinfu/SwiftSoup/issues/268
        XCTAssertEqual("mailto:mail@example.com?subject=Job%20Requisition%5BNID%5D", StringUtil.resolve("", relUrl: source1))
        XCTAssertEqual("https://example.com?foo=one%20two%5B", StringUtil.resolve("", relUrl: source2))
    }
}
