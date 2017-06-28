//
//  DocumentTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 31/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
@testable import SwiftSoup

class DocumentTest: XCTestCase {

	private static let charsetUtf8 = String.Encoding.utf8
	private static let charsetIso8859 = String.Encoding.iso2022JP //"ISO-8859-1"
	
//	func testT()throws
//	{
//		do{
//			let html = "<!DOCTYPE html>" +
//				"<html>" +
//				"<head>" +
//				"<title>Some webpage</title>" +
//				"</head>" +
//				"<body>" +
//				"<p class='normal'>This is the first paragraph.</p>" +
//				"<p class='special'><b>this is in bold</b></p>" +
//				"</body>" +
//			"</html>";
//			
//			let doc: Document = try SwiftSoup.parse(html)
//			try doc.append("<p class='special'><b>this is in bold</b></p>")
//			try doc.append("<p class='special'><b>this is in bold</b></p>")
//			try doc.append("<p class='special'><b>this is in bold</b></p>")
//			try doc.append("<p class='special'><b>this is in bold</b></p>")
//			let els: Elements = try doc.getElementsByClass("special")
//			let special: Element? = els.first()//get first element
//			print(try special?.text())//"this is in bold"
//			print(special?.tagName())//"p"
//			print(special?.child(0).tag().getName())//"b"
//			
//			for el in els{
//				print(el)
//			}
//			
//		}catch Exception.Error(let type, let message)
//		{
//			print()
//		}catch{
//			print("")
//		}
//	}
	
	
	func testSetTextPreservesDocumentStructure() {
		do {
			let doc: Document = try SwiftSoup.parse("<p>Hello</p>")
			try doc.text("Replaced")
			XCTAssertEqual("Replaced", try doc.text())
			XCTAssertEqual("Replaced", try doc.body()!.text())
			XCTAssertEqual(1, try doc.select("head").size())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testTitles() {
		do {
			let noTitle: Document = try SwiftSoup.parse("<p>Hello</p>")
			let withTitle: Document = try SwiftSoup.parse("<title>First</title><title>Ignore</title><p>Hello</p>")

			XCTAssertEqual("", try noTitle.title())
			try noTitle.title("Hello")
			XCTAssertEqual("Hello", try noTitle.title())
			XCTAssertEqual("Hello", try noTitle.select("title").first()?.text())

			XCTAssertEqual("First", try withTitle.title())
			try withTitle.title("Hello")
			XCTAssertEqual("Hello", try withTitle.title())
			XCTAssertEqual("Hello", try withTitle.select("title").first()?.text())

			let normaliseTitle: Document = try SwiftSoup.parse("<title>   Hello\nthere   \n   now   \n")
			XCTAssertEqual("Hello there now", try normaliseTitle.title())
		} catch {

		}

	}

	func testOutputEncoding() {
		do {
			let doc: Document = try SwiftSoup.parse("<p title=π>π & < > </p>")
			// default is utf-8
			XCTAssertEqual("<p title=\"π\">π &amp; &lt; &gt; </p>", try doc.body()?.html())
			XCTAssertEqual("UTF-8", doc.outputSettings().charset().displayName())

			doc.outputSettings().charset(String.Encoding.ascii)
			XCTAssertEqual(Entities.EscapeMode.base, doc.outputSettings().escapeMode())
			XCTAssertEqual("<p title=\"&#x3c0;\">&#x3c0; &amp; &lt; &gt; </p>", try doc.body()?.html())

			doc.outputSettings().escapeMode(Entities.EscapeMode.extended)
			XCTAssertEqual("<p title=\"&pi;\">&pi; &amp; &lt; &gt; </p>", try doc.body()?.html())
		} catch {
			XCTAssertEqual(1, 2)
		}
	}

	func testXhtmlReferences() {
		let doc: Document = try! SwiftSoup.parse("&lt; &gt; &amp; &quot; &apos; &times;")
		doc.outputSettings().escapeMode(Entities.EscapeMode.xhtml)
		XCTAssertEqual("&lt; &gt; &amp; \" ' ×", try! doc.body()?.html())
	}

	func testNormalisesStructure() {
		let doc: Document = try! SwiftSoup.parse("<html><head><script>one</script><noscript><p>two</p></noscript></head><body><p>three</p></body><p>four</p></html>")
		XCTAssertEqual("<html><head><script>one</script><noscript>&lt;p&gt;two</noscript></head><body><p>three</p><p>four</p></body></html>", TextUtil.stripNewlines(try! doc.html()))
	}

	func testClone() {
		let doc: Document = try! SwiftSoup.parse("<title>Hello</title> <p>One<p>Two")
		let clone: Document = doc.copy() as! Document

		XCTAssertEqual("<html><head><title>Hello</title> </head><body><p>One</p><p>Two</p></body></html>", try! TextUtil.stripNewlines(clone.html()))
		try! clone.title("Hello there")
		try! clone.select("p").first()!.text("One more").attr("id", "1")
		XCTAssertEqual("<html><head><title>Hello there</title> </head><body><p id=\"1\">One more</p><p>Two</p></body></html>", try! TextUtil.stripNewlines(clone.html()))
		XCTAssertEqual("<html><head><title>Hello</title> </head><body><p>One</p><p>Two</p></body></html>", try! TextUtil.stripNewlines(doc.html()))
	}

	func testClonesDeclarations() {
		let doc: Document = try! SwiftSoup.parse("<!DOCTYPE html><html><head><title>Doctype test")
		let clone: Document = doc.copy() as! Document

		XCTAssertEqual(try! doc.html(), try! clone.html())
		XCTAssertEqual("<!doctype html><html><head><title>Doctype test</title></head><body></body></html>",
		               TextUtil.stripNewlines(try! clone.html()))
	}

	//todo:
	//	func testLocation()throws {
	//		File in = new ParseTest().getFile("/htmltests/yahoo-jp.html")
	//		Document doc = Jsoup.parse(in, "UTF-8", "http://www.yahoo.co.jp/index.html");
	//		String location = doc.location();
	//		String baseUri = doc.baseUri();
	//		assertEquals("http://www.yahoo.co.jp/index.html",location);
	//		assertEquals("http://www.yahoo.co.jp/_ylh=X3oDMTB0NWxnaGxsBF9TAzIwNzcyOTYyNjUEdGlkAzEyBHRtcGwDZ2Ex/",baseUri);
	//		in = new ParseTest().getFile("/htmltests/nyt-article-1.html");
	//		doc = Jsoup.parse(in, null, "http://www.nytimes.com/2010/07/26/business/global/26bp.html?hp");
	//		location = doc.location();
	//		baseUri = doc.baseUri();
	//		assertEquals("http://www.nytimes.com/2010/07/26/business/global/26bp.html?hp",location);
	//		assertEquals("http://www.nytimes.com/2010/07/26/business/global/26bp.html?hp",baseUri);
	//	}

	func testHtmlAndXmlSyntax() {
		let h: String = "<!DOCTYPE html><body><img async checked='checked' src='&<>\"'>&lt;&gt;&amp;&quot;<foo />bar"
		let doc: Document = try! SwiftSoup.parse(h)

		doc.outputSettings().syntax(syntax: OutputSettings.Syntax.html)
		XCTAssertEqual("<!doctype html>\n" +
			"<html>\n" +
			" <head></head>\n" +
			" <body>\n" +
			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
			"  <foo />bar\n" +
			" </body>\n" +
			"</html>", try! doc.html())

		doc.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)
		XCTAssertEqual("<!DOCTYPE html>\n" +
			"<html>\n" +
			" <head></head>\n" +
			" <body>\n" +
			"  <img async=\"\" checked=\"checked\" src=\"&amp;<>&quot;\" />&lt;&gt;&amp;\"\n" +
			"  <foo />bar\n" +
			" </body>\n" +
			"</html>", try! doc.html())
	}

	func testHtmlParseDefaultsToHtmlOutputSyntax() {
		let doc: Document = try! SwiftSoup.parse("x")
		XCTAssertEqual(OutputSettings.Syntax.html, doc.outputSettings().syntax())
	}

	func testHtmlAppendable() {
		let htmlContent: String = "<html><head><title>Hello</title></head><body><p>One</p><p>Two</p></body></html>"
		let document: Document = try! SwiftSoup.parse(htmlContent)
		let outputSettings: OutputSettings = OutputSettings()

		outputSettings.prettyPrint(pretty: false)
		document.outputSettings(outputSettings)
		XCTAssertEqual(htmlContent, try! document.html(StringBuilder()).toString())
	}

	//todo: // Ignored since this test can take awhile to run.
	//	func testOverflowClone() {
	//		let builder: StringBuilder = StringBuilder();
	//		for i in 0..<100000
	//		{
	//			builder.insert(0, "<i>");
	//			builder.append("</i>");
	//		}
	//		let doc: Document = try! Jsoup.parse(builder.toString());
	//		doc.copy();
	//	}

	func testDocumentsWithSameContentAreEqual() throws {
		let docA: Document = try SwiftSoup.parse("<div/>One")
		let docB: Document = try SwiftSoup.parse("<div/>One")
		_ = try SwiftSoup.parse("<div/>Two")

		XCTAssertFalse(docA.equals(docB))
		XCTAssertTrue(docA.equals(docA))
		//todo:
		//		XCTAssertEqual(docA.hashCode(), docA.hashCode());
		//		XCTAssertFalse(docA.hashCode() == docC.hashCode());
	}

	func testDocumentsWithSameContentAreVerifialbe() throws {
		let docA: Document = try SwiftSoup.parse("<div/>One")
		let docB: Document = try SwiftSoup.parse("<div/>One")
		let docC: Document = try SwiftSoup.parse("<div/>Two")

		XCTAssertTrue(try docA.hasSameValue(docB))
		XCTAssertFalse(try docA.hasSameValue(docC))
	}

	func testMetaCharsetUpdateUtf8() {
		let doc: Document = createHtmlDocument("changeThis")
		doc.updateMetaCharsetElement(true)
		do {
			try doc.charset(DocumentTest.charsetUtf8)
		} catch {
			print("")
		}

		let htmlCharsetUTF8: String = "<html>\n" + " <head>\n" + "  <meta charset=\"" + "UTF-8" + "\">\n" + " </head>\n" + " <body></body>\n" + "</html>"
		XCTAssertEqual(htmlCharsetUTF8, try! doc.outerHtml())

		let selectedElement: Element = try! doc.select("meta[charset]").first()!
		XCTAssertEqual(DocumentTest.charsetUtf8, doc.charset())
		XCTAssertEqual("UTF-8", try! selectedElement.attr("charset"))
		XCTAssertEqual(doc.charset(), doc.outputSettings().charset())

	}

	func testMetaCharsetUpdateIsoLatin2()throws {
		let doc: Document = createHtmlDocument("changeThis")
		doc.updateMetaCharsetElement(true)
		try doc.charset(String.Encoding.isoLatin2)

		let htmlCharsetISO = "<html>\n" +
			" <head>\n" +
			"  <meta charset=\"" + String.Encoding.isoLatin2.displayName() + "\">\n" +
			" </head>\n" +
			" <body></body>\n" +
		"</html>"
		XCTAssertEqual(htmlCharsetISO, try doc.outerHtml())

		let selectedElement: Element = try doc.select("meta[charset]").first()!
		XCTAssertEqual(String.Encoding.isoLatin2.displayName(), doc.charset().displayName())
		XCTAssertEqual(String.Encoding.isoLatin2.displayName(), try selectedElement.attr("charset"))
		XCTAssertEqual(doc.charset(), doc.outputSettings().charset())
	}

	func testMetaCharsetUpdateNoCharset()throws {
		let docNoCharset: Document = Document.createShell("")
		docNoCharset.updateMetaCharsetElement(true)
		try docNoCharset.charset(String.Encoding.utf8)

		try XCTAssertEqual(String.Encoding.utf8.displayName(), docNoCharset.select("meta[charset]").first()?.attr("charset"))

		let htmlCharsetUTF8 = "<html>\n" +
			" <head>\n" +
			"  <meta charset=\"" + String.Encoding.utf8.displayName() + "\">\n" +
			" </head>\n" +
			" <body></body>\n" +
		"</html>"
		try XCTAssertEqual(htmlCharsetUTF8, docNoCharset.outerHtml())
	}

	func testMetaCharsetUpdateDisabled()throws {
		let docDisabled: Document = Document.createShell("")

		let htmlNoCharset = "<html>\n" +
			" <head></head>\n" +
			" <body></body>\n" +
		"</html>"
		try XCTAssertEqual(htmlNoCharset, docDisabled.outerHtml())
		try XCTAssertNil(docDisabled.select("meta[charset]").first())
	}

	func testMetaCharsetUpdateDisabledNoChanges()throws {
		let doc: Document = createHtmlDocument("dontTouch")

		let htmlCharset = "<html>\n" +
			" <head>\n" +
			"  <meta charset=\"dontTouch\">\n" +
			"  <meta name=\"charset\" content=\"dontTouch\">\n" +
			" </head>\n" +
			" <body></body>\n" +
		"</html>"
		try XCTAssertEqual(htmlCharset, doc.outerHtml())

		var selectedElement: Element = try doc.select("meta[charset]").first()!
		XCTAssertNotNil(selectedElement)
		try XCTAssertEqual("dontTouch", selectedElement.attr("charset"))

		selectedElement = try doc.select("meta[name=charset]").first()!
		XCTAssertNotNil(selectedElement)
		try XCTAssertEqual("dontTouch", selectedElement.attr("content"))
	}

	func testMetaCharsetUpdateEnabledAfterCharsetChange()throws {
		let doc: Document = createHtmlDocument("dontTouch")
		try doc.charset(String.Encoding.utf8)

		let selectedElement: Element = try doc.select("meta[charset]").first()!
		try XCTAssertEqual(String.Encoding.utf8.displayName(), selectedElement.attr("charset"))
		try XCTAssertTrue(doc.select("meta[name=charset]").isEmpty())
	}

	func testMetaCharsetUpdateCleanup()throws {
		let doc: Document = createHtmlDocument("dontTouch")
		doc.updateMetaCharsetElement(true)
		try doc.charset(String.Encoding.utf8)

		let htmlCharsetUTF8 = "<html>\n" +
			" <head>\n" +
			"  <meta charset=\"" + String.Encoding.utf8.displayName() + "\">\n" +
			" </head>\n" +
			" <body></body>\n" +
		"</html>"

		try XCTAssertEqual(htmlCharsetUTF8, doc.outerHtml())
	}

	func testMetaCharsetUpdateXmlUtf8()throws {
		let doc: Document = try createXmlDocument("1.0", "changeThis", true)
		doc.updateMetaCharsetElement(true)
		try doc.charset(String.Encoding.utf8)

		let xmlCharsetUTF8 = "<?xml version=\"1.0\" encoding=\"" + String.Encoding.utf8.displayName() + "\"?>\n" +
			"<root>\n" +
			" node\n" +
		"</root>"
		try XCTAssertEqual(xmlCharsetUTF8, doc.outerHtml())

		let selectedNode: XmlDeclaration = doc.childNode(0) as! XmlDeclaration
		XCTAssertEqual(String.Encoding.utf8.displayName(), doc.charset().displayName())
		try XCTAssertEqual(String.Encoding.utf8.displayName(), selectedNode.attr("encoding"))
		XCTAssertEqual(doc.charset(), doc.outputSettings().charset())
	}

	func testMetaCharsetUpdateXmlIso2022JP()throws {
		let doc: Document = try createXmlDocument("1.0", "changeThis", true)
		doc.updateMetaCharsetElement(true)
		try doc.charset(String.Encoding.iso2022JP)

		let xmlCharsetISO = "<?xml version=\"1.0\" encoding=\"" + String.Encoding.iso2022JP.displayName() + "\"?>\n" +
			"<root>\n" +
			" node\n" +
		"</root>"
		try XCTAssertEqual(xmlCharsetISO, doc.outerHtml())

		let selectedNode: XmlDeclaration =  doc.childNode(0) as! XmlDeclaration
		XCTAssertEqual(String.Encoding.iso2022JP.displayName(), doc.charset().displayName())
		try XCTAssertEqual(String.Encoding.iso2022JP.displayName(), selectedNode.attr("encoding"))
		XCTAssertEqual(doc.charset(), doc.outputSettings().charset())
	}

	func testMetaCharsetUpdateXmlNoCharset()throws {
		let doc: Document = try createXmlDocument("1.0", "none", false)
		doc.updateMetaCharsetElement(true)
		try doc.charset(String.Encoding.utf8)

		let xmlCharsetUTF8 = "<?xml version=\"1.0\" encoding=\"" + String.Encoding.utf8.displayName() + "\"?>\n" +
			"<root>\n" +
			" node\n" +
		"</root>"
		try XCTAssertEqual(xmlCharsetUTF8, doc.outerHtml())

		let selectedNode: XmlDeclaration = doc.childNode(0) as! XmlDeclaration
		try XCTAssertEqual(String.Encoding.utf8.displayName(), selectedNode.attr("encoding"))
	}

	func testMetaCharsetUpdateXmlDisabled()throws {
		let doc: Document = try createXmlDocument("none", "none", false)

		let xmlNoCharset = "<root>\n" +
			" node\n" +
		"</root>"
		try XCTAssertEqual(xmlNoCharset, doc.outerHtml())
	}

	func testMetaCharsetUpdateXmlDisabledNoChanges()throws {
		let doc: Document = try createXmlDocument("dontTouch", "dontTouch", true)

		let xmlCharset = "<?xml version=\"dontTouch\" encoding=\"dontTouch\"?>\n" +
			"<root>\n" +
			" node\n" +
		"</root>"
		try XCTAssertEqual(xmlCharset, doc.outerHtml())

		let selectedNode: XmlDeclaration = doc.childNode(0) as! XmlDeclaration
		try XCTAssertEqual("dontTouch", selectedNode.attr("encoding"))
		try XCTAssertEqual("dontTouch", selectedNode.attr("version"))
	}

	func testMetaCharsetUpdatedDisabledPerDefault() {
		let doc: Document = createHtmlDocument("none")
		XCTAssertFalse(doc.updateMetaCharsetElement())
	}

	private func createHtmlDocument(_ charset: String) -> Document {
		let doc: Document = Document.createShell("")
		try! doc.head()?.appendElement("meta").attr("charset", charset)
		try! doc.head()?.appendElement("meta").attr("name", "charset").attr("content", charset)
		return doc
	}

	func createXmlDocument(_ version: String, _ charset: String, _ addDecl: Bool)throws->Document {
		let doc: Document = Document("")
		try doc.appendElement("root").text("node")
		doc.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)

		if( addDecl == true ) {
			let decl: XmlDeclaration = XmlDeclaration("xml", "", false)
			try decl.attr("version", version)
			try decl.attr("encoding", charset)
			try doc.prependChild(decl)
		}

		return doc
	}
    
    
    func testThai()
    {
        let str = "บังคับ"
        guard let doc = try? SwiftSoup.parse(str) else {
            XCTFail()
            return}
        guard let txt = try? doc.html() else {
            XCTFail()
            return}
        XCTAssertEqual("<html>\n <head></head>\n <body>\n  บังคับ\n </body>\n</html>", txt)
    }
    
