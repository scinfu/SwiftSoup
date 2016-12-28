//
//  NodeTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 17/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
import SwiftSoup

class NodeTest: XCTestCase {

	func testHandlesBaseUri() {
		do {
			let tag: Tag = try Tag.valueOf("a")
			let attribs: Attributes = Attributes()
			try attribs.put("relHref", "/foo")
			try attribs.put("absHref", "http://bar/qux")

			let noBase: Element = Element(tag, "", attribs)
			XCTAssertEqual("", try noBase.absUrl("relHref")) // with no base, should NOT fallback to href attrib, whatever it is
			XCTAssertEqual("http://bar/qux", try noBase.absUrl("absHref")) // no base but valid attrib, return attrib

			let withBase: Element = Element(tag, "http://foo/", attribs)
			XCTAssertEqual("http://foo/foo", try withBase.absUrl("relHref")) // construct abs from base + rel
			XCTAssertEqual("http://bar/qux", try withBase.absUrl("absHref")) // href is abs, so returns that
			XCTAssertEqual("", try withBase.absUrl("noval"))

			let dodgyBase: Element = Element(tag, "wtf://no-such-protocol/", attribs)
			XCTAssertEqual("http://bar/qux", try dodgyBase.absUrl("absHref")) // base fails, but href good, so get that
			//TODO:Nabil in swift an url with scheme wtf is valid , find a method to validate schemes
			//XCTAssertEqual("", try dodgyBase.absUrl("relHref")); // base fails, only rel href, so return nothing
		} catch {
			XCTAssertEqual(1, 2)
		}

	}

