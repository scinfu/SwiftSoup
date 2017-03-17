//
//  ElementTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 06/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
@testable import SwiftSoup
class ElementTest: XCTestCase {

	private let reference = "<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>"

	func testGetElementsByTagName() {
		let doc: Document = try! SwiftSoup.parse(reference)
		let divs = try! doc.getElementsByTag("div")
		XCTAssertEqual(2, divs.size())
		XCTAssertEqual("div1", divs.get(0).id())
		XCTAssertEqual("div2", divs.get(1).id())

		let ps = try! doc.getElementsByTag("p")
		XCTAssertEqual(2, ps.size())
		XCTAssertEqual("Hello", (ps.get(0).childNode(0) as! TextNode).getWholeText())
		XCTAssertEqual("Another ", (ps.get(1).childNode(0) as! TextNode).getWholeText())
		let ps2 = try! doc.getElementsByTag("P")
		XCTAssertEqual(ps, ps2)

		let imgs = try! doc.getElementsByTag("img")
		XCTAssertEqual("foo.png", try! imgs.get(0).attr("src"))

		let empty = try! doc.getElementsByTag("wtf")
		XCTAssertEqual(0, empty.size())
	}

	func testGetNamespacedElementsByTag() {
		let doc: Document = try! SwiftSoup.parse("<div><abc:def id=1>Hello</abc:def></div>")
		let els: Elements = try! doc.getElementsByTag("abc:def")
		XCTAssertEqual(1, els.size())
		XCTAssertEqual("1", els.first()?.id())
		XCTAssertEqual("abc:def", els.first()?.tagName())
	}

	func testGetElementById() {
		let doc: Document = try! SwiftSoup.parse(reference)
		let div: Element = try! doc.getElementById("div1")!
		XCTAssertEqual("div1", div.id())
		XCTAssertNil(try! doc.getElementById("none"))

		let doc2: Document = try! SwiftSoup.parse("<div id=1><div id=2><p>Hello <span id=2>world!</span></p></div></div>")
		let div2: Element = try! doc2.getElementById("2")!
		XCTAssertEqual("div", div2.tagName()) // not the span
		let span: Element = try! div2.child(0).getElementById("2")! // called from <p> context should be span
		XCTAssertEqual("span", span.tagName())
	}

	func testGetText() {
		let doc: Document = try! SwiftSoup.parse(reference)
		XCTAssertEqual("Hello Another element", try! doc.text())
		XCTAssertEqual("Another element", try! doc.getElementsByTag("p").get(1).text())
	}

	func testGetChildText() {
		let doc: Document = try! SwiftSoup.parse("<p>Hello <b>there</b> now")
		let p: Element = try! doc.select("p").first()!
		XCTAssertEqual("Hello there now", try! p.text())
		XCTAssertEqual("Hello now", p.ownText())
	}

	func testNormalisesText() {
		let h: String = "<p>Hello<p>There.</p> \n <p>Here <b>is</b> \n s<b>om</b>e text."
		let doc: Document = try! SwiftSoup.parse(h)
		let text: String = try! doc.text()
		XCTAssertEqual("Hello There. Here is some text.", text)
	}

	func testKeepsPreText() {
		let h = "<p>Hello \n \n there.</p> <div><pre>  What's \n\n  that?</pre>"
		let doc: Document = try! SwiftSoup.parse(h)
		XCTAssertEqual("Hello there.   What's \n\n  that?", try! doc.text())
	}

	func testKeepsPreTextInCode() {
		let h = "<pre><code>code\n\ncode</code></pre>"
		let doc: Document = try! SwiftSoup.parse(h)
		XCTAssertEqual("code\n\ncode", try! doc.text())
		XCTAssertEqual("<pre><code>code\n\ncode</code></pre>", try! doc.body()?.html())
	}

	func testBrHasSpace() {
		var doc: Document = try! SwiftSoup.parse("<p>Hello<br>there</p>")
		XCTAssertEqual("Hello there", try! doc.text())
		XCTAssertEqual("Hello there", try! doc.select("p").first()?.ownText())

		doc = try! SwiftSoup.parse("<p>Hello <br> there</p>")
		XCTAssertEqual("Hello there", try! doc.text())
	}

	func testGetSiblings() {
		let doc: Document = try! SwiftSoup.parse("<div><p>Hello<p id=1>there<p>this<p>is<p>an<p id=last>element</div>")
		let p: Element = try! doc.getElementById("1")!
		XCTAssertEqual("there", try! p.text())
		XCTAssertEqual("Hello", try! p.previousElementSibling()?.text())
		XCTAssertEqual("this", try! p.nextElementSibling()?.text())
		XCTAssertEqual("Hello", try! p.firstElementSibling()?.text())
		XCTAssertEqual("element", try! p.lastElementSibling()?.text())
	}

	func testGetSiblingsWithDuplicateContent() {
		let doc: Document = try! SwiftSoup.parse("<div><p>Hello<p id=1>there<p>this<p>this<p>is<p>an<p id=last>element</div>")
		let p: Element = try! doc.getElementById("1")!
		XCTAssertEqual("there", try! p.text())
		XCTAssertEqual("Hello", try! p.previousElementSibling()?.text())
		XCTAssertEqual("this", try! p.nextElementSibling()?.text())
		XCTAssertEqual("this", try! p.nextElementSibling()?.nextElementSibling()?.text())
		XCTAssertEqual("is", try! p.nextElementSibling()?.nextElementSibling()?.nextElementSibling()?.text())
		XCTAssertEqual("Hello", try! p.firstElementSibling()?.text())
		XCTAssertEqual("element", try! p.lastElementSibling()?.text())
	}

	func testGetParents() {
		let doc: Document = try! SwiftSoup.parse("<div><p>Hello <span>there</span></div>")
		let span: Element = try! doc.select("span").first()!
		let parents: Elements = span.parents()

		XCTAssertEqual(4, parents.size())
		XCTAssertEqual("p", parents.get(0).tagName())
		XCTAssertEqual("div", parents.get(1).tagName())
		XCTAssertEqual("body", parents.get(2).tagName())
		XCTAssertEqual("html", parents.get(3).tagName())
	}

