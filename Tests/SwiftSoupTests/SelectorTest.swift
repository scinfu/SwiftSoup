//
//  SelectorTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class SelectorTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

	func testByTag()throws {
		// should be case insensitive
		let els: Elements = try SwiftSoup.parse("<div id=1><div id=2><p>Hello</p></div></div><DIV id=3>").select("DIV")
		XCTAssertEqual(3, els.size())
		XCTAssertEqual("1", els.get(0).id())
		XCTAssertEqual("2", els.get(1).id())
		XCTAssertEqual("3", els.get(2).id())

		let none: Elements = try SwiftSoup.parse("<div id=1><div id=2><p>Hello</p></div></div><div id=3>").select("span")
		XCTAssertEqual(0, none.size())
	}

	func testById()throws {
		let els: Elements = try SwiftSoup.parse("<div><p id=foo>Hello</p><p id=foo>Foo two!</p></div>").select("#foo")
		XCTAssertEqual(2, els.size())
		XCTAssertEqual("Hello", try els.get(0).text())
		XCTAssertEqual("Foo two!", try els.get(1).text())

		let none: Elements = try SwiftSoup.parse("<div id=1></div>").select("#foo")
		XCTAssertEqual(0, none.size())
	}

	func testByClass()throws {
		let els: Elements = try SwiftSoup.parse("<p id=0 class='ONE two'><p id=1 class='one'><p id=2 class='two'>").select("P.One")
		XCTAssertEqual(2, els.size())
		XCTAssertEqual("0", els.get(0).id())
		XCTAssertEqual("1", els.get(1).id())

		let none: Elements = try SwiftSoup.parse("<div class='one'></div>").select(".foo")
		XCTAssertEqual(0, none.size())

		let els2: Elements = try SwiftSoup.parse("<div class='One-Two'></div>").select(".one-two")
		XCTAssertEqual(1, els2.size())
	}

	func testByAttribute()throws {
		let h: String = "<div Title=Foo /><div Title=Bar /><div Style=Qux /><div title=Bam /><div title=SLAM />" +
		"<div data-name='with spaces'/>"
		let doc: Document = try SwiftSoup.parse(h)

		let withTitle: Elements = try doc.select("[title]")
		XCTAssertEqual(4, withTitle.size())

		let foo: Elements = try doc.select("[TITLE=foo]")
		XCTAssertEqual(1, foo.size())

		let foo2: Elements = try doc.select("[title=\"foo\"]")
		XCTAssertEqual(1, foo2.size())

		let foo3: Elements = try doc.select("[title=\"Foo\"]")
		XCTAssertEqual(1, foo3.size())

		let dataName: Elements = try doc.select("[data-name=\"with spaces\"]")
		XCTAssertEqual(1, dataName.size())
		XCTAssertEqual("with spaces", try dataName.first()?.attr("data-name"))

		let not: Elements = try doc.select("div[title!=bar]")
		XCTAssertEqual(5, not.size())
		XCTAssertEqual("Foo", try not.first()?.attr("title"))

		let starts: Elements = try doc.select("[title^=ba]")
		XCTAssertEqual(2, starts.size())
		XCTAssertEqual("Bar", try starts.first()?.attr("title"))
		XCTAssertEqual("Bam", try starts.last()?.attr("title"))

		let ends: Elements = try doc.select("[title$=am]")
		XCTAssertEqual(2, ends.size())
		XCTAssertEqual("Bam", try ends.first()?.attr("title"))
		XCTAssertEqual("SLAM", try ends.last()?.attr("title"))

		let contains: Elements = try doc.select("[title*=a]")
		XCTAssertEqual(3, contains.size())
		XCTAssertEqual("Bar", try contains.first()?.attr("title"))
		XCTAssertEqual("SLAM", try contains.last()?.attr("title"))
	}

	func testNamespacedTag()throws {
		let doc: Document = try SwiftSoup.parse("<div><abc:def id=1>Hello</abc:def></div> <abc:def class=bold id=2>There</abc:def>")
		let byTag: Elements = try doc.select("abc|def")
		XCTAssertEqual(2, byTag.size())
		XCTAssertEqual("1", byTag.first()?.id())
		XCTAssertEqual("2", byTag.last()?.id())

		let byAttr: Elements = try doc.select(".bold")
		XCTAssertEqual(1, byAttr.size())
		XCTAssertEqual("2", byAttr.last()?.id())

		let byTagAttr: Elements = try doc.select("abc|def.bold")
		XCTAssertEqual(1, byTagAttr.size())
		XCTAssertEqual("2", byTagAttr.last()?.id())

		let byContains: Elements = try doc.select("abc|def:contains(e)")
		XCTAssertEqual(2, byContains.size())
		XCTAssertEqual("1", byContains.first()?.id())
		XCTAssertEqual("2", byContains.last()?.id())
	}

	func testWildcardNamespacedTag()throws {
		let doc: Document = try SwiftSoup.parse("<div><abc:def id=1>Hello</abc:def></div> <abc:def class=bold id=2>There</abc:def>")
		let byTag: Elements = try doc.select("*|def")
		XCTAssertEqual(2, byTag.size())
		XCTAssertEqual("1", byTag.first()?.id())
		XCTAssertEqual("2", byTag.last()?.id())

		let byAttr: Elements = try doc.select(".bold")
		XCTAssertEqual(1, byAttr.size())
		XCTAssertEqual("2", byAttr.last()?.id())

		let byTagAttr: Elements = try doc.select("*|def.bold")
		XCTAssertEqual(1, byTagAttr.size())
		XCTAssertEqual("2", byTagAttr.last()?.id())

		let byContains: Elements = try doc.select("*|def:contains(e)")
		XCTAssertEqual(2, byContains.size())
		XCTAssertEqual("1", byContains.first()?.id())
		XCTAssertEqual("2", byContains.last()?.id())
	}

	func testByAttributeStarting()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1 data-name=jsoup>Hello</div><p data-val=5 id=2>There</p><p id=3>No</p>")
		var withData: Elements = try doc.select("[^data-]")
		XCTAssertEqual(2, withData.size())
		XCTAssertEqual("1", withData.first()?.id())
		XCTAssertEqual("2", withData.last()?.id())

		withData = try doc.select("p[^data-]")
		XCTAssertEqual(1, withData.size())
		XCTAssertEqual("2", withData.first()?.id())
	}

	func testByAttributeRegex()throws {
		let doc: Document = try SwiftSoup.parse("<p><img src=foo.png id=1><img src=bar.jpg id=2><img src=qux.JPEG id=3><img src=old.gif><img></p>")
		let imgs: Elements = try doc.select("img[src~=(?i)\\.(png|jpe?g)]")
		XCTAssertEqual(3, imgs.size())
		XCTAssertEqual("1", imgs.get(0).id())
		XCTAssertEqual("2", imgs.get(1).id())
		XCTAssertEqual("3", imgs.get(2).id())
	}

	func testByAttributeRegexCharacterClass()throws {
		let doc: Document = try SwiftSoup.parse("<p><img src=foo.png id=1><img src=bar.jpg id=2><img src=qux.JPEG id=3><img src=old.gif id=4></p>")
		let imgs: Elements = try doc.select("img[src~=[o]]")
		XCTAssertEqual(2, imgs.size())
		XCTAssertEqual("1", imgs.get(0).id())
		XCTAssertEqual("4", imgs.get(1).id())
	}

	func testByAttributeRegexCombined()throws {
		let doc: Document = try SwiftSoup.parse("<div><table class=x><td>Hello</td></table></div>")
		let els: Elements = try doc.select("div table[class~=x|y]")
		XCTAssertEqual(1, els.size())
		try XCTAssertEqual("Hello", els.text())
	}

	func testCombinedWithContains()throws {
		let doc: Document = try SwiftSoup.parse("<p id=1>One</p><p>Two +</p><p>Three +</p>")
		let els: Elements = try doc.select("p#1 + :contains(+)")
		XCTAssertEqual(1, els.size())
		try XCTAssertEqual("Two +", els.text())
		XCTAssertEqual("p", els.first()?.tagName())
	}

	func testAllElements()throws {
		let h: String = "<div><p>Hello</p><p><b>there</b></p></div>"
		let doc: Document = try SwiftSoup.parse(h)
		let allDoc: Elements = try doc.select("*")
		let allUnderDiv: Elements = try doc.select("div *")
		XCTAssertEqual(8, allDoc.size())
		XCTAssertEqual(3, allUnderDiv.size())
		XCTAssertEqual("p", allUnderDiv.first()?.tagName())
	}

	func testAllWithClass()throws {
		let h: String = "<p class=first>One<p class=first>Two<p>Three"
		let doc: Document = try SwiftSoup.parse(h)
		let ps: Elements = try doc.select("*.first")
		XCTAssertEqual(2, ps.size())
	}

	func testGroupOr()throws {
		let h: String = "<div title=foo /><div title=bar /><div /><p></p><img /><span title=qux>"
		let doc: Document = try SwiftSoup.parse(h)
		let els: Elements = try doc.select("p,div,[title]")

		XCTAssertEqual(5, els.size())
		XCTAssertEqual("div", els.get(0).tagName())
		try XCTAssertEqual("foo", els.get(0).attr("title"))
		XCTAssertEqual("div", els.get(1).tagName())
		try XCTAssertEqual("bar", els.get(1).attr("title"))
		XCTAssertEqual("div", els.get(2).tagName())
		try XCTAssertTrue(els.get(2).attr("title").count == 0) // missing attributes come back as empty string
		XCTAssertFalse(els.get(2).hasAttr("title"))
		XCTAssertEqual("p", els.get(3).tagName())
		XCTAssertEqual("span", els.get(4).tagName())
	}

	func testGroupOrAttribute()throws {
		let h: String = "<div id=1 /><div id=2 /><div title=foo /><div title=bar />"
		let els: Elements = try SwiftSoup.parse(h).select("[id],[title=foo]")

		XCTAssertEqual(3, els.size())
		XCTAssertEqual("1", els.get(0).id())
		XCTAssertEqual("2", els.get(1).id())
		try XCTAssertEqual("foo", els.get(2).attr("title"))
	}

	func testDescendant()throws {
		let h: String = "<div class=head><p class=first>Hello</p><p>There</p></div><p>None</p>"
		let doc: Document = try SwiftSoup.parse(h)
		let root: Element = try doc.getElementsByClass("HEAD").first()!

		let els: Elements = try root.select(".head p")
		XCTAssertEqual(2, els.size())
		try XCTAssertEqual("Hello", els.get(0).text())
		try XCTAssertEqual("There", els.get(1).text())

		let p: Elements = try root.select("p.first")
		XCTAssertEqual(1, p.size())
		try XCTAssertEqual("Hello", p.get(0).text())

		let empty: Elements = try root.select("p .first") // self, not descend, should not match
		XCTAssertEqual(0, empty.size())

		let aboveRoot: Elements = try root.select("body div.head")
		XCTAssertEqual(0, aboveRoot.size())
	}

	func testAnd()throws {
		let h: String = "<div id=1 class='foo bar' title=bar name=qux><p class=foo title=bar>Hello</p></div"
		let doc: Document = try SwiftSoup.parse(h)

		let div: Elements = try doc.select("div.foo")
		XCTAssertEqual(1, div.size())
		XCTAssertEqual("div", div.first()?.tagName())

		let p: Elements = try doc.select("div .foo") // space indicates like "div *.foo"
		XCTAssertEqual(1, p.size())
		XCTAssertEqual("p", p.first()?.tagName())

		let div2: Elements = try doc.select("div#1.foo.bar[title=bar][name=qux]") // very specific!
		XCTAssertEqual(1, div2.size())
		XCTAssertEqual("div", div2.first()?.tagName())

		let p2: Elements = try doc.select("div *.foo") // space indicates like "div *.foo"
		XCTAssertEqual(1, p2.size())
		XCTAssertEqual("p", p2.first()?.tagName())
	}

	func testDeeperDescendant()throws {
		let h: String = "<div class=head><p><span class=first>Hello</div><div class=head><p class=first><span>Another</span><p>Again</div>"
		let doc: Document = try SwiftSoup.parse(h)
		let root: Element = try doc.getElementsByClass("head").first()!

		let els: Elements = try root.select("div p .first")
		XCTAssertEqual(1, els.size())
		try XCTAssertEqual("Hello", els.first()?.text())
		XCTAssertEqual("span", els.first()?.tagName())

		let aboveRoot: Elements = try root.select("body p .first")
		XCTAssertEqual(0, aboveRoot.size())
	}

	func testParentChildElement()throws {
		let h: String = "<div id=1><div id=2><div id = 3></div></div></div><div id=4></div>"
		let doc: Document = try SwiftSoup.parse(h)

		let divs: Elements = try doc.select("div > div")
		XCTAssertEqual(2, divs.size())
		XCTAssertEqual("2", divs.get(0).id()) // 2 is child of 1
		XCTAssertEqual("3", divs.get(1).id()) // 3 is child of 2

		let div2: Elements = try doc.select("div#1 > div")
		XCTAssertEqual(1, div2.size())
		XCTAssertEqual("2", div2.get(0).id())
	}

	func testParentWithClassChild()throws {
		let h: String = "<h1 class=foo><a href=1 /></h1><h1 class=foo><a href=2 class=bar /></h1><h1><a href=3 /></h1>"
		let doc: Document = try SwiftSoup.parse(h)

		let allAs: Elements = try doc.select("h1 > a")
		XCTAssertEqual(3, allAs.size())
		XCTAssertEqual("a", allAs.first()?.tagName())

		let fooAs: Elements = try doc.select("h1.foo > a")
		XCTAssertEqual(2, fooAs.size())
		XCTAssertEqual("a", fooAs.first()?.tagName())

		let barAs: Elements = try doc.select("h1.foo > a.bar")
		XCTAssertEqual(1, barAs.size())
	}

	func testParentChildStar()throws {
		let h: String = "<div id=1><p>Hello<p><b>there</b></p></div><div id=2><span>Hi</span></div>"
		let doc: Document = try SwiftSoup.parse(h)
		let divChilds: Elements = try doc.select("div > *")
		XCTAssertEqual(3, divChilds.size())
		XCTAssertEqual("p", divChilds.get(0).tagName())
		XCTAssertEqual("p", divChilds.get(1).tagName())
		XCTAssertEqual("span", divChilds.get(2).tagName())
	}

	func testMultiChildDescent()throws {
		let h: String = "<div id=foo><h1 class=bar><a href=http://example.com/>One</a></h1></div>"
		let doc: Document = try SwiftSoup.parse(h)
		let els: Elements = try doc.select("div#foo > h1.bar > a[href*=example]")
		XCTAssertEqual(1, els.size())
		XCTAssertEqual("a", els.first()?.tagName())
	}

	func testCaseInsensitive()throws {
		let h: String = "<dIv tItle=bAr><div>" // mixed case so a simple toLowerCase() on value doesn't catch
		let doc: Document = try SwiftSoup.parse(h)

		XCTAssertEqual(2, try doc.select("DIV").size())
		XCTAssertEqual(1, try doc.select("DIV[TITLE]").size())
		XCTAssertEqual(1, try doc.select("DIV[TITLE=BAR]").size())
		XCTAssertEqual(0, try doc.select("DIV[TITLE=BARBARELLA").size())
	}

	func testAdjacentSiblings()throws {
		let h: String = "<ol><li>One<li>Two<li>Three</ol>"
		let doc: Document = try SwiftSoup.parse(h)
		let sibs: Elements = try doc.select("li + li")
		XCTAssertEqual(2, sibs.size())
		try XCTAssertEqual("Two", sibs.get(0).text())
		try XCTAssertEqual("Three", sibs.get(1).text())
	}

	func testAdjacentSiblingsWithId()throws {
		let h: String = "<ol><li id=1>One<li id=2>Two<li id=3>Three</ol>"
		let doc: Document = try SwiftSoup.parse(h)
		let sibs: Elements = try doc.select("li#1 + li#2")
		XCTAssertEqual(1, sibs.size())
		try XCTAssertEqual("Two", sibs.get(0).text())
	}

	func testNotAdjacent()throws {
		let h: String = "<ol><li id=1>One<li id=2>Two<li id=3>Three</ol>"
		let doc: Document = try SwiftSoup.parse(h)
		let sibs: Elements = try doc.select("li#1 + li#3")
		XCTAssertEqual(0, sibs.size())
	}

	func testMixCombinator()throws {
		let h: String = "<div class=foo><ol><li>One<li>Two<li>Three</ol></div>"
		let doc: Document = try SwiftSoup.parse(h)
		let sibs: Elements = try doc.select("body > div.foo li + li")

		XCTAssertEqual(2, sibs.size())
		try XCTAssertEqual("Two", sibs.get(0).text())
		try XCTAssertEqual("Three", sibs.get(1).text())
	}

	func testMixCombinatorGroup()throws {
		let h: String = "<div class=foo><ol><li>One<li>Two<li>Three</ol></div>"
		let doc: Document = try SwiftSoup.parse(h)
		let els: Elements = try doc.select(".foo > ol, ol > li + li")

		XCTAssertEqual(3, els.size())
		XCTAssertEqual("ol", els.get(0).tagName())
		try XCTAssertEqual("Two", els.get(1).text())
		try XCTAssertEqual("Three", els.get(2).text())
	}

	func testGeneralSiblings()throws {
		let h: String = "<ol><li id=1>One<li id=2>Two<li id=3>Three</ol>"
		let doc: Document = try SwiftSoup.parse(h)
		let els: Elements = try doc.select("#1 ~ #3")
		XCTAssertEqual(1, els.size())
		try XCTAssertEqual("Three", els.first()?.text())
	}

	// for http://github.com/jhy/jsoup/issues#issue/10
	func testCharactersInIdAndClass()throws {
		// using CSS spec for identifiers (id and class): a-z0-9, -, _. NOT . (which is OK in html spec, but not css)
		let h: String = "<div><p id='a1-foo_bar'>One</p><p class='b2-qux_bif'>Two</p></div>"
		let doc: Document = try SwiftSoup.parse(h)

		let el1: Element = try doc.getElementById("a1-foo_bar")!
		try XCTAssertEqual("One", el1.text())
		let el2: Element = try doc.getElementsByClass("b2-qux_bif").first()!
		XCTAssertEqual("Two", try el2.text())

		let el3: Element = try doc.select("#a1-foo_bar").first()!
		XCTAssertEqual("One", try el3.text())
		let el4: Element = try doc.select(".b2-qux_bif").first()!
		XCTAssertEqual("Two", try el4.text())
	}

	// for http://github.com/jhy/jsoup/issues#issue/13
	func testSupportsLeadingCombinator()throws {
		var h: String = "<div><p><span>One</span><span>Two</span></p></div>"
		var doc: Document = try SwiftSoup.parse(h)

		let p: Element = try doc.select("div > p").first()!
		let spans: Elements = try p.select("> span")
		XCTAssertEqual(2, spans.size())
		try XCTAssertEqual("One", spans.first()?.text())

		// make sure doesn't get nested
		h = "<div id=1><div id=2><div id=3></div></div></div>"
		doc = try SwiftSoup.parse(h)
		let div: Element = try doc.select("div").select(" > div").first()!
		XCTAssertEqual("2", div.id())
	}

	func testPseudoLessThan()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One</p><p>Two</p><p>Three</>p></div><div><p>Four</p>")
		let ps: Elements = try doc.select("div p:lt(2)")
		XCTAssertEqual(3, ps.size())
		try XCTAssertEqual("One", ps.get(0).text())
		try XCTAssertEqual("Two", ps.get(1).text())
		try XCTAssertEqual("Four", ps.get(2).text())
	}

	func testPseudoGreaterThan()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One</p><p>Two</p><p>Three</p></div><div><p>Four</p>")
		let ps: Elements = try doc.select("div p:gt(0)")
		XCTAssertEqual(2, ps.size())
		try XCTAssertEqual("Two", ps.get(0).text())
		try XCTAssertEqual("Three", ps.get(1).text())
	}

	func testPseudoEquals()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One</p><p>Two</p><p>Three</>p></div><div><p>Four</p>")
		let ps: Elements = try doc.select("div p:eq(0)")
		XCTAssertEqual(2, ps.size())
		try XCTAssertEqual("One", ps.get(0).text())
		try XCTAssertEqual("Four", ps.get(1).text())

		let ps2: Elements = try doc.select("div:eq(0) p:eq(0)")
		XCTAssertEqual(1, ps2.size())
		try XCTAssertEqual("One", ps2.get(0).text())
		XCTAssertEqual("p", ps2.get(0).tagName())
	}

	func testPseudoBetween()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One</p><p>Two</p><p>Three</>p></div><div><p>Four</p>")
		let ps: Elements = try doc.select("div p:gt(0):lt(2)")
		XCTAssertEqual(1, ps.size())
		try XCTAssertEqual("Two", ps.get(0).text())
	}

	func testPseudoCombined()throws {
		let doc: Document = try SwiftSoup.parse("<div class='foo'><p>One</p><p>Two</p></div><div><p>Three</p><p>Four</p></div>")
		let ps: Elements = try doc.select("div.foo p:gt(0)")
		XCTAssertEqual(1, ps.size())
		try XCTAssertEqual("Two", ps.get(0).text())
	}

	func testPseudoHas()throws {
		let doc: Document = try SwiftSoup.parse("<div id=0><p><span>Hello</span></p></div> <div id=1><span class=foo>There</span></div> <div id=2><p>Not</p></div>")

		let divs1: Elements = try doc.select("div:has(span)")
		XCTAssertEqual(2, divs1.size())
		XCTAssertEqual("0", divs1.get(0).id())
		XCTAssertEqual("1", divs1.get(1).id())

		let divs2: Elements = try doc.select("div:has([class]")
		XCTAssertEqual(1, divs2.size())
		XCTAssertEqual("1", divs2.get(0).id())

		let divs3: Elements = try doc.select("div:has(span, p)")
		XCTAssertEqual(3, divs3.size())
		XCTAssertEqual("0", divs3.get(0).id())
		XCTAssertEqual("1", divs3.get(1).id())
		XCTAssertEqual("2", divs3.get(2).id())

		let els1: Elements = try doc.body()!.select(":has(p)")
		XCTAssertEqual(3, els1.size()) // body, div, dib
		XCTAssertEqual("body", els1.first()?.tagName())
		XCTAssertEqual("0", els1.get(1).id())
		XCTAssertEqual("2", els1.get(2).id())
	}

	func testNestedHas()throws {
		let doc: Document = try SwiftSoup.parse("<div><p><span>One</span></p></div> <div><p>Two</p></div>")
		var divs: Elements = try doc.select("div:has(p:has(span))")
		XCTAssertEqual(1, divs.size())
		try XCTAssertEqual("One", divs.first()?.text())

		// test matches in has
		divs = try doc.select("div:has(p:matches((?i)two))")
		XCTAssertEqual(1, divs.size())
		XCTAssertEqual("div", divs.first()?.tagName())
		try XCTAssertEqual("Two", divs.first()?.text())

		// test contains in has
		divs = try doc.select("div:has(p:contains(two))")
		XCTAssertEqual(1, divs.size())
		XCTAssertEqual("div", divs.first()?.tagName())
		try XCTAssertEqual("Two", divs.first()?.text())
	}

	func testPseudoContains()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>The Rain.</p> <p class=light>The <i>rain</i>.</p> <p>Rain, the.</p></div>")

		let ps1: Elements = try doc.select("p:contains(Rain)")
		XCTAssertEqual(3, ps1.size())

		let ps2: Elements = try doc.select("p:contains(the rain)")
		XCTAssertEqual(2, ps2.size())
		try XCTAssertEqual("The Rain.", ps2.first()?.html())
		try XCTAssertEqual("The <i>rain</i>.", ps2.last()?.html())

		let ps3: Elements = try doc.select("p:contains(the Rain):has(i)")
		XCTAssertEqual(1, ps3.size())
		try XCTAssertEqual("light", ps3.first()?.className())

		let ps4: Elements = try doc.select(".light:contains(rain)")
		XCTAssertEqual(1, ps4.size())
		try XCTAssertEqual("light", ps3.first()?.className())

		let ps5: Elements = try doc.select(":contains(rain)")
		XCTAssertEqual(8, ps5.size()) // html, body, div,...
	}

	func testPsuedoContainsWithParentheses()throws {
		let doc: Document = try SwiftSoup.parse("<div><p id=1>This (is good)</p><p id=2>This is bad)</p>")

		let ps1: Elements = try doc.select("p:contains(this (is good))")
		XCTAssertEqual(1, ps1.size())
		XCTAssertEqual("1", ps1.first()?.id())

		let ps2: Elements = try doc.select("p:contains(this is bad\\))")
		XCTAssertEqual(1, ps2.size())
		XCTAssertEqual("2", ps2.first()?.id())
	}

	func testContainsOwn()throws {
		let doc: Document = try SwiftSoup.parse("<p id=1>Hello <b>there</b> now</p>")
		let ps: Elements = try doc.select("p:containsOwn(Hello now)")
		XCTAssertEqual(1, ps.size())
		XCTAssertEqual("1", ps.first()?.id())

		XCTAssertEqual(0, try doc.select("p:containsOwn(there)").size())
	}

	func testMatches()throws {
		let doc: Document = try SwiftSoup.parse("<p id=1>The <i>Rain</i></p> <p id=2>There are 99 bottles.</p> <p id=3>Harder (this)</p> <p id=4>Rain</p>")

		let p1: Elements = try doc.select("p:matches(The rain)") // no match, case sensitive
		XCTAssertEqual(0, p1.size())

		let p2: Elements = try doc.select("p:matches((?i)the rain)") // case insense. should include root, html, body
		XCTAssertEqual(1, p2.size())
		XCTAssertEqual("1", p2.first()?.id())

		let p4: Elements = try doc.select("p:matches((?i)^rain$)") // bounding
		XCTAssertEqual(1, p4.size())
		XCTAssertEqual("4", p4.first()?.id())

		let p5: Elements = try doc.select("p:matches(\\d+)")
		XCTAssertEqual(1, p5.size())
		XCTAssertEqual("2", p5.first()?.id())

		let p6: Elements = try doc.select("p:matches(\\w+\\s+\\(\\w+\\))") // test bracket matching
		XCTAssertEqual(1, p6.size())
		XCTAssertEqual("3", p6.first()?.id())

		let p7: Elements = try doc.select("p:matches((?i)the):has(i)") // multi
		XCTAssertEqual(1, p7.size())
		XCTAssertEqual("1", p7.first()?.id())
	}

	func testMatchesOwn()throws {
		let doc: Document = try SwiftSoup.parse("<p id=1>Hello <b>there</b> now</p>")

		let p1: Elements = try doc.select("p:matchesOwn((?i)hello now)")
		XCTAssertEqual(1, p1.size())
		XCTAssertEqual("1", p1.first()?.id())

		XCTAssertEqual(0, try doc.select("p:matchesOwn(there)").size())
	}

	func testRelaxedTags()throws {
		let doc: Document = try SwiftSoup.parse("<abc_def id=1>Hello</abc_def> <abc-def id=2>There</abc-def>")

		let el1: Elements = try doc.select("abc_def")
		XCTAssertEqual(1, el1.size())
		XCTAssertEqual("1", el1.first()?.id())

		let el2: Elements = try doc.select("abc-def")
		XCTAssertEqual(1, el2.size())
		XCTAssertEqual("2", el2.first()?.id())
	}

	func testNotParas()throws {
		let doc: Document = try SwiftSoup.parse("<p id=1>One</p> <p>Two</p> <p><span>Three</span></p>")

		let el1: Elements = try doc.select("p:not([id=1])")
		XCTAssertEqual(2, el1.size())
		try XCTAssertEqual("Two", el1.first()?.text())
		try XCTAssertEqual("Three", el1.last()?.text())

		let el2: Elements = try doc.select("p:not(:has(span))")
		XCTAssertEqual(2, el2.size())
		try XCTAssertEqual("One", el2.first()?.text())
		try XCTAssertEqual("Two", el2.last()?.text())
	}

	func testNotAll()throws {
		let doc: Document = try SwiftSoup.parse("<p>Two</p> <p><span>Three</span></p>")

		let el1: Elements = try doc.body()!.select(":not(p)") // should just be the span
		XCTAssertEqual(2, el1.size())
		XCTAssertEqual("body", el1.first()?.tagName())
		XCTAssertEqual("span", el1.last()?.tagName())
	}

	func testNotClass()throws {
		let doc: Document = try SwiftSoup.parse("<div class=left>One</div><div class=right id=1><p>Two</p></div>")

		let el1: Elements = try doc.select("div:not(.left)")
		XCTAssertEqual(1, el1.size())
		XCTAssertEqual("1", el1.first()?.id())
	}

	func testHandlesCommasInSelector()throws {
		let doc: Document = try SwiftSoup.parse("<p name='1,2'>One</p><div>Two</div><ol><li>123</li><li>Text</li></ol>")

		let ps: Elements = try doc.select("[name=1,2]")
		XCTAssertEqual(1, ps.size())

		let containers: Elements = try doc.select("div, li:matches([0-9,]+)")
		XCTAssertEqual(2, containers.size())
		XCTAssertEqual("div", containers.get(0).tagName())
		XCTAssertEqual("li", containers.get(1).tagName())
		try XCTAssertEqual("123", containers.get(1).text())
	}

	func testSelectSupplementaryCharacter()throws {
		#if !os(Linux)
			let s = String(Character(UnicodeScalar(135361)!))
			let doc: Document = try SwiftSoup.parse("<div k" + s + "='" + s + "'>^" + s + "$/div>")
			XCTAssertEqual("div", try doc.select("div[k" + s + "]").first()?.tagName())
			XCTAssertEqual("div", try doc.select("div:containsOwn(" + s + ")").first()?.tagName())
		#endif
	}

	func testSelectClassWithSpace()throws {
		 let html: String = "<div class=\"value\">class without space</div>\n"
			+ "<div class=\"value \">class with space</div>"

		let doc: Document = try SwiftSoup.parse(html)

		var found: Elements = try doc.select("div[class=value ]")
		XCTAssertEqual(2, found.size())
		try XCTAssertEqual("class without space", found.get(0).text())
		try XCTAssertEqual("class with space", found.get(1).text())

		found = try doc.select("div[class=\"value \"]")
		XCTAssertEqual(2, found.size())
		try XCTAssertEqual("class without space", found.get(0).text())
		try XCTAssertEqual("class with space", found.get(1).text())

		found = try doc.select("div[class=\"value\\ \"]")
		XCTAssertEqual(0, found.size())
	}

	func testSelectSameElements()throws {
		let html: String = "<div>one</div><div>one</div>"

		let doc: Document = try SwiftSoup.parse(html)
		let els: Elements = try doc.select("div")
		XCTAssertEqual(2, els.size())

		let subSelect: Elements = try els.select(":contains(one)")
		XCTAssertEqual(2, subSelect.size())
	}

	func testAttributeWithBrackets()throws {
		let html: String = "<div data='End]'>One</div> <div data='[Another)]]'>Two</div>"
		let doc: Document = try SwiftSoup.parse(html)
		try _ = doc.select("div[data='End]'")
		XCTAssertEqual("One", try doc.select("div[data='End]'").first()?.text())
		XCTAssertEqual("Two", try doc.select("div[data='[Another)]]'").first()?.text())
		XCTAssertEqual("One", try doc.select("div[data=\"End]\"").first()?.text())
		XCTAssertEqual("Two", try doc.select("div[data=\"[Another)]]\"").first()?.text())
	}

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testByTag", testByTag),
			("testById", testById),
			("testByClass", testByClass),
			("testByAttribute", testByAttribute),
			("testNamespacedTag", testNamespacedTag),
			("testWildcardNamespacedTag", testWildcardNamespacedTag),
			("testByAttributeStarting", testByAttributeStarting),
			("testByAttributeRegex", testByAttributeRegex),
			("testByAttributeRegexCharacterClass", testByAttributeRegexCharacterClass),
			("testByAttributeRegexCombined", testByAttributeRegexCombined),
			("testCombinedWithContains", testCombinedWithContains),
			("testAllElements", testAllElements),
			("testAllWithClass", testAllWithClass),
			("testGroupOr", testGroupOr),
			("testGroupOrAttribute", testGroupOrAttribute),
			("testDescendant", testDescendant),
			("testAnd", testAnd),
			("testDeeperDescendant", testDeeperDescendant),
			("testParentChildElement", testParentChildElement),
			("testParentWithClassChild", testParentWithClassChild),
			("testParentChildStar", testParentChildStar),
			("testMultiChildDescent", testMultiChildDescent),
			("testCaseInsensitive", testCaseInsensitive),
			("testAdjacentSiblings", testAdjacentSiblings),
			("testAdjacentSiblingsWithId", testAdjacentSiblingsWithId),
			("testNotAdjacent", testNotAdjacent),
			("testMixCombinator", testMixCombinator),
			("testMixCombinatorGroup", testMixCombinatorGroup),
			("testGeneralSiblings", testGeneralSiblings),
			("testCharactersInIdAndClass", testCharactersInIdAndClass),
			("testSupportsLeadingCombinator", testSupportsLeadingCombinator),
			("testPseudoLessThan", testPseudoLessThan),
			("testPseudoGreaterThan", testPseudoGreaterThan),
			("testPseudoEquals", testPseudoEquals),
			("testPseudoBetween", testPseudoBetween),
			("testPseudoCombined", testPseudoCombined),
			("testPseudoHas", testPseudoHas),
			("testNestedHas", testNestedHas),
			("testPseudoContains", testPseudoContains),
			("testPsuedoContainsWithParentheses", testPsuedoContainsWithParentheses),
			("testContainsOwn", testContainsOwn),
			("testMatches", testMatches),
			("testMatchesOwn", testMatchesOwn),
			("testRelaxedTags", testRelaxedTags),
			("testNotParas", testNotParas),
			("testNotAll", testNotAll),
			("testNotClass", testNotClass),
			("testHandlesCommasInSelector", testHandlesCommasInSelector),
			("testSelectSupplementaryCharacter", testSelectSupplementaryCharacter),
			("testSelectClassWithSpace", testSelectClassWithSpace),
			("testSelectSameElements", testSelectSameElements),
			("testAttributeWithBrackets", testAttributeWithBrackets)
		]
	}()

}
