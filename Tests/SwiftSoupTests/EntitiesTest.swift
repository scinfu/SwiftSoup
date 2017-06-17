//
//  EntitiesTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 09/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation
import XCTest
import SwiftSoup

class EntitiesTest: XCTestCase {

	func testEscape()throws {
		let text = "Hello &<> Å å π 新 there ¾ © »"

		let escapedAscii = Entities.escape(text, OutputSettings().encoder(String.Encoding.ascii).escapeMode(Entities.EscapeMode.base))
		let escapedAsciiFull = Entities.escape(text, OutputSettings().charset(String.Encoding.ascii).escapeMode(Entities.EscapeMode.extended))
		let escapedAsciiXhtml = Entities.escape(text, OutputSettings().charset(String.Encoding.ascii).escapeMode(Entities.EscapeMode.xhtml))
		let escapedUtfFull = Entities.escape(text, OutputSettings().charset(String.Encoding.utf8).escapeMode(Entities.EscapeMode.extended))
        let escapedUtfFull2 = Entities.escape(text)
		let escapedUtfMin = Entities.escape(text, OutputSettings().charset(String.Encoding.utf8).escapeMode(Entities.EscapeMode.xhtml))

		XCTAssertEqual("Hello &amp;&lt;&gt; &Aring; &aring; &#x3c0; &#x65b0; there &frac34; &copy; &raquo;", escapedAscii)
		XCTAssertEqual("Hello &amp;&lt;&gt; &angst; &aring; &pi; &#x65b0; there &frac34; &copy; &raquo;", escapedAsciiFull)
		XCTAssertEqual("Hello &amp;&lt;&gt; &#xc5; &#xe5; &#x3c0; &#x65b0; there &#xbe; &#xa9; &#xbb;", escapedAsciiXhtml)
		XCTAssertEqual("Hello &amp;&lt;&gt; Å å π 新 there ¾ © »", escapedUtfFull)
        XCTAssertEqual("Hello &amp;&lt;&gt; Å å π 新 there ¾ © »", escapedUtfFull2)
		XCTAssertEqual("Hello &amp;&lt;&gt; Å å π 新 there ¾ © »", escapedUtfMin)
		// odd that it's defined as aring in base but angst in full

		// round trip
		XCTAssertEqual(text, try Entities.unescape(escapedAscii))
		XCTAssertEqual(text, try Entities.unescape(escapedAsciiFull))
		XCTAssertEqual(text, try Entities.unescape(escapedAsciiXhtml))
		XCTAssertEqual(text, try Entities.unescape(escapedUtfFull))
        XCTAssertEqual(text, try Entities.unescape(escapedUtfFull2))
		XCTAssertEqual(text, try Entities.unescape(escapedUtfMin))
	}

	func testXhtml() {
		//let text = "&amp; &gt; &lt; &quot;";
		XCTAssertEqual(38, Entities.EscapeMode.xhtml.codepointForName("amp"))
		XCTAssertEqual(62, Entities.EscapeMode.xhtml.codepointForName("gt"))
		XCTAssertEqual(60, Entities.EscapeMode.xhtml.codepointForName("lt"))
		XCTAssertEqual(34, Entities.EscapeMode.xhtml.codepointForName("quot"))

		XCTAssertEqual("amp", Entities.EscapeMode.xhtml.nameForCodepoint(38))
		XCTAssertEqual("gt", Entities.EscapeMode.xhtml.nameForCodepoint(62))
		XCTAssertEqual("lt", Entities.EscapeMode.xhtml.nameForCodepoint(60))
		XCTAssertEqual("quot", Entities.EscapeMode.xhtml.nameForCodepoint(34))
	}

	func testGetByName() {
		//XCTAssertEqual("≫⃒", Entities.getByName(name: "nGt"));//todo:nabil same codepoint 8811 in java but charachters different
		//XCTAssertEqual("fj", Entities.getByName(name: "fjlig"));
		XCTAssertEqual("≫", Entities.getByName(name: "gg"))
		XCTAssertEqual("©", Entities.getByName(name: "copy"))
	}

	func testEscapeSupplementaryCharacter() {
		let text: String = "𡃁"
		let escapedAscii: String = Entities.escape(text, OutputSettings().charset(.ascii).escapeMode(Entities.EscapeMode.base))
		XCTAssertEqual("&#x210c1;", escapedAscii)
		let escapedUtf: String = Entities.escape(text, OutputSettings().charset(.utf8).escapeMode(Entities.EscapeMode.base))
		XCTAssertEqual(text, escapedUtf)
	}

