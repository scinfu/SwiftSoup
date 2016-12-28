//
//  AttributeParseTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 10/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//
/**
Test suite for attribute parser.
*/

import XCTest
import SwiftSoup

class AttributeParseTest: XCTestCase {

	func testparsesRoughAttributeString()throws {
		let html: String = "<a id=\"123\" class=\"baz = 'bar'\" style = 'border: 2px'qux zim foo = 12 mux=18 />"
		// should be: <id=123>, <class=baz = 'bar'>, <qux=>, <zim=>, <foo=12>, <mux.=18>

		let el: Element = try SwiftSoup.parse(html).getElementsByTag("a").get(0)
		let attr: Attributes = el.getAttributes()!
		XCTAssertEqual(7, attr.size())
		XCTAssertEqual("123", attr.get(key: "id"))
		XCTAssertEqual("baz = 'bar'", attr.get(key: "class"))
		XCTAssertEqual("border: 2px", attr.get(key: "style"))
		XCTAssertEqual("", attr.get(key: "qux"))
		XCTAssertEqual("", attr.get(key: "zim"))
		XCTAssertEqual("12", attr.get(key: "foo"))
		XCTAssertEqual("18", attr.get(key: "mux"))
	}

	func testhandlesNewLinesAndReturns()throws {
		let html: String = "<a\r\nfoo='bar\r\nqux'\r\nbar\r\n=\r\ntwo>One</a>"
		let el: Element = try SwiftSoup.parse(html).select("a").first()!
		XCTAssertEqual(2, el.getAttributes()?.size())
		XCTAssertEqual("bar\r\nqux", try el.attr("foo")) // currently preserves newlines in quoted attributes. todo confirm if should.
		XCTAssertEqual("two", try el.attr("bar"))
	}

	func testparsesEmptyString()throws {
		let html: String = "<a />"
		let el: Element = try SwiftSoup.parse(html).getElementsByTag("a").get(0)
		let attr: Attributes = el.getAttributes()!
		XCTAssertEqual(0, attr.size())
	}

	func testcanStartWithEq()throws {
		let html: String = "<a =empty />"
		let el: Element = try SwiftSoup.parse(html).getElementsByTag("a").get(0)
		let attr: Attributes = el.getAttributes()!
		XCTAssertEqual(1, attr.size())
		XCTAssertTrue(attr.hasKey(key: "=empty"))
		XCTAssertEqual("", attr.get(key: "=empty"))
	}

	func teststrictAttributeUnescapes()throws {
		let html: String = "<a id=1 href='?foo=bar&mid&lt=true'>One</a> <a id=2 href='?foo=bar&lt;qux&lg=1'>Two</a>"
		let els: Elements = try SwiftSoup.parse(html).select("a")
		XCTAssertEqual("?foo=bar&mid&lt=true", try els.first()!.attr("href"))
		XCTAssertEqual("?foo=bar<qux&lg=1", try els.last()!.attr("href"))
	}

	func testmoreAttributeUnescapes()throws {
		let html: String = "<a href='&wr_id=123&mid-size=true&ok=&wr'>Check</a>"
		let els: Elements = try SwiftSoup.parse(html).select("a")
		XCTAssertEqual("&wr_id=123&mid-size=true&ok=&wr", try  els.first()!.attr("href"))
	}

	func testparsesBooleanAttributes()throws {
		let html: String = "<a normal=\"123\" boolean empty=\"\"></a>"
		let el: Element = try SwiftSoup.parse(html).select("a").first()!

		XCTAssertEqual("123", try el.attr("normal"))
		XCTAssertEqual("", try el.attr("boolean"))
		XCTAssertEqual("", try el.attr("empty"))

		let attributes: Array<Attribute> = el.getAttributes()!.asList()
		XCTAssertEqual(3, attributes.count, "There should be 3 attribute present")

		// Assuming the list order always follows the parsed html
		XCTAssertFalse((attributes[0] as? BooleanAttribute) != nil, "'normal' attribute should not be boolean")
		XCTAssertTrue((attributes[1] as? BooleanAttribute) != nil, "'boolean' attribute should be boolean")
		XCTAssertFalse((attributes[2] as? BooleanAttribute) != nil, "'empty' attribute should not be boolean")

		XCTAssertEqual(html, try el.outerHtml())
	}

	func testdropsSlashFromAttributeName()throws {
		let html: String = "<img /onerror='doMyJob'/>"
		var doc: Document = try SwiftSoup.parse(html)
		XCTAssertTrue(try doc.select("img[onerror]").size() != 0, "SelfClosingStartTag ignores last character")
		XCTAssertEqual("<img onerror=\"doMyJob\">", try doc.body()!.html())

		doc = try SwiftSoup.parse(html, "", Parser.xmlParser())
		XCTAssertEqual("<img onerror=\"doMyJob\" />", try doc.html())
	}

	static var allTests = {
		return [
			("testparsesRoughAttributeString", testparsesRoughAttributeString),
			("testhandlesNewLinesAndReturns", testhandlesNewLinesAndReturns),
			("testparsesEmptyString", testparsesEmptyString),
			("testcanStartWithEq", testcanStartWithEq),
			("teststrictAttributeUnescapes", teststrictAttributeUnescapes),
			("testmoreAttributeUnescapes", testmoreAttributeUnescapes),
			("testparsesBooleanAttributes", testparsesBooleanAttributes),
			("testdropsSlashFromAttributeName", testdropsSlashFromAttributeName),
		]
	}()

}