	func testElementSiblingIndex() {
		let doc: Document = try! SwiftSoup.parse("<div><p>One</p>...<p>Two</p>...<p>Three</p>")
		let ps: Elements = try! doc.select("p")
		XCTAssertTrue(try! 0 == ps.get(0).elementSiblingIndex())
		XCTAssertTrue(try! 1 == ps.get(1).elementSiblingIndex())
		XCTAssertTrue(try! 2 == ps.get(2).elementSiblingIndex())
	}

	func testElementSiblingIndexSameContent() {
		let doc: Document = try! SwiftSoup.parse("<div><p>One</p>...<p>One</p>...<p>One</p>")
		let ps: Elements = try! doc.select("p")
		XCTAssertTrue(try! 0 == ps.get(0).elementSiblingIndex())
		XCTAssertTrue(try! 1 == ps.get(1).elementSiblingIndex())
		XCTAssertTrue(try! 2 == ps.get(2).elementSiblingIndex())
	}

	func testGetElementsWithClass() {
		let doc: Document = try! SwiftSoup.parse("<div class='mellow yellow'><span class=mellow>Hello <b class='yellow'>Yellow!</b></span><p>Empty</p></div>")

		let els = try! doc.getElementsByClass("mellow")
		XCTAssertEqual(2, els.size())
		XCTAssertEqual("div", els.get(0).tagName())
		XCTAssertEqual("span", els.get(1).tagName())

		let els2 = try! doc.getElementsByClass("yellow")
		XCTAssertEqual(2, els2.size())
		XCTAssertEqual("div", els2.get(0).tagName())
		XCTAssertEqual("b", els2.get(1).tagName())

		let none = try! doc.getElementsByClass("solo")
		XCTAssertEqual(0, none.size())
	}

	func testGetElementsWithAttribute() {
		let doc: Document = try! SwiftSoup.parse("<div style='bold'><p title=qux><p><b style></b></p></div>")
		let els = try! doc.getElementsByAttribute("style")
		XCTAssertEqual(2, els.size())
		XCTAssertEqual("div", els.get(0).tagName())
		XCTAssertEqual("b", els.get(1).tagName())

		let none = try! doc.getElementsByAttribute("class")
		XCTAssertEqual(0, none.size())
	}

	func testGetElementsWithAttributeDash() {
		let doc: Document = try! SwiftSoup.parse("<meta http-equiv=content-type value=utf8 id=1> <meta name=foo content=bar id=2> <div http-equiv=content-type value=utf8 id=3>")
		let meta: Elements = try! doc.select("meta[http-equiv=content-type], meta[charset]")
		XCTAssertEqual(1, meta.size())
		XCTAssertEqual("1", meta.first()!.id())
	}

	func testGetElementsWithAttributeValue() {
		let doc = try! SwiftSoup.parse("<div style='bold'><p><p><b style></b></p></div>")
		let els: Elements = try! doc.getElementsByAttributeValue("style", "bold")
		XCTAssertEqual(1, els.size())
		XCTAssertEqual("div", els.get(0).tagName())

		let none: Elements = try! doc.getElementsByAttributeValue("style", "none")
		XCTAssertEqual(0, none.size())
	}

	func testClassDomMethods() {
		let doc: Document = try! SwiftSoup.parse("<div><span class=' mellow yellow '>Hello <b>Yellow</b></span></div>")
		let els: Elements = try! doc.getElementsByAttribute("class")
		let span: Element = els.get(0)
		XCTAssertEqual("mellow yellow", try! span.className())
		XCTAssertTrue(span.hasClass("mellow"))
		XCTAssertTrue(span.hasClass("yellow"))
		var classes: OrderedSet<String> = try! span.classNames()
		XCTAssertEqual(2, classes.count)
		XCTAssertTrue(classes.contains("mellow"))
		XCTAssertTrue(classes.contains("yellow"))

		XCTAssertEqual("", try! doc.className())
		classes = try! doc.classNames()
		XCTAssertEqual(0, classes.count)
		XCTAssertFalse(doc.hasClass("mellow"))
	}

    func testHasClassDomMethods()throws {
        let tag: Tag = try Tag.valueOf("a")
        let attribs: Attributes = Attributes()
        let el: Element = Element(tag, "", attribs)

        try attribs.put("class", "toto")
        var hasClass = el.hasClass("toto")
        XCTAssertTrue(hasClass)

        try attribs.put("class", " toto")
        hasClass = el.hasClass("toto")
        XCTAssertTrue(hasClass)

        try attribs.put("class", "toto ")
        hasClass = el.hasClass("toto")
        XCTAssertTrue(hasClass)

        try attribs.put("class", "\ttoto ")
        hasClass = el.hasClass("toto")
        XCTAssertTrue(hasClass)

        try attribs.put("class", "  toto ")
        hasClass = el.hasClass("toto")
        XCTAssertTrue(hasClass)

        try attribs.put("class", "ab")
        hasClass = el.hasClass("toto")
        XCTAssertFalse(hasClass)

        try attribs.put("class", "     ")
        hasClass = el.hasClass("toto")
        XCTAssertFalse(hasClass)

        try attribs.put("class", "tototo")
        hasClass = el.hasClass("toto")
        XCTAssertFalse(hasClass)

        try attribs.put("class", "raulpismuth  ")
        hasClass = el.hasClass("raulpismuth")
        XCTAssertTrue(hasClass)

        try attribs.put("class", " abcd  raulpismuth efgh ")
        hasClass = el.hasClass("raulpismuth")
        XCTAssertTrue(hasClass)

        try attribs.put("class", " abcd efgh raulpismuth")
        hasClass = el.hasClass("raulpismuth")
        XCTAssertTrue(hasClass)

        try attribs.put("class", " abcd efgh raulpismuth ")
        hasClass = el.hasClass("raulpismuth")
        XCTAssertTrue(hasClass)
    }

