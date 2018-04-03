//
//  CssTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 11/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class CssTest: XCTestCase {
	var html: Document!
	private var htmlString: String!

	override func setUp() {
		super.setUp()

		let sb: StringBuilder = StringBuilder(string: "<html><head></head><body>")

		sb.append("<div id='pseudo'>")
		for i in 1...10 {
			sb.append("<p>\(i)</p>")
		}
		sb.append("</div>")

		sb.append("<div id='type'>")
		for i in 1...10 {
			sb.append("<p>\(i)</p>")
			sb.append("<span>\(i)</span>")
			sb.append("<em>\(i)</em>")
			sb.append("<svg>\(i)</svg>")
		}
		sb.append("</div>")

		sb.append("<span id='onlySpan'><br /></span>")
		sb.append("<p class='empty'><!-- Comment only is still empty! --></p>")

		sb.append("<div id='only'>")
		sb.append("Some text before the <em>only</em> child in this div")
		sb.append("</div>")

		sb.append("</body></html>")
		htmlString = sb.toString()
		html  = try! SwiftSoup.parse(htmlString)
	}

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

	func testFirstChild()throws {
		try check(html.select("#pseudo :first-child"), "1")
		try check(html.select("html:first-child"))
	}

	func testLastChild()throws {
        try! check(html.select("#pseudo :last-child"), "10")
        try! check(html.select("html:last-child"))
	}

	func testNthChild_simple()throws {
		for i in 1...10 {
			try check(html.select("#pseudo :nth-child(\(i))"), "\(i)")
		}
	}

	func testNthOfType_unknownTag()throws {
		for i in 1...10 {
			try check(html.select("#type svg:nth-of-type(\(i))"), "\(i)")
		}
	}

	func testNthLastChild_simple()throws {
		for i in 1...10 {
			try check(html.select("#pseudo :nth-last-child(\(i))"), "\(11-i)")
		}
	}

	func testNthOfType_simple()throws {
		for i in 1...10 {
			try check(html.select("#type p:nth-of-type(\(i))"), "\(i)")
		}
	}

	func testNthLastOfType_simple()throws {
		for i in 1...10 {
			try check(html.select("#type :nth-last-of-type(\(i))"), "\(11-i)", "\(11-i)", "\(11-i)", "\(11-i)")
		}
	}

	func testNthChild_advanced()throws {
		try check(html.select("#pseudo :nth-child(-5)"))
		try check(html.select("#pseudo :nth-child(odd)"), "1", "3", "5", "7", "9")
		try check(html.select("#pseudo :nth-child(2n-1)"), "1", "3", "5", "7", "9")
		try check(html.select("#pseudo :nth-child(2n+1)"), "1", "3", "5", "7", "9")
		try check(html.select("#pseudo :nth-child(2n+3)"), "3", "5", "7", "9")
		try check(html.select("#pseudo :nth-child(even)"), "2", "4", "6", "8", "10")
		try check(html.select("#pseudo :nth-child(2n)"), "2", "4", "6", "8", "10")
		try check(html.select("#pseudo :nth-child(3n-1)"), "2", "5", "8")
		try check(html.select("#pseudo :nth-child(-2n+5)"), "1", "3", "5")
		try check(html.select("#pseudo :nth-child(+5)"), "5")
	}

	func testNthOfType_advanced()throws {
		try check(html.select("#type :nth-of-type(-5)"))
		try check(html.select("#type p:nth-of-type(odd)"), "1", "3", "5", "7", "9")
		try check(html.select("#type em:nth-of-type(2n-1)"), "1", "3", "5", "7", "9")
		try check(html.select("#type p:nth-of-type(2n+1)"), "1", "3", "5", "7", "9")
		try check(html.select("#type span:nth-of-type(2n+3)"), "3", "5", "7", "9")
		try check(html.select("#type p:nth-of-type(even)"), "2", "4", "6", "8", "10")
		try check(html.select("#type p:nth-of-type(2n)"), "2", "4", "6", "8", "10")
		try check(html.select("#type p:nth-of-type(3n-1)"), "2", "5", "8")
		try check(html.select("#type p:nth-of-type(-2n+5)"), "1", "3", "5")
		try check(html.select("#type :nth-of-type(+5)"), "5", "5", "5", "5")
	}

	func testNthLastChild_advanced()throws {
		try check(html.select("#pseudo :nth-last-child(-5)"))
		try check(html.select("#pseudo :nth-last-child(odd)"), "2", "4", "6", "8", "10")
		try check(html.select("#pseudo :nth-last-child(2n-1)"), "2", "4", "6", "8", "10")
		try check(html.select("#pseudo :nth-last-child(2n+1)"), "2", "4", "6", "8", "10")
		try check(html.select("#pseudo :nth-last-child(2n+3)"), "2", "4", "6", "8")
		try check(html.select("#pseudo :nth-last-child(even)"), "1", "3", "5", "7", "9")
		try check(html.select("#pseudo :nth-last-child(2n)"), "1", "3", "5", "7", "9")
		try check(html.select("#pseudo :nth-last-child(3n-1)"), "3", "6", "9")

		try check(html.select("#pseudo :nth-last-child(-2n+5)"), "6", "8", "10")
		try check(html.select("#pseudo :nth-last-child(+5)"), "6")
	}

	func testNthLastOfType_advanced()throws {
		try check(html.select("#type :nth-last-of-type(-5)"))
		try check(html.select("#type p:nth-last-of-type(odd)"), "2", "4", "6", "8", "10")
		try check(html.select("#type em:nth-last-of-type(2n-1)"), "2", "4", "6", "8", "10")
		try check(html.select("#type p:nth-last-of-type(2n+1)"), "2", "4", "6", "8", "10")
		try check(html.select("#type span:nth-last-of-type(2n+3)"), "2", "4", "6", "8")
		try check(html.select("#type p:nth-last-of-type(even)"), "1", "3", "5", "7", "9")
		try check(html.select("#type p:nth-last-of-type(2n)"), "1", "3", "5", "7", "9")
		try check(html.select("#type p:nth-last-of-type(3n-1)"), "3", "6", "9")

		try check(html.select("#type span:nth-last-of-type(-2n+5)"), "6", "8", "10")
		try check(html.select("#type :nth-last-of-type(+5)"), "6", "6", "6", "6")
	}

	func testFirstOfType()throws {
		try check(html.select("div:not(#only) :first-of-type"), "1", "1", "1", "1", "1")
	}

	func testLastOfType()throws {
		try check(html.select("div:not(#only) :last-of-type"), "10", "10", "10", "10", "10")
	}

	func testEmpty()throws {
		let sel: Elements = try html.select(":empty")
		XCTAssertEqual(3, sel.size())
		XCTAssertEqual("head", sel.get(0).tagName())
		XCTAssertEqual("br", sel.get(1).tagName())
		XCTAssertEqual("p", sel.get(2).tagName())
	}

	func testOnlyChild()throws {
		let sel: Elements = try html.select("span :only-child")
		XCTAssertEqual(1, sel.size())
		XCTAssertEqual("br", sel.get(0).tagName())

		try check(html.select("#only :only-child"), "only")
	}

	func testOnlyOfType()throws {
		let sel: Elements = try html.select(":only-of-type")
		XCTAssertEqual(6, sel.size())
		XCTAssertEqual("head", sel.get(0).tagName())
		XCTAssertEqual("body", sel.get(1).tagName())
		XCTAssertEqual("span", sel.get(2).tagName())
		XCTAssertEqual("br", sel.get(3).tagName())
		XCTAssertEqual("p", sel.get(4).tagName())
		XCTAssertTrue(sel.get(4).hasClass("empty"))
		XCTAssertEqual("em", sel.get(5).tagName())
	}

	func check(_ resut: Elements, _ expectedContent: String... ) {
		check(resut, expectedContent)
	}

	func check(_ result: Elements, _ expectedContent: [String] ) {
		XCTAssertEqual(expectedContent.count, result.size())
		for i in 0..<expectedContent.count {
			XCTAssertNotNil(result.get(i))
			XCTAssertEqual(expectedContent[i], result.get(i).ownText())
		}
	}

	func testRoot()throws {
		let sel: Elements = try html.select(":root")
		XCTAssertEqual(1, sel.size())
		XCTAssertNotNil(sel.get(0))
		try XCTAssertEqual(Tag.valueOf("html"), sel.get(0).tag())

		let sel2: Elements = try html.select("body").select(":root")
		XCTAssertEqual(1, sel2.size())
		XCTAssertNotNil(sel2.get(0))
		try XCTAssertEqual(Tag.valueOf("body"), sel2.get(0).tag())
	}

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testFirstChild", testFirstChild),
			("testLastChild", testLastChild),
			("testNthChild_simple", testNthChild_simple),
			("testNthOfType_unknownTag", testNthOfType_unknownTag),
			("testNthLastChild_simple", testNthLastChild_simple),
			("testNthOfType_simple", testNthOfType_simple),
			("testNthLastOfType_simple", testNthLastOfType_simple),
			("testNthChild_advanced", testNthChild_advanced),
			("testNthOfType_advanced", testNthOfType_advanced),
			("testNthLastChild_advanced", testNthLastChild_advanced),
			("testNthLastOfType_advanced", testNthLastOfType_advanced),
			("testFirstOfType", testFirstOfType),
			("testLastOfType", testLastOfType),
			("testEmpty", testEmpty),
			("testOnlyChild", testOnlyChild),
			("testOnlyOfType", testOnlyOfType),
			("testRoot", testRoot)
		]
	}()
}