	func testSetBaseUriIsRecursive() {
		do {
			let doc: Document = try SwiftSoup.parse("<div><p></p></div>")
			let baseUri: String = "https://jsoup.org"
			try doc.setBaseUri(baseUri)

			XCTAssertEqual(baseUri, doc.getBaseUri())
			XCTAssertEqual(baseUri, try doc.select("div").first()?.getBaseUri())
			XCTAssertEqual(baseUri, try doc.select("p").first()?.getBaseUri())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testHandlesAbsPrefix() {
		do {
			let doc: Document = try SwiftSoup.parse("<a href=/foo>Hello</a>", "https://jsoup.org/")
			let a: Element? = try doc.select("a").first()
			XCTAssertEqual("/foo", try a?.attr("href"))
			XCTAssertEqual("https://jsoup.org/foo", try a?.attr("abs:href"))
			//XCTAssertTrue(a!.hasAttr("abs:href"));//TODO:nabil
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testHandlesAbsOnImage() {
		do {
			let doc: Document = try SwiftSoup.parse("<p><img src=\"/rez/osi_logo.png\" /></p>", "https://jsoup.org/")
			let img: Element? = try doc.select("img").first()
			XCTAssertEqual("https://jsoup.org/rez/osi_logo.png", try img?.attr("abs:src"))
			XCTAssertEqual(try img?.absUrl("src"), try img?.attr("abs:src"))
		} catch {
			XCTAssertEqual(1, 2)
		}

	}

	func testHandlesAbsPrefixOnHasAttr() {
		do {
			// 1: no abs url; 2: has abs url
			let doc: Document = try SwiftSoup.parse("<a id=1 href='/foo'>One</a> <a id=2 href='https://jsoup.org/'>Two</a>")
			let one: Element = try doc.select("#1").first()!
			let two: Element = try doc.select("#2").first()!

			XCTAssertFalse(one.hasAttr("abs:href"))
			XCTAssertTrue(one.hasAttr("href"))
			XCTAssertEqual("", try one.absUrl("href"))

			XCTAssertTrue(two.hasAttr("abs:href"))
			XCTAssertTrue(two.hasAttr("href"))
			XCTAssertEqual("https://jsoup.org/", try two.absUrl("href"))
		} catch {
			XCTAssertEqual(1, 2)
		}

	}

	func testLiteralAbsPrefix() {
		do {
			// if there is a literal attribute "abs:xxx", don't try and make absolute.
			let doc: Document = try SwiftSoup.parse("<a abs:href='odd'>One</a>")
			let el: Element = try doc.select("a").first()!
			XCTAssertTrue(el.hasAttr("abs:href"))
			XCTAssertEqual("odd", try el.attr("abs:href"))
		} catch {
			XCTAssertEqual(1, 2)
		}

	}
	//TODO:Nabil
/*
	func testHandleAbsOnFileUris() {
		do{
			let doc: Document = try Jsoup.parse("<a href='password'>One/a><a href='/var/log/messages'>Two</a>", "file:/etc/");
			let one: Element = try doc.select("a").first()!;
			XCTAssertEqual("file:/etc/password", try one.absUrl("href"));
			let two: Element = try doc.select("a").get(1);
			XCTAssertEqual("file:/var/log/messages", try two.absUrl("href"));
		}catch{
			XCTAssertEqual(1,2)
		}
	}
*/
	func testHandleAbsOnLocalhostFileUris() {
		do {
			let doc: Document  = try SwiftSoup.parse("<a href='password'>One/a><a href='/var/log/messages'>Two</a>", "file://localhost/etc/")
			let one: Element? = try doc.select("a").first()
			XCTAssertEqual("file://localhost/etc/password", try one?.absUrl("href"))
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testHandlesAbsOnProtocolessAbsoluteUris() {
		do {
			let doc1: Document = try SwiftSoup.parse("<a href='//example.net/foo'>One</a>", "http://example.com/")
			let doc2: Document = try SwiftSoup.parse("<a href='//example.net/foo'>One</a>", "https://example.com/")

			let one: Element? = try doc1.select("a").first()
			let two: Element? = try doc2.select("a").first()

			XCTAssertEqual("http://example.net/foo", try one?.absUrl("href"))
			XCTAssertEqual("https://example.net/foo", try two?.absUrl("href"))

			let doc3: Document = try SwiftSoup.parse("<img src=//www.google.com/images/errors/logo_sm.gif alt=Google>", "https://google.com")
			XCTAssertEqual("https://www.google.com/images/errors/logo_sm.gif", try doc3.select("img").attr("abs:src"))
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testAbsHandlesRelativeQuery() {
		do {
			let doc: Document = try SwiftSoup.parse("<a href='?foo'>One</a> <a href='bar.html?foo'>Two</a>", "https://jsoup.org/path/file?bar")

			let a1: Element? = try doc.select("a").first()
			XCTAssertEqual("https://jsoup.org/path/file?foo", try a1?.absUrl("href"))

			let a2: Element? = try doc.select("a").get(1)
			XCTAssertEqual("https://jsoup.org/path/bar.html?foo", try a2?.absUrl("href"))
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testAbsHandlesDotFromIndex() {
		do {
			let doc: Document = try SwiftSoup.parse("<a href='./one/two.html'>One</a>", "http://example.com")
			let a1: Element? = try doc.select("a").first()
			XCTAssertEqual("http://example.com/one/two.html", try a1?.absUrl("href"))
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testRemove() {
		do {
			let doc: Document = try SwiftSoup.parse("<p>One <span>two</span> three</p>")
			let p: Element? = try doc.select("p").first()
			try p?.childNode(0).remove()

			XCTAssertEqual("two three", try p?.text())
			XCTAssertEqual("<span>two</span> three", TextUtil.stripNewlines(try p!.html()))
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testReplace() {
		do {
			let doc: Document = try SwiftSoup.parse("<p>One <span>two</span> three</p>")
			let p: Element? = try doc.select("p").first()
			let insert: Element = try doc.createElement("em").text("foo")
			try p?.childNode(1).replaceWith(insert)

			XCTAssertEqual("One <em>foo</em> three", try p?.html())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testOwnerDocument() {
		do {
			let doc: Document = try SwiftSoup.parse("<p>Hello")
			let p: Element? = try doc.select("p").first()
			XCTAssertTrue(p?.ownerDocument() == doc)
			XCTAssertTrue(doc.ownerDocument() == doc)
			XCTAssertNil(doc.parent())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testBefore() {
		do {
			let doc: Document = try SwiftSoup.parse("<p>One <b>two</b> three</p>")
			let newNode: Element =  Element(try Tag.valueOf("em"), "")
			try newNode.appendText("four")

			try doc.select("b").first()?.before(newNode)
			XCTAssertEqual("<p>One <em>four</em><b>two</b> three</p>", try doc.body()?.html())

			try doc.select("b").first()?.before("<i>five</i>")
			XCTAssertEqual("<p>One <em>four</em><i>five</i><b>two</b> three</p>", try doc.body()?.html())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testAfter() {
		do {
			let doc: Document = try SwiftSoup.parse("<p>One <b>two</b> three</p>")
			let newNode: Element = Element(try Tag.valueOf("em"), "")
			try newNode.appendText("four")

			try _ = doc.select("b").first()?.after(newNode)
			XCTAssertEqual("<p>One <b>two</b><em>four</em> three</p>", try doc.body()?.html())

			try doc.select("b").first()?.after("<i>five</i>")
			XCTAssertEqual("<p>One <b>two</b><i>five</i><em>four</em> three</p>", try doc.body()?.html())
		} catch {
			XCTAssertEqual(1, 2)
		}

	}

	func testUnwrap() {
		do {
			let doc: Document = try SwiftSoup.parse("<div>One <span>Two <b>Three</b></span> Four</div>")
			let span: Element? = try doc.select("span").first()
			let twoText: Node? = span?.childNode(0)
			let node: Node? = try span?.unwrap()

			XCTAssertEqual("<div>One Two <b>Three</b> Four</div>", TextUtil.stripNewlines(try doc.body()!.html()))
			XCTAssertTrue(((node as? TextNode) != nil))
			XCTAssertEqual("Two ", (node as? TextNode)?.text())
			XCTAssertEqual(node, twoText)
			XCTAssertEqual(node?.parent(), try doc.select("div").first())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testUnwrapNoChildren() {
		do {
			let doc: Document = try SwiftSoup.parse("<div>One <span></span> Two</div>")
			let span: Element? = try doc.select("span").first()
			let node: Node? = try span?.unwrap()
			XCTAssertEqual("<div>One  Two</div>", TextUtil.stripNewlines(try doc.body()!.html()))
			XCTAssertTrue(node == nil)
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testTraverse() {
		do {
			let doc: Document = try SwiftSoup.parse("<div><p>Hello</p></div><div>There</div>")
			let accum: StringBuilder = StringBuilder()
			class nv: NodeVisitor {
				let accum: StringBuilder
				init (_ accum: StringBuilder) {
					self.accum = accum
				}
				func head(_ node: Node, _ depth: Int)throws {
					accum.append("<" + node.nodeName() + ">")
				}
				func tail(_ node: Node, _ depth: Int)throws {
					accum.append("</" + node.nodeName() + ">")
				}
			}
			try doc.select("div").first()?.traverse(nv(accum))
			XCTAssertEqual("<div><p><#text></#text></p></div>", accum.toString())

		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testOrphanNodeReturnsNullForSiblingElements() {
		do {
			let node: Node = Element(try Tag.valueOf("p"), "")
			let el: Element = Element(try Tag.valueOf("p"), "")

			XCTAssertEqual(0, node.siblingIndex)
			XCTAssertEqual(0, node.siblingNodes().count)

			XCTAssertNil(node.previousSibling())
			XCTAssertNil(node.nextSibling())

			XCTAssertEqual(0, el.siblingElements().size())
			XCTAssertNil(try el.previousElementSibling())
			XCTAssertNil(try el.nextElementSibling())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testNodeIsNotASiblingOfItself() {
		do {
			let doc: Document = try SwiftSoup.parse("<div><p>One<p>Two<p>Three</div>")
			let p2: Element = try doc.select("p").get(1)

			XCTAssertEqual("Two", try p2.text())
			let nodes = p2.siblingNodes()
			XCTAssertEqual(2, nodes.count)
			XCTAssertEqual("<p>One</p>", try nodes[0].outerHtml())
			XCTAssertEqual("<p>Three</p>", try nodes[1].outerHtml())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testChildNodesCopy() {
		do {
			let doc: Document = try SwiftSoup.parse("<div id=1>Text 1 <p>One</p> Text 2 <p>Two<p>Three</div><div id=2>")
			let div1: Element? = try doc.select("#1").first()
			let div2: Element? = try doc.select("#2").first()
			let divChildren = div1?.childNodesCopy()
			XCTAssertEqual(5, divChildren?.count)
			let tn1: TextNode? = div1?.childNode(0) as? TextNode
			let tn2: TextNode? = divChildren?[0] as? TextNode
			tn2?.text("Text 1 updated")
			XCTAssertEqual("Text 1 ", tn1?.text())
			try div2?.insertChildren(-1, divChildren!)
			XCTAssertEqual("<div id=\"1\">Text 1 <p>One</p> Text 2 <p>Two</p><p>Three</p></div><div id=\"2\">Text 1 updated"+"<p>One</p> Text 2 <p>Two</p><p>Three</p></div>", TextUtil.stripNewlines(try doc.body()!.html()))
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testSupportsClone() {
		do {
			let doc: Document = try SwiftSoup.parse("<div class=foo>Text</div>")
			let el: Element = try doc.select("div").first()!
			XCTAssertTrue(el.hasClass("foo"))

			let elClone: Element = try (doc.copy() as! Document).select("div").first()!
			XCTAssertTrue(elClone.hasClass("foo"))
			XCTAssertTrue(try elClone.text() == "Text")

			try el.removeClass("foo")
			try el.text("None")
			XCTAssertFalse(el.hasClass("foo"))
			XCTAssertTrue(elClone.hasClass("foo"))
			XCTAssertTrue(try el.text() == "None")
			XCTAssertTrue(try elClone.text()=="Text")
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	static var allTests = {
		return [
			("testHandlesBaseUri", testHandlesBaseUri),
			("testSetBaseUriIsRecursive", testSetBaseUriIsRecursive),
			("testHandlesAbsPrefix", testHandlesAbsPrefix),
			("testHandlesAbsOnImage", testHandlesAbsOnImage),
			("testHandlesAbsPrefixOnHasAttr", testHandlesAbsPrefixOnHasAttr),
			("testLiteralAbsPrefix", testLiteralAbsPrefix),
			("testHandleAbsOnLocalhostFileUris", testHandleAbsOnLocalhostFileUris),
			 ("testHandlesAbsOnProtocolessAbsoluteUris", testHandlesAbsOnProtocolessAbsoluteUris),
			 ("testAbsHandlesRelativeQuery", testAbsHandlesRelativeQuery),
			 ("testAbsHandlesDotFromIndex", testAbsHandlesDotFromIndex),
			 ("testRemove", testRemove),
			 ("testReplace", testReplace),
			 ("testOwnerDocument", testOwnerDocument),
			 ("testBefore", testBefore),
			 ("testAfter", testAfter),
			 ("testUnwrap", testUnwrap),
			 ("testUnwrapNoChildren", testUnwrapNoChildren),
			 ("testTraverse", testTraverse),
			 ("testOrphanNodeReturnsNullForSiblingElements", testOrphanNodeReturnsNullForSiblingElements),
			 ("testNodeIsNotASiblingOfItself", testNodeIsNotASiblingOfItself),
			 ("testChildNodesCopy", testChildNodesCopy),
			 ("testSupportsClone", testSupportsClone)
		]
	}()
}
