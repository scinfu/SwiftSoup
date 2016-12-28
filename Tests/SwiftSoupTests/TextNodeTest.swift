//
//  TextNodeTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 09/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
@testable import SwiftSoup

class TextNodeTest: XCTestCase {

	func testBlank() {
		let one = TextNode("", "")
		let two = TextNode("     ", "")
		let three = TextNode("  \n\n   ", "")
		let four = TextNode("Hello", "")
		let five = TextNode("  \nHello ", "")

		XCTAssertTrue(one.isBlank())
		XCTAssertTrue(two.isBlank())
		XCTAssertTrue(three.isBlank())
		XCTAssertFalse(four.isBlank())
		XCTAssertFalse(five.isBlank())
	}

	func testTextBean()throws {
		let doc = try SwiftSoup.parse("<p>One <span>two &amp;</span> three &amp;</p>")
		let p: Element = try doc.select("p").first()!

		let span: Element = try doc.select("span").first()!
		XCTAssertEqual("two &", try span.text())
		let spanText: TextNode =  span.childNode(0) as! TextNode
		XCTAssertEqual("two &", spanText.text())

		let tn: TextNode = p.childNode(2) as! TextNode
		XCTAssertEqual(" three &", tn.text())

		tn.text(" POW!")
		XCTAssertEqual("One <span>two &amp;</span> POW!", TextUtil.stripNewlines(try p.html()))

		try _ = tn.attr("text", "kablam &")
		XCTAssertEqual("kablam &", tn.text())
		XCTAssertEqual("One <span>two &amp;</span>kablam &amp;", try TextUtil.stripNewlines(p.html()))
	}

	func testSplitText()throws {
		let doc: Document = try SwiftSoup.parse("<div>Hello there</div>")
		let div: Element = try doc.select("div").first()!
		let tn: TextNode =  div.childNode(0) as! TextNode
		let tail: TextNode = try tn.splitText(6)
		XCTAssertEqual("Hello ", tn.getWholeText())
		XCTAssertEqual("there", tail.getWholeText())
		tail.text("there!")
		XCTAssertEqual("Hello there!", try div.text())
		XCTAssertTrue(tn.parent() == tail.parent())
	}

	func testSplitAnEmbolden()throws {
		let doc: Document = try SwiftSoup.parse("<div>Hello there</div>")
		let div: Element = try doc.select("div").first()!
		let tn: TextNode = div.childNode(0) as! TextNode
		let tail: TextNode = try  tn.splitText(6)
		try tail.wrap("<b></b>")

		XCTAssertEqual("Hello <b>there</b>", TextUtil.stripNewlines(try div.html())) // not great that we get \n<b>there there... must correct
	}

	func testWithSupplementaryCharacter()throws {
		#if !os(Linux)
			let doc: Document = try SwiftSoup.parse(String(Character(UnicodeScalar(135361)!)))
			let t: TextNode = doc.body()!.textNodes()[0]
			XCTAssertEqual(String(Character(UnicodeScalar(135361)!)), try t.outerHtml().trim())
		#endif
	}

	static var allTests = {
		return [
			("testBlank", testBlank),
			("testTextBean", testTextBean),
			("testSplitText", testSplitText),
			("testSplitAnEmbolden", testSplitAnEmbolden),
			("testWithSupplementaryCharacter", testWithSupplementaryCharacter)
			]
	}()
}