    func testClassUpdates()throws {
        let doc: Document = try SwiftSoup.parse("<div class='mellow yellow'></div>")
        let div: Element = try doc.select("div").first()!

        try div.addClass("green")
        XCTAssertEqual("mellow yellow green", try div.className())
        try div.removeClass("red") // noop
        try div.removeClass("yellow")
        XCTAssertEqual("mellow green", try div.className())
        try div.toggleClass("green").toggleClass("red")
        XCTAssertEqual("mellow red", try div.className())
    }

    func testOuterHtml()throws {
        let doc = try SwiftSoup.parse("<div title='Tags &amp;c.'><img src=foo.png><p><!-- comment -->Hello<p>there")
        XCTAssertEqual("<html><head></head><body><div title=\"Tags &amp;c.\"><img src=\"foo.png\"><p><!-- comment -->Hello</p><p>there</p></div></body></html>",
                       try TextUtil.stripNewlines(doc.outerHtml()))
    }

	func testInnerHtml()throws {
		let doc: Document = try SwiftSoup.parse("<div>\n <p>Hello</p> </div>")
		XCTAssertEqual("<p>Hello</p>", try doc.getElementsByTag("div").get(0).html())
	}

	func testFormatHtml()throws {
		let doc: Document = try SwiftSoup.parse("<title>Format test</title><div><p>Hello <span>jsoup <span>users</span></span></p><p>Good.</p></div>")
		XCTAssertEqual("<html>\n <head>\n  <title>Format test</title>\n </head>\n <body>\n  <div>\n   <p>Hello <span>jsoup <span>users</span></span></p>\n   <p>Good.</p>\n  </div>\n </body>\n</html>", try doc.html())
	}

	func testFormatOutline()throws {
		let doc: Document = try SwiftSoup.parse("<title>Format test</title><div><p>Hello <span>jsoup <span>users</span></span></p><p>Good.</p></div>")
		doc.outputSettings().outline(outlineMode: true)
		XCTAssertEqual("<html>\n <head>\n  <title>Format test</title>\n </head>\n <body>\n  <div>\n   <p>\n    Hello \n    <span>\n     jsoup \n     <span>users</span>\n    </span>\n   </p>\n   <p>Good.</p>\n  </div>\n </body>\n</html>", try doc.html())
	}

	func testSetIndent()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello\nthere</p></div>")
		doc.outputSettings().indentAmount(indentAmount: 0)
		XCTAssertEqual("<html>\n<head></head>\n<body>\n<div>\n<p>Hello there</p>\n</div>\n</body>\n</html>", try doc.html())
	}

	func testNotPretty()throws {
		let doc: Document = try SwiftSoup.parse("<div>   \n<p>Hello\n there\n</p></div>")
		doc.outputSettings().prettyPrint(pretty: false)
		XCTAssertEqual("<html><head></head><body><div>   \n<p>Hello\n there\n</p></div></body></html>", try doc.html())

		let div: Element? = try doc.select("div").first()
		XCTAssertEqual("   \n<p>Hello\n there\n</p>", try div?.html())
	}

	func testEmptyElementFormatHtml()throws {
		// don't put newlines into empty blocks
		let doc: Document = try SwiftSoup.parse("<section><div></div></section>")
		XCTAssertEqual("<section>\n <div></div>\n</section>", try doc.select("section").first()?.outerHtml())
	}

	func testNoIndentOnScriptAndStyle()throws {
		// don't newline+indent closing </script> and </style> tags
		let doc: Document = try SwiftSoup.parse("<script>one\ntwo</script>\n<style>three\nfour</style>")
		XCTAssertEqual("<script>one\ntwo</script> \n<style>three\nfour</style>", try  doc.head()?.html())
	}

	func testContainerOutput()throws {
		let doc: Document = try SwiftSoup.parse("<title>Hello there</title> <div><p>Hello</p><p>there</p></div> <div>Another</div>")
		XCTAssertEqual("<title>Hello there</title>", try  doc.select("title").first()?.outerHtml())
		XCTAssertEqual("<div>\n <p>Hello</p>\n <p>there</p>\n</div>", try  doc.select("div").first()?.outerHtml())
		XCTAssertEqual("<div>\n <p>Hello</p>\n <p>there</p>\n</div> \n<div>\n Another\n</div>", try doc.select("body").first()?.html())
	}

	func testSetText()throws {
		let h: String = "<div id=1>Hello <p>there <b>now</b></p></div>"
		let doc: Document = try SwiftSoup.parse(h)
		XCTAssertEqual("Hello there now", try doc.text()) // need to sort out node whitespace
		XCTAssertEqual("there now", try doc.select("p").get(0).text())

		let div: Element? = try doc.getElementById("1")?.text("Gone")
		XCTAssertEqual("Gone", try div?.text())
		XCTAssertEqual(0, try doc.select("p").size())
	}

	func testAddNewElement()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element = try doc.getElementById("1")!
		try div.appendElement("p").text("there")
		try div.appendElement("P").attr("CLASS", "second").text("now")
		// manually specifying tag and attributes should now preserve case, regardless of parse mode
		XCTAssertEqual("<html><head></head><body><div id=\"1\"><p>Hello</p><p>there</p><P CLASS=\"second\">now</P></div></body></html>",
		             TextUtil.stripNewlines(try doc.html()))

		// check sibling index (with short circuit on reindexChildren):
		let ps: Elements = try doc.select("p")
		for i in 0..<ps.size() {
			XCTAssertEqual(i, ps.get(i).siblingIndex)
		}
	}

	func testAddBooleanAttribute()throws {
		let div: Element = try Element(Tag.valueOf("div"), "")

		try div.attr("true", true)

		try div.attr("false", "value")
		try div.attr("false", false)

		XCTAssertTrue(div.hasAttr("true"))
		XCTAssertEqual("", try div.attr("true"))

		let attributes: Array<Attribute> = div.getAttributes()!.asList()
		XCTAssertEqual(1, attributes.count)
		XCTAssertTrue((attributes[0] as? BooleanAttribute) != nil)

		XCTAssertFalse(div.hasAttr("false"))

		XCTAssertEqual("<div true></div>", try div.outerHtml())
	}

	func testAppendRowToTable()throws {
		let doc: Document = try SwiftSoup.parse("<table><tr><td>1</td></tr></table>")
		let table: Element? = try doc.select("tbody").first()
		try table?.append("<tr><td>2</td></tr>")

		XCTAssertEqual("<table><tbody><tr><td>1</td></tr><tr><td>2</td></tr></tbody></table>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testPrependRowToTable()throws {
		let doc: Document = try SwiftSoup.parse("<table><tr><td>1</td></tr></table>")
		let table: Element? = try doc.select("tbody").first()
		try table?.prepend("<tr><td>2</td></tr>")

		XCTAssertEqual("<table><tbody><tr><td>2</td></tr><tr><td>1</td></tr></tbody></table>", try TextUtil.stripNewlines(doc.body()!.html()))

		// check sibling index (reindexChildren):
		let ps: Elements = try doc.select("tr")
		for i in 0..<ps.size() {
			XCTAssertEqual(i, ps.get(i).siblingIndex)
		}
	}

	func testPrependElement()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element? = try doc.getElementById("1")
		try div?.prependElement("p").text("Before")
		XCTAssertEqual("Before", try div?.child(0).text())
		XCTAssertEqual("Hello", try div?.child(1).text())
	}

	func testAddNewText()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element = try doc.getElementById("1")!
		try div.appendText(" there & now >")
		XCTAssertEqual("<p>Hello</p> there &amp; now &gt;", try TextUtil.stripNewlines(div.html()))
	}

	func testPrependText()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element = try doc.getElementById("1")!
		try div.prependText("there & now > ")
		XCTAssertEqual("there & now > Hello", try div.text())
		XCTAssertEqual("there &amp; now &gt; <p>Hello</p>", try TextUtil.stripNewlines(div.html()))
	}

	// nil not allower