	func testNotMissingMultis()throws {
		let text: String = "&nparsl;"
		let un: String = "\u{2AFD}\u{20E5}"
		XCTAssertEqual(un, try Entities.unescape(text))
	}

	func testnotMissingSupplementals()throws {
		let text: String = "&npolint; &qfr;"
		let un: String = "⨔ 𝔮"//+"\u{D835}\u{DD2E}" // 𝔮
		XCTAssertEqual(un, try Entities.unescape(text))
	}

	func testUnescape()throws {
		let text: String = "Hello &AElig; &amp;&LT&gt; &reg &angst; &angst &#960; &#960 &#x65B0; there &! &frac34; &copy; &COPY;"
		XCTAssertEqual("Hello Æ &<> ® Å &angst π π 新 there &! ¾ © ©", try Entities.unescape(text))

		XCTAssertEqual("&0987654321; &unknown", try Entities.unescape("&0987654321; &unknown"))
	}

	func testStrictUnescape()throws { // for attributes, enforce strict unescaping (must look like &#xxx; , not just &#xxx)
		let text: String = "Hello &amp= &amp;"
		XCTAssertEqual("Hello &amp= &", try Entities.unescape(string: text, strict: true))
		XCTAssertEqual("Hello &= &", try Entities.unescape(text))
		XCTAssertEqual("Hello &= &", try Entities.unescape(string: text, strict: false))
	}

	func testCaseSensitive()throws {
		let unescaped: String = "Ü ü & &"
		XCTAssertEqual("&Uuml; &uuml; &amp; &amp;",
		             Entities.escape(unescaped, OutputSettings().charset(.ascii).escapeMode(Entities.EscapeMode.extended)))

		let escaped: String = "&Uuml; &uuml; &amp; &AMP"
		XCTAssertEqual("Ü ü & &", try Entities.unescape(escaped))
	}

	func testQuoteReplacements()throws {
		let escaped: String = "&#92; &#36;"
		let unescaped: String = "\\ $"

		XCTAssertEqual(unescaped, try Entities.unescape(escaped))
	}

	func testLetterDigitEntities()throws {
		let html: String = "<p>&sup1;&sup2;&sup3;&frac14;&frac12;&frac34;</p>"
		let doc: Document = try SwiftSoup.parse(html)
		doc.outputSettings().charset(.ascii)
		let p: Element = try doc.select("p").first()!
		XCTAssertEqual("&sup1;&sup2;&sup3;&frac14;&frac12;&frac34;", try p.html())
		XCTAssertEqual("¹²³¼½¾", try p.text())
		doc.outputSettings().charset(.utf8)
		XCTAssertEqual("¹²³¼½¾", try p.html())
	}

	func testNoSpuriousDecodes()throws {
		let string: String = "http://www.foo.com?a=1&num_rooms=1&children=0&int=VA&b=2"
		XCTAssertEqual(string, try Entities.unescape(string))
	}

	func testUscapesGtInXmlAttributesButNotInHtml()throws {
		// https://github.com/jhy/jsoup/issues/528 - < is OK in HTML attribute values, but not in XML

		let docHtml: String = "<a title='<p>One</p>'>One</a>"
		let doc: Document = try SwiftSoup.parse(docHtml)
		let element: Element = try doc.select("a").first()!

		doc.outputSettings().escapeMode(Entities.EscapeMode.base)
		XCTAssertEqual("<a title=\"<p>One</p>\">One</a>", try element.outerHtml())

		doc.outputSettings().escapeMode(Entities.EscapeMode.xhtml)
		XCTAssertEqual("<a title=\"&lt;p>One&lt;/p>\">One</a>", try  element.outerHtml())
	}
    

	static var allTests = {
		return [
			("testEscape", testEscape),
			("testXhtml", testXhtml),
			("testGetByName", testGetByName),
			("testEscapeSupplementaryCharacter", testEscapeSupplementaryCharacter),
			("testNotMissingMultis", testNotMissingMultis),
			("testnotMissingSupplementals", testnotMissingSupplementals),
			("testUnescape", testUnescape),
			("testStrictUnescape", testStrictUnescape),
			("testCaseSensitive", testCaseSensitive),
			("testQuoteReplacements", testQuoteReplacements),
			("testLetterDigitEntities", testLetterDigitEntities),
			("testNoSpuriousDecodes", testNoSpuriousDecodes),
			("testUscapesGtInXmlAttributesButNotInHtml", testUscapesGtInXmlAttributesButNotInHtml)
		]
	}()
}
