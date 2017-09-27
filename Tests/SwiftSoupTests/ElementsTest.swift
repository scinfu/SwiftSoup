//
//  ElementsTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//
/**
Tests for ElementList.
*/
import XCTest
import SwiftSoup
class ElementsTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

	func testFilter()throws {
		let h: String = "<p>Excl</p><div class=headline><p>Hello</p><p>There</p></div><div class=headline><h1>Headline</h1></div>"
		let doc: Document = try SwiftSoup.parse(h)
		let els: Elements = try doc.select(".headline").select("p")
		XCTAssertEqual(2, els.size())
		try XCTAssertEqual("Hello", els.get(0).text())
		try XCTAssertEqual("There", els.get(1).text())
	}

	func testAttributes()throws {
		let h = "<p title=foo><p title=bar><p class=foo><p class=bar>"
		let doc: Document = try SwiftSoup.parse(h)
		let withTitle: Elements = try doc.select("p[title]")
		XCTAssertEqual(2, withTitle.size())
		XCTAssertTrue(withTitle.hasAttr("title"))
		XCTAssertFalse(withTitle.hasAttr("class"))
		try XCTAssertEqual("foo", withTitle.attr("title"))

		try withTitle.removeAttr("title")
		XCTAssertEqual(2, withTitle.size()) // existing Elements are not reevaluated
		try XCTAssertEqual(0, doc.select("p[title]").size())

		let ps: Elements = try doc.select("p").attr("style", "classy")
		XCTAssertEqual(4, ps.size())
		try XCTAssertEqual("classy", ps.last()?.attr("style"))
		try XCTAssertEqual("bar", ps.last()?.attr("class"))
	}

	func testHasAttr()throws {
		let doc: Document = try SwiftSoup.parse("<p title=foo><p title=bar><p class=foo><p class=bar>")
		let ps: Elements = try doc.select("p")
		XCTAssertTrue(ps.hasAttr("class"))
		XCTAssertFalse(ps.hasAttr("style"))
	}

	func testHasAbsAttr()throws {
		let doc: Document = try SwiftSoup.parse("<a id=1 href='/foo'>One</a> <a id=2 href='https://jsoup.org'>Two</a>")
		let one: Elements = try doc.select("#1")
		let two: Elements = try doc.select("#2")
		let both: Elements = try doc.select("a")
		XCTAssertFalse(one.hasAttr("abs:href"))
		XCTAssertTrue(two.hasAttr("abs:href"))
		XCTAssertTrue(both.hasAttr("abs:href")) // hits on #2
	}

	func testAttr()throws {
		let doc: Document = try SwiftSoup.parse("<p title=foo><p title=bar><p class=foo><p class=bar>")
		let classVal = try doc.select("p").attr("class")
		XCTAssertEqual("foo", classVal)
	}

	func testAbsAttr()throws {
		let doc: Document = try SwiftSoup.parse("<a id=1 href='/foo'>One</a> <a id=2 href='https://jsoup.org'>Two</a>")
		let one: Elements = try doc.select("#1")
		let two: Elements = try doc.select("#2")
		let both: Elements = try doc.select("a")

		XCTAssertEqual("", try one.attr("abs:href"))
		XCTAssertEqual("https://jsoup.org", try two.attr("abs:href"))
		XCTAssertEqual("https://jsoup.org", try both.attr("abs:href"))
	}

	func testClasses()throws {
		let doc: Document = try SwiftSoup.parse("<div><p class='mellow yellow'></p><p class='red green'></p>")

		let els: Elements = try doc.select("p")
		XCTAssertTrue(els.hasClass("red"))
		XCTAssertFalse(els.hasClass("blue"))
		try els.addClass("blue")
		try els.removeClass("yellow")
		try els.toggleClass("mellow")

		XCTAssertEqual("blue", try els.get(0).className())
		XCTAssertEqual("red green blue mellow", try els.get(1).className())
	}

	func testText()throws {
		let h = "<div><p>Hello<p>there<p>world</div>"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("Hello there world", try doc.select("div > *").text())
	}

	func testHasText()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div><div><p></p></div>")
		let divs: Elements = try doc.select("div")
		XCTAssertTrue(divs.hasText())
		XCTAssertFalse(try doc.select("div + div").hasText())
	}

	func testHtml()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div><div><p>There</p></div>")
		let divs: Elements = try doc.select("div")
		XCTAssertEqual("<p>Hello</p>\n<p>There</p>", try divs.html())
	}

	func testOuterHtml()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div><div><p>There</p></div>")
		let divs: Elements = try doc.select("div")
		XCTAssertEqual("<div><p>Hello</p></div><div><p>There</p></div>", try TextUtil.stripNewlines(divs.outerHtml()))
	}

	func testSetHtml()throws {
		let doc: Document = try SwiftSoup.parse("<p>One</p><p>Two</p><p>Three</p>")
		let ps: Elements = try doc.select("p")

		try ps.prepend("<b>Bold</b>").append("<i>Ital</i>")
		try XCTAssertEqual("<p><b>Bold</b>Two<i>Ital</i></p>", TextUtil.stripNewlines(ps.get(1).outerHtml()))

		try ps.html("<span>Gone</span>")
		try XCTAssertEqual("<p><span>Gone</span></p>", TextUtil.stripNewlines(ps.get(1).outerHtml()))
	}

	func testVal()throws {
		let doc: Document = try SwiftSoup.parse("<input value='one' /><textarea>two</textarea>")
		let els: Elements = try doc.select("input, textarea")
		XCTAssertEqual(2, els.size())
		try XCTAssertEqual("one", els.val())
		try XCTAssertEqual("two", els.last()?.val())

		try els.val("three")
		try XCTAssertEqual("three", els.first()?.val())
		try XCTAssertEqual("three", els.last()?.val())
		try XCTAssertEqual("<textarea>three</textarea>", els.last()?.outerHtml())
	}

	func testBefore()throws {
		let doc: Document = try SwiftSoup.parse("<p>This <a>is</a> <a>jsoup</a>.</p>")
		try doc.select("a").before("<span>foo</span>")
		XCTAssertEqual("<p>This <span>foo</span><a>is</a> <span>foo</span><a>jsoup</a>.</p>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testAfter()throws {
		let doc: Document = try SwiftSoup.parse("<p>This <a>is</a> <a>jsoup</a>.</p>")
		try doc.select("a").after("<span>foo</span>")
		XCTAssertEqual("<p>This <a>is</a><span>foo</span> <a>jsoup</a><span>foo</span>.</p>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testWrap()throws {
		let h = "<p><b>This</b> is <b>jsoup</b></p>"
		let doc: Document = try SwiftSoup.parse(h)
		try doc.select("b").wrap("<i></i>")
		XCTAssertEqual("<p><i><b>This</b></i> is <i><b>jsoup</b></i></p>", try doc.body()?.html())
	}

	func testWrapDiv()throws {
		let h = "<p><b>This</b> is <b>jsoup</b>.</p> <p>How do you like it?</p>"
		let doc: Document = try SwiftSoup.parse(h)
		try doc.select("p").wrap("<div></div>")
		XCTAssertEqual("<div><p><b>This</b> is <b>jsoup</b>.</p></div> <div><p>How do you like it?</p></div>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testUnwrap()throws {
		let h = "<div><font>One</font> <font><a href=\"/\">Two</a></font></div"
		let doc: Document = try SwiftSoup.parse(h)
		try doc.select("font").unwrap()
		XCTAssertEqual("<div>One <a href=\"/\">Two</a></div>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testUnwrapP()throws {
		let h = "<p><a>One</a> Two</p> Three <i>Four</i> <p>Fix <i>Six</i></p>"
		let doc: Document = try SwiftSoup.parse(h)
		try doc.select("p").unwrap()
		XCTAssertEqual("<a>One</a> Two Three <i>Four</i> Fix <i>Six</i>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testUnwrapKeepsSpace()throws {
		let h = "<p>One <span>two</span> <span>three</span> four</p>"
		let doc: Document = try SwiftSoup.parse(h)
		try doc.select("span").unwrap()
		XCTAssertEqual("<p>One two three four</p>", try doc.body()?.html())
	}

	func testEmpty()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello <b>there</b></p> <p>now!</p></div>")
		doc.outputSettings().prettyPrint(pretty: false)

		try doc.select("p").empty()
		XCTAssertEqual("<div><p></p> <p></p></div>", try doc.body()?.html())
	}

	func testRemove()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello <b>there</b></p> jsoup <p>now!</p></div>")
		doc.outputSettings().prettyPrint(pretty: false)

		try doc.select("p").remove()
		XCTAssertEqual("<div> jsoup </div>", try doc.body()?.html())
	}

	func testEq()throws {
		let h = "<p>Hello<p>there<p>world"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("there", try doc.select("p").eq(1).text())
		XCTAssertEqual("there", try doc.select("p").get(1).text())
	}

	func testIs()throws {
		let h = "<p>Hello<p title=foo>there<p>world"
		let doc: Document = try SwiftSoup.parse(h)
		let ps: Elements = try doc.select("p")
		try XCTAssertTrue(ps.iS("[title=foo]"))
		try XCTAssertFalse(ps.iS("[title=bar]"))
	}

	func testParents()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div><p>There</p>")
		let parents: Elements = try doc.select("p").parents()

		XCTAssertEqual(3, parents.size())
		XCTAssertEqual("div", parents.get(0).tagName())
		XCTAssertEqual("body", parents.get(1).tagName())
		XCTAssertEqual("html", parents.get(2).tagName())
	}

	func testNot()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>One</p></div> <div id=2><p><span>Two</span></p></div>")

		let div1: Elements = try doc.select("div").not(":has(p > span)")
		XCTAssertEqual(1, div1.size())
		XCTAssertEqual("1", div1.first()?.id())

		let div2: Elements = try doc.select("div").not("#1")
		XCTAssertEqual(1, div2.size())
		XCTAssertEqual("2", div2.first()?.id())
	}

	func testTagNameSet()throws {
		let doc: Document = try SwiftSoup.parse("<p>Hello <i>there</i> <i>now</i></p>")
		try doc.select("i").tagName("em")

		XCTAssertEqual("<p>Hello <em>there</em> <em>now</em></p>", try doc.body()?.html())
	}

	func testTraverse()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div><div>There</div>")
		let accum: StringBuilder = StringBuilder()

		class nv: NodeVisitor {
			let accum: StringBuilder
			init(_ accum: StringBuilder) {
				self.accum = accum
			}
			public func head(_ node: Node, _ depth: Int) {
				accum.append("<" + node.nodeName() + ">")
			}
			public func tail(_ node: Node, _ depth: Int) {
				accum.append("</" + node.nodeName() + ">")
			}
		}
		try doc.select("div").traverse(nv(accum))
		XCTAssertEqual("<div><p><#text></#text></p></div><div><#text></#text></div>", accum.toString())
	}

	func testForms()throws {
		let doc: Document = try SwiftSoup.parse("<form id=1><input name=q></form><div /><form id=2><input name=f></form>")
		let els: Elements = try doc.select("*")
		XCTAssertEqual(9, els.size())

		let forms: Array<FormElement> = els.forms()
		XCTAssertEqual(2, forms.count)
		//XCTAssertTrue(forms[0] != nil)
		//XCTAssertTrue(forms[1] != nil)
		XCTAssertEqual("1", forms[0].id())
		XCTAssertEqual("2", forms[1].id())
	}

	func testClassWithHyphen()throws {
		let doc: Document = try SwiftSoup.parse("<p class='tab-nav'>Check</p>")
		let els: Elements = try doc.getElementsByClass("tab-nav")
		XCTAssertEqual(1, els.size())
		try XCTAssertEqual("Check", els.text())
	}

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testFilter", testFilter),
			("testAttributes", testAttributes),
			("testHasAttr", testHasAttr),
			("testHasAbsAttr", testHasAbsAttr),
			("testAttr", testAttr),
			("testAbsAttr", testAbsAttr),
			("testClasses", testClasses),
			("testText", testText),
			("testHasText", testHasText),
			("testHtml", testHtml),
			("testOuterHtml", testOuterHtml),
			("testSetHtml", testSetHtml),
			("testVal", testVal),
			("testBefore", testBefore),
			("testAfter", testAfter),
			("testWrap", testWrap),
			("testWrapDiv", testWrapDiv),
			("testUnwrap", testUnwrap),
			("testUnwrapP", testUnwrapP),
			("testUnwrapKeepsSpace", testUnwrapKeepsSpace),
			("testEmpty", testEmpty),
			("testRemove", testRemove),
			("testEq", testEq),
			("testIs", testIs),
			("testParents", testParents),
			("testNot", testNot),
			("testTagNameSet", testTagNameSet),
			("testTraverse", testTraverse),
			("testForms", testForms),
			("testClassWithHyphen", testClassWithHyphen)
		]
	}()
}