//	func testThrowsOnAddNullText()throws {
//		let doc: Document = try Jsoup.parse("<div id=1><p>Hello</p></div>");
//		let div: Element = try doc.getElementById("1")!;
//		div.appendText(nil);
//	}

	// nil not allower
//	@Test(expected = IllegalArgumentException.class)  public void testThrowsOnPrependNullText() {
//	Document doc = Jsoup.parse("<div id=1><p>Hello</p></div>");
//	Element div = doc.getElementById("1");
//	div.prependText(null);
//	}

	func testAddNewHtml()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element = try doc.getElementById("1")!
		try div.append("<p>there</p><p>now</p>")
		XCTAssertEqual("<p>Hello</p><p>there</p><p>now</p>", try TextUtil.stripNewlines(div.html()))

		// check sibling index (no reindexChildren):
		let ps: Elements = try doc.select("p")
		for i in 0..<ps.size() {
			XCTAssertEqual(i, ps.get(i).siblingIndex)
		}
	}

	func testPrependNewHtml()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element = try doc.getElementById("1")!
		try div.prepend("<p>there</p><p>now</p>")
		XCTAssertEqual("<p>there</p><p>now</p><p>Hello</p>", try TextUtil.stripNewlines(div.html()))

		// check sibling index (reindexChildren):
		let ps: Elements = try doc.select("p")
		for i in 0..<ps.size() {
			XCTAssertEqual(i, ps.get(i).siblingIndex)
		}
	}

	func testSetHtml()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1><p>Hello</p></div>")
		let div: Element = try doc.getElementById("1")!
		try div.html("<p>there</p><p>now</p>")
		XCTAssertEqual("<p>there</p><p>now</p>", try TextUtil.stripNewlines(div.html()))
	}

	func testSetHtmlTitle()throws {
		let doc: Document = try SwiftSoup.parse("<html><head id=2><title id=1></title></head></html>")

		let title: Element = try doc.getElementById("1")!
		try title.html("good")
		XCTAssertEqual("good", try title.html())
		try title.html("<i>bad</i>")
		XCTAssertEqual("&lt;i&gt;bad&lt;/i&gt;", try title.html())

		let head: Element = try doc.getElementById("2")!
		try head.html("<title><i>bad</i></title>")
		XCTAssertEqual("<title>&lt;i&gt;bad&lt;/i&gt;</title>", try head.html())
	}

	func testWrap()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p><p>There</p></div>")
		let p: Element = try doc.select("p").first()!
		try p.wrap("<div class='head'></div>")
		XCTAssertEqual("<div><div class=\"head\"><p>Hello</p></div><p>There</p></div>", try TextUtil.stripNewlines(doc.body()!.html()))

		let ret: Element = try p.wrap("<div><div class=foo></div><p>What?</p></div>")
		XCTAssertEqual("<div><div class=\"head\"><div><div class=\"foo\"><p>Hello</p></div><p>What?</p></div></div><p>There</p></div>",
		             try TextUtil.stripNewlines(doc.body()!.html()))

		XCTAssertEqual(ret, p)
	}

	func testBefore()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p><p>There</p></div>")
		let p1: Element = try doc.select("p").first()!
		try p1.before("<div>one</div><div>two</div>")
		XCTAssertEqual("<div><div>one</div><div>two</div><p>Hello</p><p>There</p></div>", try TextUtil.stripNewlines(doc.body()!.html()))

		try doc.select("p").last()?.before("<p>Three</p><!-- four -->")
		XCTAssertEqual("<div><div>one</div><div>two</div><p>Hello</p><p>Three</p><!-- four --><p>There</p></div>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testAfter()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p><p>There</p></div>")
		let p1: Element = try doc.select("p").first()!
		try p1.after("<div>one</div><div>two</div>")
		XCTAssertEqual("<div><p>Hello</p><div>one</div><div>two</div><p>There</p></div>", try TextUtil.stripNewlines(doc.body()!.html()))

		try doc.select("p").last()?.after("<p>Three</p><!-- four -->")
		XCTAssertEqual("<div><p>Hello</p><div>one</div><div>two</div><p>There</p><p>Three</p><!-- four --></div>", TextUtil.stripNewlines(try doc.body()!.html()))
	}

	func testWrapWithRemainder()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div>")
		let p: Element = try doc.select("p").first()!
		try p.wrap("<div class='head'></div><p>There!</p>")
		XCTAssertEqual("<div><div class=\"head\"><p>Hello</p><p>There!</p></div></div>", TextUtil.stripNewlines(try doc.body()!.html()))
	}

	func testHasText()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>Hello</p><p></p></div>")
		let div: Element = try doc.select("div").first()!
		let ps: Elements = try doc.select("p")

		XCTAssertTrue(div.hasText())
		XCTAssertTrue(ps.first()!.hasText())
		XCTAssertFalse(ps.last()!.hasText())
	}

	//todo:datase is a simple dictionary but in java it's different
	func testDataset()throws {
//		let doc: Document = try Jsoup.parse("<div id=1 data-name=jsoup class=new data-package=jar>Hello</div><p id=2>Hello</p>");
//		let div: Element = try doc.select("div").first()!;
//		var dataset = div.dataset();
//		let attributes: Attributes = div.getAttributes()!;
//		
//		// size, get, set, add, remove
//		XCTAssertEqual(2, dataset.count);
//		XCTAssertEqual("jsoup", dataset["name"]);
//		XCTAssertEqual("jar", dataset["package"]);
//		
//		dataset["name"] = "jsoup updated"
//		dataset["language"] = "java"
//		dataset.removeValue(forKey: "package")
//		
//		XCTAssertEqual(2, dataset.count);
//		XCTAssertEqual(4, attributes.size());
//		XCTAssertEqual("jsoup updated", try attributes.get(key: "data-name"));
//		XCTAssertEqual("jsoup updated", dataset["name"]);
//		XCTAssertEqual("java", try attributes.get(key: "data-language"));
//		XCTAssertEqual("java", dataset["language"]);
//		
//		try attributes.put("data-food", "bacon");
//		XCTAssertEqual(3, dataset.count);
//		XCTAssertEqual("bacon", dataset["food"]);
//		
//		try attributes.put("data-", "empty");
//		XCTAssertEqual(nil, dataset[""]); // data- is not a data attribute
//		
//		let p: Element = try doc.select("p").first()!;
//		XCTAssertEqual(0, p.dataset().count);

	}

	func testpParentlessToString()throws {
		let doc: Document = try SwiftSoup.parse("<img src='foo'>")
		let img: Element = try doc.select("img").first()!
		XCTAssertEqual("<img src=\"foo\">", try img.outerHtml())

		try img.remove() // lost its parent
		XCTAssertEqual("<img src=\"foo\">", try img.outerHtml())
	}

	func testClone()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One<p><span>Two</div>")

		let p: Element = try doc.select("p").get(1)
		let clone: Element = p.copy() as! Element

		XCTAssertNil(clone.parent()) // should be orphaned
		XCTAssertEqual(0, clone.siblingIndex)
		XCTAssertEqual(1, p.siblingIndex)
		XCTAssertNotNil(p.parent())

		try clone.append("<span>Three")
		XCTAssertEqual("<p><span>Two</span><span>Three</span></p>", try TextUtil.stripNewlines(clone.outerHtml()))
		XCTAssertEqual("<div><p>One</p><p><span>Two</span></p></div>", try TextUtil.stripNewlines(doc.body()!.html())) // not modified

		try doc.body()?.appendChild(clone) // adopt
		XCTAssertNotNil(clone.parent())
		XCTAssertEqual("<div><p>One</p><p><span>Two</span></p></div><p><span>Two</span><span>Three</span></p>", try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testClonesClassnames()throws {
		let doc: Document = try SwiftSoup.parse("<div class='one two'></div>")
		let div: Element = try doc.select("div").first()!
		let classes = try div.classNames()
		XCTAssertEqual(2, classes.count)
		XCTAssertTrue(classes.contains("one"))
		XCTAssertTrue(classes.contains("two"))

		let copy: Element = div.copy() as! Element
		let copyClasses: OrderedSet<String> = try copy.classNames()
		XCTAssertEqual(2, copyClasses.count)
		XCTAssertTrue(copyClasses.contains("one"))
		XCTAssertTrue(copyClasses.contains("two"))
		copyClasses.append("three")
		copyClasses.remove("one")

		XCTAssertTrue(classes.contains("one"))
		XCTAssertFalse(classes.contains("three"))
		XCTAssertFalse(copyClasses.contains("one"))
		XCTAssertTrue(copyClasses.contains("three"))

		XCTAssertEqual("", try div.html())
		XCTAssertEqual("", try copy.html())
	}

	func testTagNameSet()throws {
		let doc: Document = try SwiftSoup.parse("<div><i>Hello</i>")
		try doc.select("i").first()!.tagName("em")
		XCTAssertEqual(0, try doc.select("i").size())
		XCTAssertEqual(1, try doc.select("em").size())
		XCTAssertEqual("<em>Hello</em>", try doc.select("div").first()!.html())
	}

	func testHtmlContainsOuter()throws {
		let doc: Document = try SwiftSoup.parse("<title>Check</title> <div>Hello there</div>")
		doc.outputSettings().indentAmount(indentAmount: 0)
		XCTAssertTrue(try doc.html().contains(doc.select("title").outerHtml()))
		XCTAssertTrue(try doc.html().contains(doc.select("div").outerHtml()))
	}

	func testGetTextNodes()throws {
		let doc: Document = try SwiftSoup.parse("<p>One <span>Two</span> Three <br> Four</p>")
		let textNodes: Array<TextNode> = try doc.select("p").first()!.textNodes()

		XCTAssertEqual(3, textNodes.count)
		XCTAssertEqual("One ", textNodes[0].text())
		XCTAssertEqual(" Three ", textNodes[1].text())
		XCTAssertEqual(" Four", textNodes[2].text())

		XCTAssertEqual(0, try doc.select("br").first()!.textNodes().count)
	}

	func testManipulateTextNodes()throws {
		let doc: Document = try SwiftSoup.parse("<p>One <span>Two</span> Three <br> Four</p>")
		let p: Element = try doc.select("p").first()!
		let textNodes: Array<TextNode> = p.textNodes()

		textNodes[1].text(" three-more ")
		try textNodes[2].splitText(3).text("-ur")

		XCTAssertEqual("One Two three-more Fo-ur", try p.text())
		XCTAssertEqual("One three-more Fo-ur", p.ownText())
		XCTAssertEqual(4, p.textNodes().count) // grew because of split
	}

	func testGetDataNodes()throws {
		let doc: Document = try SwiftSoup.parse("<script>One Two</script> <style>Three Four</style> <p>Fix Six</p>")
		let script: Element = try doc.select("script").first()!
		let style: Element = try doc.select("style").first()!
		let p: Element = try doc.select("p").first()!

		let scriptData: Array<DataNode> = script.dataNodes()
		XCTAssertEqual(1, scriptData.count)
		XCTAssertEqual("One Two", scriptData[0].getWholeData())

		let styleData: Array<DataNode> = style.dataNodes()
		XCTAssertEqual(1, styleData.count)
		XCTAssertEqual("Three Four", styleData[0].getWholeData())

		let pData: Array<DataNode> = p.dataNodes()
		XCTAssertEqual(0, pData.count)
	}

	func testElementIsNotASiblingOfItself()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One<p>Two<p>Three</div>")
		let p2: Element = try doc.select("p").get(1)

		XCTAssertEqual("Two", try p2.text())
		let els: Elements = p2.siblingElements()
		XCTAssertEqual(2, els.size())
		XCTAssertEqual("<p>One</p>", try els.get(0).outerHtml())
		XCTAssertEqual("<p>Three</p>", try els.get(1).outerHtml())
	}

	func testChildThrowsIndexOutOfBoundsOnMissing()throws {
		let doc: Document = try SwiftSoup.parse("<div><p>One</p><p>Two</p></div>")
		let div: Element = try doc.select("div").first()!

		XCTAssertEqual(2, div.children().size())
		XCTAssertEqual("One", try div.child(0).text())
	}

	func testMoveByAppend()throws {
		// can empty an element and append its children to another element
		let doc: Document = try SwiftSoup.parse("<div id=1>Text <p>One</p> Text <p>Two</p></div><div id=2></div>")
		let div1: Element = try doc.select("div").get(0)
		let div2: Element = try doc.select("div").get(1)

		XCTAssertEqual(4, div1.childNodeSize())
		var children: Array<Node> = div1.getChildNodes()
		XCTAssertEqual(4, children.count)

		try div2.insertChildren(0, children)

		children = div1.getChildNodes()
		XCTAssertEqual(0, children.count) // children is backed by div1.childNodes, moved, so should be 0 now
		XCTAssertEqual(0, div1.childNodeSize())
		XCTAssertEqual(4, div2.childNodeSize())
		XCTAssertEqual("<div id=\"1\"></div>\n<div id=\"2\">\n Text \n <p>One</p> Text \n <p>Two</p>\n</div>", try doc.body()!.html())
	}

	func testInsertChildrenArgumentValidation()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1>Text <p>One</p> Text <p>Two</p></div><div id=2></div>")
		let div1: Element = try doc.select("div").get(0)
		let div2: Element = try doc.select("div").get(1)
		let children: Array<Node> = div1.getChildNodes()

		do {
			try div2.insertChildren(6, children)
			XCTAssertEqual(0, 1)
		} catch {}

		do {
			try div2.insertChildren(-5, children)
			XCTAssertEqual(0, 1)
		} catch {
		}
	}

	func testInsertChildrenAtPosition()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1>Text1 <p>One</p> Text2 <p>Two</p></div><div id=2>Text3 <p>Three</p></div>")
		let div1: Element = try doc.select("div").get(0)
		let p1s: Elements = try div1.select("p")
		let div2: Element = try doc.select("div").get(1)

		XCTAssertEqual(2, div2.childNodeSize())
		try div2.insertChildren(-1, p1s.array())
		XCTAssertEqual(2, div1.childNodeSize()) // moved two out
		XCTAssertEqual(4, div2.childNodeSize())
		XCTAssertEqual(3, p1s.get(1).siblingIndex) // should be last

		var els: Array<Node> = Array<Node>()
		let el1: Element = try Element(Tag.valueOf("span"), "").text("Span1")
		let el2: Element = try Element(Tag.valueOf("span"), "").text("Span2")
		let tn1: TextNode = TextNode("Text4", "")
		els.append(el1)
		els.append(el2)
		els.append(tn1)

		XCTAssertNil(el1.parent())
		try div2.insertChildren(-2, els)
		XCTAssertEqual(div2, el1.parent())
		XCTAssertEqual(7, div2.childNodeSize())
		XCTAssertEqual(3, el1.siblingIndex)
		XCTAssertEqual(4, el2.siblingIndex)
		XCTAssertEqual(5, tn1.siblingIndex)
	}

	func testInsertChildrenAsCopy()throws {
		let doc: Document = try SwiftSoup.parse("<div id=1>Text <p>One</p> Text <p>Two</p></div><div id=2></div>")
		let div1: Element = try doc.select("div").get(0)
		let div2: Element = try doc.select("div").get(1)
		let ps: Elements = try doc.select("p").copy() as! Elements
		try ps.first()!.text("One cloned")
		try div2.insertChildren(-1, ps.array())

		XCTAssertEqual(4, div1.childNodeSize()) // not moved -- cloned
		XCTAssertEqual(2, div2.childNodeSize())
		XCTAssertEqual("<div id=\"1\">Text <p>One</p> Text <p>Two</p></div><div id=\"2\"><p>One cloned</p><p>Two</p></div>",
		             try TextUtil.stripNewlines(doc.body()!.html()))
	}

	func testCssPath()throws {
		let doc: Document = try SwiftSoup.parse("<div id=\"id1\">A</div><div>B</div><div class=\"c1 c2\">C</div>")
		let divA: Element = try doc.select("div").get(0)
		let divB: Element = try doc.select("div").get(1)
		let divC: Element = try doc.select("div").get(2)
		XCTAssertEqual(try divA.cssSelector(), "#id1")
		XCTAssertEqual(try divB.cssSelector(), "html > body > div:nth-child(2)")
		XCTAssertEqual(try divC.cssSelector(), "html > body > div.c1.c2")

		XCTAssertTrue(try divA == doc.select(divA.cssSelector()).first())
		XCTAssertTrue(try divB == doc.select(divB.cssSelector()).first())
		XCTAssertTrue(try divC == doc.select(divC.cssSelector()).first())
	}

	func testClassNames()throws {
		let doc: Document = try SwiftSoup.parse("<div class=\"c1 c2\">C</div>")
		let div: Element = try doc.select("div").get(0)

		XCTAssertEqual("c1 c2", try div.className())

		let set1 = try div.classNames()
		let arr1 = set1
		XCTAssertTrue(arr1.count==2)
		XCTAssertEqual("c1", arr1[0])
		XCTAssertEqual("c2", arr1[1])

		// Changes to the set should not be reflected in the Elements getters
		set1.append("c3")
		XCTAssertTrue(try 2==div.classNames().count)
		XCTAssertEqual("c1 c2", try div.className())

		// Update the class names to a fresh set
		let newSet = OrderedSet<String>()
		newSet.append(contentsOf:set1)
		//newSet["c3"] //todo: nabil not a set , add == append but not change exists c3

		try div.classNames(newSet)

		XCTAssertEqual("c1 c2 c3", try div.className())

		let set2 = try div.classNames()
		let arr2 = set2
		XCTAssertTrue(arr2.count==3)
		XCTAssertEqual("c1", arr2[0])
		XCTAssertEqual("c2", arr2[1])
		XCTAssertEqual("c3", arr2[2])
	}

	func testHashAndEqualsAndValue()throws {
		// .equals and hashcode are identity. value is content.

		let doc1 = "<div id=1><p class=one>One</p><p class=one>One</p><p class=one>Two</p><p class=two>One</p></div>" +
		"<div id=2><p class=one>One</p><p class=one>One</p><p class=one>Two</p><p class=two>One</p></div>"

		let doc: Document = try SwiftSoup.parse(doc1)
		let els: Elements = try doc.select("p")

		/*
		for (Element el : els) {
		System.out.println(el.hashCode() + " - " + el.outerHtml());
		}
		
		0 1534787905 - <p class="one">One</p>
		1 1534787905 - <p class="one">One</p>
		2 1539683239 - <p class="one">Two</p>
		3 1535455211 - <p class="two">One</p>
		4 1534787905 - <p class="one">One</p>
		5 1534787905 - <p class="one">One</p>
		6 1539683239 - <p class="one">Two</p>
		7 1535455211 - <p class="two">One</p>
		*/
		XCTAssertEqual(8, els.size())
		let e0: Element = els.get(0)
		let e1: Element = els.get(1)
		let e2: Element = els.get(2)
		let e3: Element = els.get(3)
		let e4: Element = els.get(4)
		let e5: Element = els.get(5)
		let e6: Element = els.get(6)
		let e7: Element = els.get(7)

		XCTAssertEqual(e0, e0)
		XCTAssertTrue(try e0.hasSameValue(e1))
		XCTAssertTrue(try e0.hasSameValue(e4))
		XCTAssertTrue(try e0.hasSameValue(e5))
		XCTAssertFalse(e0.equals(e2))
		XCTAssertFalse(try e0.hasSameValue(e2))
		XCTAssertFalse(try e0.hasSameValue(e3))
		XCTAssertFalse(try e0.hasSameValue(e6))
		XCTAssertFalse(try e0.hasSameValue(e7))

		XCTAssertEqual(e0.hashValue, e0.hashValue)
		XCTAssertFalse(e0.hashValue == (e2.hashValue))
		XCTAssertFalse(e0.hashValue == (e3).hashValue)
		XCTAssertFalse(e0.hashValue == (e6).hashValue)
		XCTAssertFalse(e0.hashValue == (e7).hashValue)
	}

	func testRelativeUrls()throws {
		let html = "<body><a href='./one.html'>One</a> <a href='two.html'>two</a> <a href='../three.html'>Three</a> <a href='//example2.com/four/'>Four</a> <a href='https://example2.com/five/'>Five</a>"
		let doc: Document = try SwiftSoup.parse(html, "http://example.com/bar/")
		let els: Elements = try doc.select("a")

		XCTAssertEqual("http://example.com/bar/one.html", try els.get(0).absUrl("href"))
		XCTAssertEqual("http://example.com/bar/two.html", try els.get(1).absUrl("href"))
		XCTAssertEqual("http://example.com/three.html", try els.get(2).absUrl("href"))
		XCTAssertEqual("http://example2.com/four/", try els.get(3).absUrl("href"))
		XCTAssertEqual("https://example2.com/five/", try els.get(4).absUrl("href"))
	}

	func testAppendMustCorrectlyMoveChildrenInsideOneParentElement()throws {
		let doc: Document = Document("")
		let body: Element = try doc.appendElement("body")
		try body.appendElement("div1")
		try body.appendElement("div2")
		let div3: Element = try body.appendElement("div3")
		try div3.text("Check")
		let div4: Element = try body.appendElement("div4")

		var toMove: Array<Element> = Array<Element>()
		toMove.append(div3)
		toMove.append(div4)

		try body.insertChildren(0, toMove)

		let result: String = try doc.outerHtml().replaceAll(of: "\\s+", with: "")
		XCTAssertEqual("<body><div3>Check</div3><div4></div4><div1></div1><div2></div2></body>", result)
	}

	func testHashcodeIsStableWithContentChanges()throws {
		let root: Element = try Element(Tag.valueOf("root"), "")
		let set = OrderedSet<Element>()
		// Add root node:
		set.append(root)
		try root.appendChild(Element(Tag.valueOf("a"), ""))
		XCTAssertTrue(set.contains(root))
	}

	func testNamespacedElements()throws {
		// Namespaces with ns:tag in HTML must be translated to ns|tag in CSS.
		let html: String = "<html><body><fb:comments /></body></html>"
		let doc: Document = try SwiftSoup.parse(html, "http://example.com/bar/")
		let els: Elements = try doc.select("fb|comments")
		XCTAssertEqual(1, els.size())
		XCTAssertEqual("html > body > fb|comments", try els.get(0).cssSelector())
	}
    
    func testChainedRemoveAttributes()throws {
        let html = "<a one two three four>Text</a>"
        let doc = try SwiftSoup.parse(html)
        let a: Element = try doc.select("a").first()!
       try a.removeAttr("zero")
            .removeAttr("one")
            .removeAttr("two")
            .removeAttr("three")
            .removeAttr("four")
            .removeAttr("five");
        XCTAssertEqual("<a>Text</a>", try a.outerHtml());
    }
    
    func testIs()throws {
        let html = "<div><p>One <a class=big>Two</a> Three</p><p>Another</p>"
        let doc: Document = try SwiftSoup.parse(html)
        let p: Element = try doc.select("p").first()!
        
        try XCTAssertTrue(p.iS("p"));
        try XCTAssertFalse(p.iS("div"));
        try XCTAssertTrue(p.iS("p:has(a)"));
        try XCTAssertTrue(p.iS("p:first-child"));
        try XCTAssertFalse(p.iS("p:last-child"));
        try XCTAssertTrue(p.iS("*"));
        try XCTAssertTrue(p.iS("div p"));
        
        let q: Element = try doc.select("p").last()!
        try XCTAssertTrue(q.iS("p"));
        try XCTAssertTrue(q.iS("p ~ p"));
        try XCTAssertTrue(q.iS("p + p"));
        try XCTAssertTrue(q.iS("p:last-child"));
        try XCTAssertFalse(q.iS("p a"));
        try XCTAssertFalse(q.iS("a"));
    }



	static var allTests = {
		return [
			("testGetElementsByTagName", testGetElementsByTagName),
			("testGetNamespacedElementsByTag", testGetNamespacedElementsByTag),
			("testGetElementById", testGetElementById),
			("testGetText", testGetText),
			("testGetChildText", testGetChildText),
			("testNormalisesText", testNormalisesText),
			("testKeepsPreText", testKeepsPreText),
			("testKeepsPreTextInCode", testKeepsPreTextInCode),
			("testBrHasSpace", testBrHasSpace),
			("testGetSiblings", testGetSiblings),
			("testGetSiblingsWithDuplicateContent", testGetSiblingsWithDuplicateContent),
			("testGetParents", testGetParents),
			("testElementSiblingIndex", testElementSiblingIndex),
			("testElementSiblingIndexSameContent", testElementSiblingIndexSameContent),
			("testGetElementsWithClass", testGetElementsWithClass),
			("testGetElementsWithAttribute", testGetElementsWithAttribute),
			("testGetElementsWithAttributeDash", testGetElementsWithAttributeDash),
			("testGetElementsWithAttributeValue", testGetElementsWithAttributeValue),
			("testClassDomMethods", testClassDomMethods),
			("testHasClassDomMethods", testHasClassDomMethods),
			("testClassUpdates", testClassUpdates),
			("testOuterHtml", testOuterHtml),
			("testInnerHtml", testInnerHtml),
			("testFormatHtml", testFormatHtml),
			("testFormatOutline", testFormatOutline),
			("testSetIndent", testSetIndent),
			("testNotPretty", testNotPretty),
			("testEmptyElementFormatHtml", testEmptyElementFormatHtml),
			("testNoIndentOnScriptAndStyle", testNoIndentOnScriptAndStyle),
			("testContainerOutput", testContainerOutput),
			("testSetText", testSetText),
			("testAddNewElement", testAddNewElement),
			("testAddBooleanAttribute", testAddBooleanAttribute),
			("testAppendRowToTable", testAppendRowToTable),
			("testPrependRowToTable", testPrependRowToTable),
			("testPrependElement", testPrependElement),
			("testAddNewText", testAddNewText),
			("testPrependText", testPrependText),
			("testAddNewHtml", testAddNewHtml),
			("testPrependNewHtml", testPrependNewHtml),
			("testSetHtml", testSetHtml),
			("testSetHtmlTitle", testSetHtmlTitle),
			("testWrap", testWrap),
			("testBefore", testBefore),
			("testAfter", testAfter),
			("testWrapWithRemainder", testWrapWithRemainder),
			("testHasText", testHasText),
			("testDataset", testDataset),
			("testpParentlessToString", testpParentlessToString),
			("testClone", testClone),
			("testClonesClassnames", testClonesClassnames),
			("testTagNameSet", testTagNameSet),
			("testHtmlContainsOuter", testHtmlContainsOuter),
			("testGetTextNodes", testGetTextNodes),
			("testManipulateTextNodes", testManipulateTextNodes),
			("testGetDataNodes", testGetDataNodes),
			("testElementIsNotASiblingOfItself", testElementIsNotASiblingOfItself),
			("testChildThrowsIndexOutOfBoundsOnMissing", testChildThrowsIndexOutOfBoundsOnMissing),
			("testMoveByAppend", testMoveByAppend),
			("testInsertChildrenArgumentValidation", testInsertChildrenArgumentValidation),
			("testInsertChildrenAtPosition", testInsertChildrenAtPosition),
			("testInsertChildrenAsCopy", testInsertChildrenAsCopy),
			("testCssPath", testCssPath),
			("testClassNames", testClassNames),
			("testHashAndEqualsAndValue", testHashAndEqualsAndValue),
			("testRelativeUrls", testRelativeUrls),
			("testAppendMustCorrectlyMoveChildrenInsideOneParentElement", testAppendMustCorrectlyMoveChildrenInsideOneParentElement),
			("testHashcodeIsStableWithContentChanges", testHashcodeIsStableWithContentChanges),
			("testNamespacedElements", testNamespacedElements),
			("testChainedRemoveAttributes",testChainedRemoveAttributes),
			("testIs",testIs)
		]
	}()
}