	//todo:
//	func testShiftJisRoundtrip()throws {
//		let input =
//			"<html>"
//				+   "<head>"
//				+     "<meta http-equiv=\"content-type\" content=\"text/html; charset=Shift_JIS\" />"
//				+   "</head>"
//				+   "<body>"
//				+     "before&nbsp;after"
//				+   "</body>"
//				+ "</html>";
//		InputStream is = new ByteArrayInputStream(input.getBytes(Charset.forName("ASCII")));
//		
//		Document doc = Jsoup.parse(is, null, "http://example.com");
//		doc.outputSettings().escapeMode(Entities.EscapeMode.xhtml);
//		
//		String output = new String(doc.html().getBytes(doc.outputSettings().charset()), doc.outputSettings().charset());
//		
//		assertFalse("Should not have contained a '?'.", output.contains("?"));
//		assertTrue("Should have contained a '&#xa0;' or a '&nbsp;'.",
//		output.contains("&#xa0;") || output.contains("&nbsp;"));
//	}

	static var allTests = {
		return [
			("testSetTextPreservesDocumentStructure", testSetTextPreservesDocumentStructure),
			("testTitles", testTitles),
			("testOutputEncoding", testOutputEncoding),
			("testXhtmlReferences", testXhtmlReferences),
			("testNormalisesStructure", testNormalisesStructure),
			("testClone", testClone),
			("testClonesDeclarations", testClonesDeclarations),
			("testHtmlAndXmlSyntax", testHtmlAndXmlSyntax),
			("testHtmlParseDefaultsToHtmlOutputSyntax", testHtmlParseDefaultsToHtmlOutputSyntax),
			("testHtmlAppendable", testHtmlAppendable),
			("testDocumentsWithSameContentAreEqual", testDocumentsWithSameContentAreEqual),
			("testDocumentsWithSameContentAreVerifialbe", testDocumentsWithSameContentAreVerifialbe),
			("testMetaCharsetUpdateUtf8", testMetaCharsetUpdateUtf8),
			("testMetaCharsetUpdateIsoLatin2", testMetaCharsetUpdateIsoLatin2),
			("testMetaCharsetUpdateNoCharset", testMetaCharsetUpdateNoCharset),
			("testMetaCharsetUpdateDisabled", testMetaCharsetUpdateDisabled),
			("testMetaCharsetUpdateDisabledNoChanges", testMetaCharsetUpdateDisabledNoChanges),
			("testMetaCharsetUpdateEnabledAfterCharsetChange", testMetaCharsetUpdateEnabledAfterCharsetChange),
			("testMetaCharsetUpdateCleanup", testMetaCharsetUpdateCleanup),
			("testMetaCharsetUpdateXmlUtf8", testMetaCharsetUpdateXmlUtf8),
			("testMetaCharsetUpdateXmlIso2022JP", testMetaCharsetUpdateXmlIso2022JP),
			("testMetaCharsetUpdateXmlNoCharset", testMetaCharsetUpdateXmlNoCharset),
			("testMetaCharsetUpdateXmlDisabled", testMetaCharsetUpdateXmlDisabled),
			("testMetaCharsetUpdateXmlDisabledNoChanges", testMetaCharsetUpdateXmlDisabledNoChanges),
			("testMetaCharsetUpdatedDisabledPerDefault", testMetaCharsetUpdatedDisabledPerDefault),
			("testThai",testThai)
		]
	}()

}
