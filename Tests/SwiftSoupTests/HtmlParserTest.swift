//
//  HtmlParserTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 10/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//
/**
Tests for the Parser
*/

import XCTest
import SwiftSoup

class HtmlParserTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

	func testParsesSimpleDocument()throws {
		let html: String = "<html><head><title>First!</title></head><body><p>First post! <img src=\"foo.png\" /></p></body></html>"
		let doc: Document = try SwiftSoup.parse(html)
		// need a better way to verify these:
		let p: Element = doc.body()!.child(0)
		XCTAssertEqual("p", p.tagName())
		let img: Element = p.child(0)
		XCTAssertEqual("foo.png", try img.attr("src"))
		XCTAssertEqual("img", img.tagName())
	}

	func testParsesRoughAttributes()throws {
		let html: String = "<html><head><title>First!</title></head><body><p class=\"foo > bar\">First post! <img src=\"foo.png\" /></p></body></html>"
		let doc: Document = try SwiftSoup.parse(html)

		// need a better way to verify these:
		let p: Element = doc.body()!.child(0)
		XCTAssertEqual("p", p.tagName())
		XCTAssertEqual("foo > bar", try p.attr("class"))
	}

	func testParsesQuiteRoughAttributes()throws {
		let html: String = "<p =a>One<a <p>Something</p>Else"
		// this gets a <p> with attr '=a' and an <a tag with an attribue named '<p'; and then auto-recreated
		var doc: Document = try SwiftSoup.parse(html)
		XCTAssertEqual("<p =a>One<a <p>Something</a></p>\n" +
			"<a <p>Else</a>", try doc.body()!.html())

		doc = try SwiftSoup.parse("<p .....>")
		XCTAssertEqual("<p .....></p>", try doc.body()!.html())
	}

	func testParsesComments()throws {
		let html = "<html><head></head><body><img src=foo><!-- <table><tr><td></table> --><p>Hello</p></body></html>"
		let doc = try SwiftSoup.parse(html)

		let body: Element = doc.body()!
		let comment: Comment =  body.childNode(1)as! Comment // comment should not be sub of img, as it's an empty tag
		XCTAssertEqual(" <table><tr><td></table> ", comment.getData())
		let p: Element = body.child(1)
		let text: TextNode = p.childNode(0)as! TextNode
		XCTAssertEqual("Hello", text.getWholeText())
	}

	func testParsesUnterminatedComments()throws {
		let html = "<p>Hello<!-- <tr><td>"
		let doc: Document = try SwiftSoup.parse(html)
		let p: Element = try doc.getElementsByTag("p").get(0)
		XCTAssertEqual("Hello", try p.text())
		let text: TextNode = p.childNode(0) as! TextNode
		XCTAssertEqual("Hello", text.getWholeText())
		let comment: Comment = p.childNode(1)as! Comment
		XCTAssertEqual(" <tr><td>", comment.getData())
	}

	func testDropsUnterminatedTag()throws {
		// swiftsoup used to parse this to <p>, but whatwg, webkit will drop.
		let h1: String = "<p"
		var doc: Document = try SwiftSoup.parse(h1)
		XCTAssertEqual(0, try doc.getElementsByTag("p").size())
		XCTAssertEqual("", try doc.text())

		let h2: String = "<div id=1<p id='2'"
		doc = try SwiftSoup.parse(h2)
		XCTAssertEqual("", try doc.text())
	}

	func testDropsUnterminatedAttribute()throws {
		// swiftsoup used to parse this to <p id="foo">, but whatwg, webkit will drop.
		let h1: String = "<p id=\"foo"
		let doc: Document = try SwiftSoup.parse(h1)
		XCTAssertEqual("", try doc.text())
	}

	func testParsesUnterminatedTextarea()throws {
		// don't parse right to end, but break on <p>
		let doc: Document = try SwiftSoup.parse("<body><p><textarea>one<p>two")
		let t: Element = try doc.select("textarea").first()!
		XCTAssertEqual("one", try t.text())
		XCTAssertEqual("two", try doc.select("p").get(1).text())
	}

	func testParsesUnterminatedOption()throws {
		// bit weird this -- browsers and spec get stuck in select until there's a </select>
		let doc: Document = try SwiftSoup.parse("<body><p><select><option>One<option>Two</p><p>Three</p>")
		let options: Elements = try doc.select("option")
		XCTAssertEqual(2, options.size())
		XCTAssertEqual("One", try options.first()!.text())
		XCTAssertEqual("TwoThree", try options.last()!.text())
	}

	func testSpaceAfterTag()throws {
		let doc: Document = try SwiftSoup.parse("<div > <a name=\"top\"></a ><p id=1 >Hello</p></div>")
		XCTAssertEqual("<div> <a name=\"top\"></a><p id=\"1\">Hello</p></div>", TextUtil.stripNewlines(try doc.body()!.html()))
	}

	func testCreatesDocumentStructure()throws {
		let html = "<meta name=keywords /><link rel=stylesheet /><title>jsoup</title><p>Hello world</p>"
		let doc = try SwiftSoup.parse(html)
		let head: Element = doc.head()!
		let body: Element = doc.body()!

		XCTAssertEqual(1, doc.children().size()) // root node: contains html node
		XCTAssertEqual(2, doc.child(0).children().size()) // html node: head and body
		XCTAssertEqual(3, head.children().size())
		XCTAssertEqual(1, body.children().size())

		XCTAssertEqual("keywords", try head.getElementsByTag("meta").get(0).attr("name"))
		XCTAssertEqual(0, try body.getElementsByTag("meta").size())
		XCTAssertEqual("jsoup", try  doc.title())
		XCTAssertEqual("Hello world", try body.text())
		XCTAssertEqual("Hello world", try body.children().get(0).text())
	}

	func testCreatesStructureFromBodySnippet()throws {
		// the bar baz stuff naturally goes into the body, but the 'foo' goes into root, and the normalisation routine
		// needs to move into the start of the body
		let html = "foo <b>bar</b> baz"
		let doc = try SwiftSoup.parse(html)
		XCTAssertEqual("foo bar baz", try doc.text())

	}

	func testHandlesEscapedData()throws {
		let html = "<div title='Surf &amp; Turf'>Reef &amp; Beef</div>"
		let doc = try SwiftSoup.parse(html)
		let div: Element = try doc.getElementsByTag("div").get(0)

		XCTAssertEqual("Surf & Turf", try div.attr("title"))
		XCTAssertEqual("Reef & Beef", try div.text())
	}

	func testHandlesDataOnlyTags()throws {
		let t: String = "<style>font-family: bold</style>"
		let tels: Elements = try SwiftSoup.parse(t).getElementsByTag("style")
		XCTAssertEqual("font-family: bold", tels.get(0).data())
		XCTAssertEqual("", try tels.get(0).text())

		let s: String = "<p>Hello</p><script>obj.insert('<a rel=\"none\" />');\ni++;</script><p>There</p>"
		let doc: Document = try SwiftSoup.parse(s)
		XCTAssertEqual("Hello There", try doc.text())
		XCTAssertEqual("obj.insert('<a rel=\"none\" />');\ni++;", doc.data())
	}

	func testHandlesTextAfterData()throws {
		let h: String = "<html><body>pre <script>inner</script> aft</body></html>"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("<html><head></head><body>pre <script>inner</script> aft</body></html>", try TextUtil.stripNewlines(doc.html()))
	}

	func testHandlesTextArea()throws {
		let doc: Document = try SwiftSoup.parse("<textarea>Hello</textarea>")
		let els: Elements = try doc.select("textarea")
		XCTAssertEqual("Hello", try els.text())
		XCTAssertEqual("Hello", try els.val())
	}

	func testPreservesSpaceInTextArea()throws {
		// preserve because the tag is marked as preserve white space
		let doc: Document = try SwiftSoup.parse("<textarea>\n\tOne\n\tTwo\n\tThree\n</textarea>")
		let expect: String = "One\n\tTwo\n\tThree" // the leading and trailing spaces are dropped as a convenience to authors
		let el: Element = try doc.select("textarea").first()!
		XCTAssertEqual(expect, try el.text())
		XCTAssertEqual(expect, try el.val())
		XCTAssertEqual(expect, try el.html())
		XCTAssertEqual("<textarea>\n\t" + expect + "\n</textarea>", try el.outerHtml()) // but preserved in round-trip html
	}

	func testPreservesSpaceInScript()throws {
		// preserve because it's content is a data node
		let doc: Document = try SwiftSoup.parse("<script>\nOne\n\tTwo\n\tThree\n</script>")
		let expect = "\nOne\n\tTwo\n\tThree\n"
		let el: Element = try doc.select("script").first()!
		XCTAssertEqual(expect, el.data())
		XCTAssertEqual("One\n\tTwo\n\tThree", try el.html())
		XCTAssertEqual("<script>" + expect + "</script>", try el.outerHtml())
	}

	func testDoesNotCreateImplicitLists()throws {
		// old jsoup used to wrap this in <ul>, but that's not to spec
		let h: String = "<li>Point one<li>Point two"
		let doc: Document = try SwiftSoup.parse(h)
		let ol: Elements = try doc.select("ul") // should NOT have created a default ul.
		XCTAssertEqual(0, ol.size())
		let lis: Elements = try doc.select("li")
		XCTAssertEqual(2, lis.size())
		XCTAssertEqual("body", lis.first()!.parent()!.tagName())

		// no fiddling with non-implicit lists
		let h2: String = "<ol><li><p>Point the first<li><p>Point the second"
		let doc2: Document = try SwiftSoup.parse(h2)

		XCTAssertEqual(0, try doc2.select("ul").size())
		XCTAssertEqual(1, try doc2.select("ol").size())
		XCTAssertEqual(2, try doc2.select("ol li").size())
		XCTAssertEqual(2, try doc2.select("ol li p").size())
		XCTAssertEqual(1, try doc2.select("ol li").get(0).children().size()) // one p in first li
	}

	func testDiscardsNakedTds()throws {
		// jsoup used to make this into an implicit table; but browsers make it into a text run
		let h: String = "<td>Hello<td><p>There<p>now"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("Hello<p>There</p><p>now</p>", try TextUtil.stripNewlines(doc.body()!.html()))
		// <tbody> is introduced if no implicitly creating table, but allows tr to be directly under table
	}

	func testHandlesNestedImplicitTable()throws {
		let doc: Document = try SwiftSoup.parse("<table><td>1</td></tr> <td>2</td></tr> <td> <table><td>3</td> <td>4</td></table> <tr><td>5</table>")
		XCTAssertEqual("<table><tbody><tr><td>1</td></tr> <tr><td>2</td></tr> <tr><td> <table><tbody><tr><td>3</td> <td>4</td></tr></tbody></table> </td></tr><tr><td>5</td></tr></tbody></table>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesWhatWgExpensesTableExample()throws {
		// http://www.whatwg.org/specs/web-apps/current-work/multipage/tabular-data.html#examples-0
		let doc = try SwiftSoup.parse("<table> <colgroup> <col> <colgroup> <col> <col> <col> <thead> <tr> <th> <th>2008 <th>2007 <th>2006 <tbody> <tr> <th scope=rowgroup> Research and development <td> $ 1,109 <td> $ 782 <td> $ 712 <tr> <th scope=row> Percentage of net sales <td> 3.4% <td> 3.3% <td> 3.7% <tbody> <tr> <th scope=rowgroup> Selling, general, and administrative <td> $ 3,761 <td> $ 2,963 <td> $ 2,433 <tr> <th scope=row> Percentage of net sales <td> 11.6% <td> 12.3% <td> 12.6% </table>")
		XCTAssertEqual("<table> <colgroup> <col> </colgroup><colgroup> <col> <col> <col> </colgroup><thead> <tr> <th> </th><th>2008 </th><th>2007 </th><th>2006 </th></tr></thead><tbody> <tr> <th scope=\"rowgroup\"> Research and development </th><td> $ 1,109 </td><td> $ 782 </td><td> $ 712 </td></tr><tr> <th scope=\"row\"> Percentage of net sales </th><td> 3.4% </td><td> 3.3% </td><td> 3.7% </td></tr></tbody><tbody> <tr> <th scope=\"rowgroup\"> Selling, general, and administrative </th><td> $ 3,761 </td><td> $ 2,963 </td><td> $ 2,433 </td></tr><tr> <th scope=\"row\"> Percentage of net sales </th><td> 11.6% </td><td> 12.3% </td><td> 12.6% </td></tr></tbody></table>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesTbodyTable()throws {
		let doc: Document = try SwiftSoup.parse("<html><head></head><body><table><tbody><tr><td>aaa</td><td>bbb</td></tr></tbody></table></body></html>")
		XCTAssertEqual("<table><tbody><tr><td>aaa</td><td>bbb</td></tr></tbody></table>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesImplicitCaptionClose()throws {
		let doc = try SwiftSoup.parse("<table><caption>A caption<td>One<td>Two")
		XCTAssertEqual("<table><caption>A caption</caption><tbody><tr><td>One</td><td>Two</td></tr></tbody></table>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testNoTableDirectInTable()throws {
		let doc: Document = try SwiftSoup.parse("<table> <td>One <td><table><td>Two</table> <table><td>Three")
		XCTAssertEqual("<table> <tbody><tr><td>One </td><td><table><tbody><tr><td>Two</td></tr></tbody></table> <table><tbody><tr><td>Three</td></tr></tbody></table></td></tr></tbody></table>",
		               try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testIgnoresDupeEndTrTag()throws {
		let doc: Document = try SwiftSoup.parse("<table><tr><td>One</td><td><table><tr><td>Two</td></tr></tr></table></td><td>Three</td></tr></table>") // two </tr></tr>, must ignore or will close table
		XCTAssertEqual("<table><tbody><tr><td>One</td><td><table><tbody><tr><td>Two</td></tr></tbody></table></td><td>Three</td></tr></tbody></table>",
		               try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesBaseTags()throws {
		// only listen to the first base href
		let h = "<a href=1>#</a><base href='/2/'><a href='3'>#</a><base href='http://bar'><a href=/4>#</a>"
		let doc = try SwiftSoup.parse(h, "http://foo/")
		XCTAssertEqual("http://foo/2/", doc.getBaseUri()) // gets set once, so doc and descendants have first only

		let anchors: Elements = try doc.getElementsByTag("a")
		XCTAssertEqual(3, anchors.size())

		XCTAssertEqual("http://foo/2/", anchors.get(0).getBaseUri())
		XCTAssertEqual("http://foo/2/", anchors.get(1).getBaseUri())
		XCTAssertEqual("http://foo/2/", anchors.get(2).getBaseUri())

		XCTAssertEqual("http://foo/2/1", try anchors.get(0).absUrl("href"))
		XCTAssertEqual("http://foo/2/3", try anchors.get(1).absUrl("href"))
		XCTAssertEqual("http://foo/4", try anchors.get(2).absUrl("href"))
	}

	func testHandlesProtocolRelativeUrl()throws {
		let base = "https://example.com/"
		let html = "<img src='//example.net/img.jpg'>"
		let doc = try SwiftSoup.parse(html, base)
		let el: Element = try doc.select("img").first()!
		XCTAssertEqual("https://example.net/img.jpg", try el.absUrl("src"))
	}

	func testHandlesCdata()throws {
		// todo: as this is html namespace, should actually treat as bogus comment, not cdata. keep as cdata for now
		let h = "<div id=1><![CDATA[<html>\n<foo><&amp;]]></div>" // the &amp; in there should remain literal
		let doc: Document = try SwiftSoup.parse(h)
		let div: Element = try doc.getElementById("1")!
		XCTAssertEqual("<html> <foo><&amp;", try div.text())
		XCTAssertEqual(0, div.children().size())
		XCTAssertEqual(1, div.childNodeSize()) // no elements, one text node
	}

	func testHandlesUnclosedCdataAtEOF()throws {
		// https://github.com/jhy/jsoup/issues/349 would crash, as character reader would try to seek past EOF
		let h = "<![CDATA[]]"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual(1, doc.body()!.childNodeSize())
	}

	func testHandlesInvalidStartTags()throws {
		let h: String = "<div>Hello < There <&amp;></div>" // parse to <div {#text=Hello < There <&>}>
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("Hello < There <&>", try doc.select("div").first()!.text())
	}

	func testHandlesUnknownTags()throws {
		let h = "<div><foo title=bar>Hello<foo title=qux>there</foo></div>"
		let doc = try SwiftSoup.parse(h)
		let foos: Elements = try doc.select("foo")
		XCTAssertEqual(2, foos.size())
		XCTAssertEqual("bar", try foos.first()!.attr("title"))
		XCTAssertEqual("qux", try foos.last()!.attr("title"))
		XCTAssertEqual("there", try foos.last()!.text())
	}

	func testHandlesUnknownInlineTags()throws {
		let h = "<p><cust>Test</cust></p><p><cust><cust>Test</cust></cust></p>"
		let doc: Document = try SwiftSoup.parseBodyFragment(h)
		let out: String = try doc.body()!.html()
		XCTAssertEqual(h, TextUtil.stripNewlines(out))
	}

	func testParsesBodyFragment()throws {
		let h = "<!-- comment --><p><a href='foo'>One</a></p>"
		let doc: Document = try SwiftSoup.parseBodyFragment(h, "http://example.com")
		XCTAssertEqual("<body><!-- comment --><p><a href=\"foo\">One</a></p></body>", try TextUtil.stripNewlines(doc.body()!.outerHtml()))
		XCTAssertEqual("http://example.com/foo", try doc.select("a").first()!.absUrl("href"))
	}

	func testHandlesUnknownNamespaceTags()throws {
		// note that the first foo:bar should not really be allowed to be self closing, if parsed in html mode.
		let h = "<foo:bar id='1' /><abc:def id=2>Foo<p>Hello</p></abc:def><foo:bar>There</foo:bar>"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("<foo:bar id=\"1\" /><abc:def id=\"2\">Foo<p>Hello</p></abc:def><foo:bar>There</foo:bar>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesKnownEmptyBlocks()throws {
		// if a known tag, allow self closing outside of spec, but force an end tag. unknown tags can be self closing.
		let h = "<div id='1' /><script src='/foo' /><div id=2><img /><img></div><a id=3 /><i /><foo /><foo>One</foo> <hr /> hr text <hr> hr text two"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<div id=\"1\"></div><script src=\"/foo\"></script><div id=\"2\"><img><img></div><a id=\"3\"></a><i></i><foo /><foo>One</foo> <hr> hr text <hr> hr text two", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesSolidusAtAttributeEnd()throws {
		// this test makes sure [<a href=/>link</a>] is parsed as [<a href="/">link</a>], not [<a href="" /><a>link</a>]
		let h = "<a href=/>link</a>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<a href=\"/\">link</a>", try doc.body()!.html())
	}

	func testHandlesMultiClosingBody()throws {
		let h = "<body><p>Hello</body><p>there</p></body></body></html><p>now"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual(3, try doc.select("p").size())
		XCTAssertEqual(3, doc.body()!.children().size())
	}

	func testHandlesUnclosedDefinitionLists()throws {
		// jsoup used to create a <dl>, but that's not to spec
		let h: String = "<dt>Foo<dd>Bar<dt>Qux<dd>Zug"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual(0, try doc.select("dl").size()) // no auto dl
		XCTAssertEqual(4, try doc.select("dt, dd").size())
		let dts: Elements = try doc.select("dt")
		XCTAssertEqual(2, dts.size())
		XCTAssertEqual("Zug", try  dts.get(1).nextElementSibling()?.text())
	}

	func testHandlesBlocksInDefinitions()throws {
		// per the spec, dt and dd are inline, but in practise are block
		let h = "<dl><dt><div id=1>Term</div></dt><dd><div id=2>Def</div></dd></dl>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("dt", try doc.select("#1").first()!.parent()!.tagName())
		XCTAssertEqual("dd", try doc.select("#2").first()!.parent()!.tagName())
		XCTAssertEqual("<dl><dt><div id=\"1\">Term</div></dt><dd><div id=\"2\">Def</div></dd></dl>", try  TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesFrames()throws {
		let h = "<html><head><script></script><noscript></noscript></head><frameset><frame src=foo></frame><frame src=foo></frameset></html>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<html><head><script></script><noscript></noscript></head><frameset><frame src=\"foo\"><frame src=\"foo\"></frameset></html>",
		               try TextUtil.stripNewlines(doc.html()))
		// no body auto vivification
	}

	func testIgnoresContentAfterFrameset()throws {
		let h = "<html><head><title>One</title></head><frameset><frame /><frame /></frameset><table></table></html>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<html><head><title>One</title></head><frameset><frame><frame></frameset></html>", try TextUtil.stripNewlines(doc.html()))
		// no body, no table. No crash!
	}

	func testHandlesJavadocFont()throws {
		let h = "<TD BGCOLOR=\"#EEEEFF\" CLASS=\"NavBarCell1\">    <A HREF=\"deprecated-list.html\"><FONT CLASS=\"NavBarFont1\"><B>Deprecated</B></FONT></A>&nbsp;</TD>"
		let doc = try SwiftSoup.parse(h)
		let a: Element = try doc.select("a").first()!
		XCTAssertEqual("Deprecated", try a.text())
		XCTAssertEqual("font", a.child(0).tagName())
		XCTAssertEqual("b", a.child(0).child(0).tagName())
	}

	func testHandlesBaseWithoutHref()throws {
		let h = "<head><base target='_blank'></head><body><a href=/foo>Test</a></body>"
		let doc = try SwiftSoup.parse(h, "http://example.com/")
		let a: Element = try doc.select("a").first()!
		XCTAssertEqual("/foo", try a.attr("href"))
		XCTAssertEqual("http://example.com/foo", try  a.attr("abs:href"))
	}

	func testNormalisesDocument()throws {
		let h = "<!doctype html>One<html>Two<head>Three<link></head>Four<body>Five </body>Six </html>Seven "
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<!doctype html><html><head></head><body>OneTwoThree<link>FourFive Six Seven </body></html>",
		               try TextUtil.stripNewlines(doc.html()))
	}

	func testNormalisesEmptyDocument()throws {
		let doc = try SwiftSoup.parse("")
		XCTAssertEqual("<html><head></head><body></body></html>", try TextUtil.stripNewlines(doc.html()))
	}

	func testNormalisesHeadlessBody()throws {
		let doc = try SwiftSoup.parse("<html><body><span class=\"foo\">bar</span>")
		XCTAssertEqual("<html><head></head><body><span class=\"foo\">bar</span></body></html>",
		               try TextUtil.stripNewlines(doc.html()))
	}

	func testNormalisedBodyAfterContent()throws {
		let doc = try SwiftSoup.parse("<font face=Arial><body class=name><div>One</div></body></font>")
		XCTAssertEqual("<html><head></head><body class=\"name\"><font face=\"Arial\"><div>One</div></font></body></html>",
		               try TextUtil.stripNewlines(doc.html()))
	}

	func testfindsCharsetInMalformedMeta()throws {
		let h = "<meta http-equiv=Content-Type content=text/html; charset=gb2312>"
		// example cited for reason of html5's <meta charset> element
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("gb2312", try doc.select("meta").attr("charset"))
	}

	func testHgroup()throws {
		// jsoup used to not allow hroup in h{n}, but that's not in spec, and browsers are OK
		let doc = try SwiftSoup.parse("<h1>Hello <h2>There <hgroup><h1>Another<h2>headline</hgroup> <hgroup><h1>More</h1><p>stuff</p></hgroup>")
		XCTAssertEqual("<h1>Hello </h1><h2>There <hgroup><h1>Another</h1><h2>headline</h2></hgroup> <hgroup><h1>More</h1><p>stuff</p></hgroup></h2>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testRelaxedTags()throws {
		let doc = try SwiftSoup.parse("<abc_def id=1>Hello</abc_def> <abc-def>There</abc-def>")
		XCTAssertEqual("<abc_def id=\"1\">Hello</abc_def> <abc-def>There</abc-def>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHeaderContents()throws {
		// h* tags (h1 .. h9) in browsers can handle any internal content other than other h*. which is not per any
		// spec, which defines them as containing phrasing content only. so, reality over theory.
		let doc = try SwiftSoup.parse("<h1>Hello <div>There</div> now</h1> <h2>More <h3>Content</h3></h2>")
		XCTAssertEqual("<h1>Hello <div>There</div> now</h1> <h2>More </h2><h3>Content</h3>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testSpanContents()throws {
		// like h1 tags, the spec says SPAN is phrasing only, but browsers and publisher treat span as a block tag
		let doc = try SwiftSoup.parse("<span>Hello <div>there</div> <span>now</span></span>")
		XCTAssertEqual("<span>Hello <div>there</div> <span>now</span></span>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testNoImagesInNoScriptInHead()throws {
		// jsoup used to allow, but against spec if parsing with noscript
		let doc = try SwiftSoup.parse("<html><head><noscript><img src='foo'></noscript></head><body><p>Hello</p></body></html>")
		XCTAssertEqual("<html><head><noscript>&lt;img src=\"foo\"&gt;</noscript></head><body><p>Hello</p></body></html>", try TextUtil.stripNewlines(doc.html()))
	}

	func testAFlowContents()throws {
		// html5 has <a> as either phrasing or block
		let doc = try SwiftSoup.parse("<a>Hello <div>there</div> <span>now</span></a>")
		XCTAssertEqual("<a>Hello <div>there</div> <span>now</span></a>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testFontFlowContents()throws {
		// html5 has no definition of <font>; often used as flow
		let doc = try SwiftSoup.parse("<font>Hello <div>there</div> <span>now</span></font>")
		XCTAssertEqual("<font>Hello <div>there</div> <span>now</span></font>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testhandlesMisnestedTagsBI()throws {
		// whatwg: <b><i></b></i>
		let h = "<p>1<b>2<i>3</b>4</i>5</p>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<p>1<b>2<i>3</i></b><i>4</i>5</p>", try doc.body()!.html())
		// adoption agency on </b>, reconstruction of formatters on 4.
	}

	func testhandlesMisnestedTagsBP()throws {
		//  whatwg: <b><p></b></p>
		let h = "<b>1<p>2</b>3</p>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<b>1</b>\n<p><b>2</b>3</p>", try doc.body()!.html())
	}

	func testhandlesUnexpectedMarkupInTables()throws {
		// whatwg - tests markers in active formatting (if they didn't work, would get in in table)
		// also tests foster parenting
		let h = "<table><b><tr><td>aaa</td></tr>bbb</table>ccc"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<b></b><b>bbb</b><table><tbody><tr><td>aaa</td></tr></tbody></table><b>ccc</b>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testHandlesUnclosedFormattingElements()throws {
		// whatwg: formatting elements get collected and applied, but excess elements are thrown away
		let h = "<!DOCTYPE html>\n" +
			"<p><b class=x><b class=x><b><b class=x><b class=x><b>X\n" +
			"<p>X\n" +
			"<p><b><b class=x><b>X\n" +
		"<p></b></b></b></b></b></b>X"
		let doc = try SwiftSoup.parse(h)
		doc.outputSettings().indentAmount(indentAmount: 0)
		let want = "<!doctype html>\n" +
			"<html>\n" +
			"<head></head>\n" +
			"<body>\n" +
			"<p><b class=\"x\"><b class=\"x\"><b><b class=\"x\"><b class=\"x\"><b>X </b></b></b></b></b></b></p>\n" +
			"<p><b class=\"x\"><b><b class=\"x\"><b class=\"x\"><b>X </b></b></b></b></b></p>\n" +
			"<p><b class=\"x\"><b><b class=\"x\"><b class=\"x\"><b><b><b class=\"x\"><b>X </b></b></b></b></b></b></b></b></p>\n" +
			"<p>X</p>\n" +
			"</body>\n" +
		"</html>"
		XCTAssertEqual(want, try doc.html())
	}

	func testhandlesUnclosedAnchors()throws {
		let h = "<a href='http://example.com/'>Link<p>Error link</a>"
		let doc = try SwiftSoup.parse(h)
		let want = "<a href=\"http://example.com/\">Link</a>\n<p><a href=\"http://example.com/\">Error link</a></p>"
		XCTAssertEqual(want, try doc.body()!.html())
	}

	func testreconstructFormattingElements()throws {
		// tests attributes and multi b
		let h = "<p><b class=one>One <i>Two <b>Three</p><p>Hello</p>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<p><b class=\"one\">One <i>Two <b>Three</b></i></b></p>\n<p><b class=\"one\"><i><b>Hello</b></i></b></p>", try doc.body()!.html())
	}

	func testreconstructFormattingElementsInTable()throws {
		// tests that tables get formatting markers -- the <b> applies outside the table and does not leak in,
		// and the <i> inside the table and does not leak out.
		let h = "<p><b>One</p> <table><tr><td><p><i>Three<p>Four</i></td></tr></table> <p>Five</p>"
		let doc = try SwiftSoup.parse(h)
		let want = "<p><b>One</b></p>\n" +
			"<b> \n" +
			" <table>\n" +
			"  <tbody>\n" +
			"   <tr>\n" +
			"    <td><p><i>Three</i></p><p><i>Four</i></p></td>\n" +
			"   </tr>\n" +
			"  </tbody>\n" +
		" </table> <p>Five</p></b>"
		XCTAssertEqual(want, try doc.body()!.html())
	}

	func testcommentBeforeHtml()throws {
		let h = "<!-- comment --><!-- comment 2 --><p>One</p>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<!-- comment --><!-- comment 2 --><html><head></head><body><p>One</p></body></html>", try TextUtil.stripNewlines(doc.html()))
	}

	func testemptyTdTag()throws {
		let h = "<table><tr><td>One</td><td id='2' /></tr></table>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual("<td>One</td>\n<td id=\"2\"></td>", try doc.select("tr").first()!.html())
	}

	func testhandlesSolidusInA()throws {
		// test for bug #66
		let h = "<a class=lp href=/lib/14160711/>link text</a>"
		let doc = try SwiftSoup.parse(h)
		let a: Element = try doc.select("a").first()!
		XCTAssertEqual("link text", try a.text())
		XCTAssertEqual("/lib/14160711/", try a.attr("href"))
	}

	func testhandlesSpanInTbody()throws {
		// test for bug 64
		let h = "<table><tbody><span class='1'><tr><td>One</td></tr><tr><td>Two</td></tr></span></tbody></table>"
		let doc = try SwiftSoup.parse(h)
		XCTAssertEqual(try doc.select("span").first()!.children().size(), 0) // the span gets closed
		XCTAssertEqual(try doc.select("table").size(), 1) // only one table
	}

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testParsesSimpleDocument", testParsesSimpleDocument),
			("testParsesRoughAttributes", testParsesRoughAttributes),
			("testParsesQuiteRoughAttributes", testParsesQuiteRoughAttributes),
			("testParsesComments", testParsesComments),
			("testParsesUnterminatedComments", testParsesUnterminatedComments),
			("testDropsUnterminatedTag", testDropsUnterminatedTag),
			("testDropsUnterminatedAttribute", testDropsUnterminatedAttribute),
			("testParsesUnterminatedTextarea", testParsesUnterminatedTextarea),
			("testParsesUnterminatedOption", testParsesUnterminatedOption),
			("testSpaceAfterTag", testSpaceAfterTag),
			("testCreatesDocumentStructure", testCreatesDocumentStructure),
			("testCreatesStructureFromBodySnippet", testCreatesStructureFromBodySnippet),
			("testHandlesEscapedData", testHandlesEscapedData),
			("testHandlesDataOnlyTags", testHandlesDataOnlyTags),
			("testHandlesTextAfterData", testHandlesTextAfterData),
			("testHandlesTextArea", testHandlesTextArea),
			("testPreservesSpaceInTextArea", testPreservesSpaceInTextArea),
			("testPreservesSpaceInScript", testPreservesSpaceInScript),
			("testDoesNotCreateImplicitLists", testDoesNotCreateImplicitLists),
			("testDiscardsNakedTds", testDiscardsNakedTds),
			("testHandlesNestedImplicitTable", testHandlesNestedImplicitTable),
			("testHandlesWhatWgExpensesTableExample", testHandlesWhatWgExpensesTableExample),
			("testHandlesTbodyTable", testHandlesTbodyTable),
			("testHandlesImplicitCaptionClose", testHandlesImplicitCaptionClose),
			("testNoTableDirectInTable", testNoTableDirectInTable),
			("testIgnoresDupeEndTrTag", testIgnoresDupeEndTrTag),
			("testHandlesBaseTags", testHandlesBaseTags),
			("testHandlesProtocolRelativeUrl", testHandlesProtocolRelativeUrl),
			("testHandlesCdata", testHandlesCdata),
			("testHandlesUnclosedCdataAtEOF", testHandlesUnclosedCdataAtEOF),
			("testHandlesInvalidStartTags", testHandlesInvalidStartTags),
			("testHandlesUnknownTags", testHandlesUnknownTags),
			("testHandlesUnknownInlineTags", testHandlesUnknownInlineTags),
			("testParsesBodyFragment", testParsesBodyFragment),
			("testHandlesUnknownNamespaceTags", testHandlesUnknownNamespaceTags),
			("testHandlesKnownEmptyBlocks", testHandlesKnownEmptyBlocks),
			("testHandlesSolidusAtAttributeEnd", testHandlesSolidusAtAttributeEnd),
			("testHandlesMultiClosingBody", testHandlesMultiClosingBody),
			("testHandlesUnclosedDefinitionLists", testHandlesUnclosedDefinitionLists),
			("testHandlesBlocksInDefinitions", testHandlesBlocksInDefinitions),
			("testHandlesFrames", testHandlesFrames),
			("testIgnoresContentAfterFrameset", testIgnoresContentAfterFrameset),
			("testHandlesJavadocFont", testHandlesJavadocFont),
			("testHandlesBaseWithoutHref", testHandlesBaseWithoutHref),
			("testNormalisesDocument", testNormalisesDocument),
			("testNormalisesEmptyDocument", testNormalisesEmptyDocument),
			("testNormalisesHeadlessBody", testNormalisesHeadlessBody),
			("testNormalisedBodyAfterContent", testNormalisedBodyAfterContent),
			("testfindsCharsetInMalformedMeta", testfindsCharsetInMalformedMeta),
			("testHgroup", testHgroup),
			("testRelaxedTags", testRelaxedTags),
			("testHeaderContents", testHeaderContents),
			("testSpanContents", testSpanContents),
			("testNoImagesInNoScriptInHead", testNoImagesInNoScriptInHead),
			("testAFlowContents", testAFlowContents),
			("testFontFlowContents", testFontFlowContents),
			("testhandlesMisnestedTagsBI", testhandlesMisnestedTagsBI),
			("testhandlesMisnestedTagsBP", testhandlesMisnestedTagsBP),
			("testhandlesUnexpectedMarkupInTables", testhandlesUnexpectedMarkupInTables),
			("testHandlesUnclosedFormattingElements", testHandlesUnclosedFormattingElements),
			("testhandlesUnclosedAnchors", testhandlesUnclosedAnchors),
			("testreconstructFormattingElements", testreconstructFormattingElements),
			("testreconstructFormattingElementsInTable", testreconstructFormattingElementsInTable),
			("testcommentBeforeHtml", testcommentBeforeHtml),
			("testemptyTdTag", testemptyTdTag),
			("testhandlesSolidusInA", testhandlesSolidusInA),
			("testhandlesSpanInTbody", testhandlesSpanInTbody)
		]
	}()

}
