//
//  XmlTreeBuilderTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
import SwiftSoup

class XmlTreeBuilderTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

	func testSimpleXmlParse()throws {
		let xml = "<doc id=2 href='/bar'>Foo <br /><link>One</link><link>Two</link></doc>"
		let treeBuilder: XmlTreeBuilder = XmlTreeBuilder()
		let doc: Document = try treeBuilder.parse(xml, "http://foo.com/")
		XCTAssertEqual("<doc id=\"2\" href=\"/bar\">Foo <br /><link>One</link><link>Two</link></doc>",
                       try TextUtil.stripNewlines(doc.html()))
		XCTAssertEqual(try doc.getElementById("2")?.absUrl("href"), "http://foo.com/bar")
	}

	func testPopToClose()throws {
		// test: </val> closes Two, </bar> ignored
		let xml = "<doc><val>One<val>Two</val></bar>Three</doc>"
		let treeBuilder: XmlTreeBuilder = XmlTreeBuilder()
		let doc = try treeBuilder.parse(xml, "http://foo.com/")
		XCTAssertEqual("<doc><val>One<val>Two</val>Three</val></doc>", try TextUtil.stripNewlines(doc.html()))
	}

	func testCommentAndDocType()throws {
		let xml = "<!DOCTYPE HTML><!-- a comment -->One <qux />Two"
		let treeBuilder: XmlTreeBuilder = XmlTreeBuilder()
		let doc = try treeBuilder.parse(xml, "http://foo.com/")
		XCTAssertEqual("<!DOCTYPE HTML><!-- a comment -->One <qux />Two", try TextUtil.stripNewlines(doc.html()))
	}

	func testSupplyParserToJsoupClass()throws {
		let xml = "<doc><val>One<val>Two</val></bar>Three</doc>"
		let doc = try SwiftSoup.parse(xml, "http://foo.com/", Parser.xmlParser())
		try XCTAssertEqual("<doc><val>One<val>Two</val>Three</val></doc>", TextUtil.stripNewlines(doc.html()))
	}

	//TODO: nabil
	//	public void testSupplyParserToConnection() throws IOException {
	//	String xmlUrl = "http://direct.infohound.net/tools/jsoup-xml-test.xml";
	//
	//	// parse with both xml and html parser, ensure different
	//	Document xmlDoc = Jsoup.connect(xmlUrl).parser(Parser.xmlParser()).get();
	//	Document htmlDoc = Jsoup.connect(xmlUrl).parser(Parser.htmlParser()).get();
	//	Document autoXmlDoc = Jsoup.connect(xmlUrl).get(); // check connection auto detects xml, uses xml parser
	//
	//	XCTAssertEqual("<doc><val>One<val>Two</val>Three</val></doc>",
	//	TextUtil.stripNewlines(xmlDoc.html()));
	//	assertFalse(htmlDoc.equals(xmlDoc));
	//	XCTAssertEqual(xmlDoc, autoXmlDoc);
	//	XCTAssertEqual(1, htmlDoc.select("head").size()); // html parser normalises
	//	XCTAssertEqual(0, xmlDoc.select("head").size()); // xml parser does not
	//	XCTAssertEqual(0, autoXmlDoc.select("head").size()); // xml parser does not
	//	}

	//TODO: nabil
//	func testSupplyParserToDataStream()throws {
//		let testBundle = Bundle(for: type(of: self))
//		let fileURL = testBundle.url(forResource: "xml-test", withExtension: "xml")
//		File xmlFile = new File(XmlTreeBuilder.class.getResource("/htmltests/xml-test.xml").toURI());
//		InputStream inStream = new FileInputStream(xmlFile);
//		let doc = Jsoup.parse(inStream, null, "http://foo.com", Parser.xmlParser());
//		XCTAssertEqual("<doc><val>One<val>Two</val>Three</val></doc>",
//		               TextUtil.stripNewlines(doc.html()));
//	}

	func testDoesNotForceSelfClosingKnownTags()throws {
		// html will force "<br>one</br>" to logically "<br />One<br />".
        // XML should be stay "<br>one</br> -- don't recognise tag.
		let htmlDoc = try SwiftSoup.parse("<br>one</br>")
		XCTAssertEqual("<br>one\n<br>", try htmlDoc.body()?.html())

		let xmlDoc = try SwiftSoup.parse("<br>one</br>", "", Parser.xmlParser())
		XCTAssertEqual("<br>one</br>", try xmlDoc.html())
	}

	func testHandlesXmlDeclarationAsDeclaration()throws {
		let html = "<?xml encoding='UTF-8' ?><body>One</body><!-- comment -->"
		let doc = try SwiftSoup.parse(html, "", Parser.xmlParser())
		try XCTAssertEqual("<?xml encoding=\"UTF-8\"?> <body> One </body> <!-- comment -->",
                           StringUtil.normaliseWhitespace(doc.outerHtml()))
		XCTAssertEqual("#declaration", doc.childNode(0).nodeName())
		XCTAssertEqual("#comment", doc.childNode(2).nodeName())
	}

	func testXmlFragment()throws {
		let xml = "<one src='/foo/' />Two<three><four /></three>"
		let nodes: [Node] = try Parser.parseXmlFragment(xml, "http://example.com/")
		XCTAssertEqual(3, nodes.count)

		try XCTAssertEqual("http://example.com/foo/", nodes[0].absUrl("src"))
		XCTAssertEqual("one", nodes[0].nodeName())
		XCTAssertEqual("Two", (nodes[1] as? TextNode)?.text())
	}

	func testXmlParseDefaultsToHtmlOutputSyntax()throws {
		let doc = try SwiftSoup.parse("x", "", Parser.xmlParser())
		XCTAssertEqual(OutputSettings.Syntax.xml, doc.outputSettings().syntax())
	}

	func testDoesHandleEOFInTag()throws {
		let html = "<img src=asdf onerror=\"alert(1)\" x="
		let xmlDoc = try SwiftSoup.parse(html, "", Parser.xmlParser())
		try XCTAssertEqual("<img src=\"asdf\" onerror=\"alert(1)\" x=\"\" />", xmlDoc.html())
	}
	//todo:
//		func testDetectCharsetEncodingDeclaration()throws{
//		File xmlFile = new File(XmlTreeBuilder.class.getResource("/htmltests/xml-charset.xml").toURI());
//		InputStream inStream = new FileInputStream(xmlFile);
//		let doc = Jsoup.parse(inStream, null, "http://example.com/", Parser.xmlParser());
//		XCTAssertEqual("ISO-8859-1", doc.charset().name());
//		XCTAssertEqual("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?> <data>äöåéü</data>",
//		TextUtil.stripNewlines(doc.html()));
//		}

	func testParseDeclarationAttributes()throws {
		let xml = "<?xml version='1' encoding='UTF-8' something='else'?><val>One</val>"
		let doc = try SwiftSoup.parse(xml, "", Parser.xmlParser())
        guard let decl: XmlDeclaration =  doc.childNode(0) as? XmlDeclaration else {
            XCTAssertTrue(false)
            return
        }
		try XCTAssertEqual("1", decl.attr("version"))
		try XCTAssertEqual("UTF-8", decl.attr("encoding"))
		try XCTAssertEqual("else", decl.attr("something"))
		try XCTAssertEqual("version=\"1\" encoding=\"UTF-8\" something=\"else\"", decl.getWholeDeclaration())
		try XCTAssertEqual("<?xml version=\"1\" encoding=\"UTF-8\" something=\"else\"?>", decl.outerHtml())
	}

	func testCaseSensitiveDeclaration()throws {
		let xml = "<?XML version='1' encoding='UTF-8' something='else'?>"
		let doc = try SwiftSoup.parse(xml, "", Parser.xmlParser())
		try XCTAssertEqual("<?XML version=\"1\" encoding=\"UTF-8\" something=\"else\"?>", doc.outerHtml())
	}

	func testCreatesValidProlog()throws {
		let document = Document.createShell("")
		document.outputSettings().syntax(syntax: OutputSettings.Syntax.xml)
		try document.charset(String.Encoding.utf8)
		try XCTAssertEqual("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
			"<html>\n" +
			" <head></head>\n" +
			" <body></body>\n" +
			"</html>", document.outerHtml())
	}

	func testPreservesCaseByDefault()throws {
		let xml = "<TEST ID=1>Check</TEST>"
		let doc = try SwiftSoup.parse(xml, "", Parser.xmlParser())
		try XCTAssertEqual("<TEST ID=\"1\">Check</TEST>", TextUtil.stripNewlines(doc.html()))
	}

	func testCanNormalizeCase()throws {
		let xml = "<TEST ID=1>Check</TEST>"
		let doc = try  SwiftSoup.parse(xml, "", Parser.xmlParser().settings(ParseSettings.htmlDefault))
		try XCTAssertEqual("<test id=\"1\">Check</test>", TextUtil.stripNewlines(doc.html()))
	}

    func testNilReplaceInQueue()throws {
        let html: String = "<TABLE><TBODY><TR><TD></TD><TD><FONT color=#000000 size=1><I><FONT size=5><P align=center></FONT></I></FONT>&nbsp;</P></TD></TR></TBODY></TABLE></TD></TR></TBODY></TABLE></DIV></DIV></DIV><BLOCKQUOTE></BLOCKQUOTE><DIV style=\"FONT: 10pt Courier New\"><BR><BR>&nbsp;</DIV></BODY></HTML>"
        _ = try SwiftSoup.parse(html)
    }

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testSimpleXmlParse", testSimpleXmlParse),
			("testPopToClose", testPopToClose),
			("testCommentAndDocType", testCommentAndDocType),
			("testSupplyParserToJsoupClass", testSupplyParserToJsoupClass),
			("testDoesNotForceSelfClosingKnownTags", testDoesNotForceSelfClosingKnownTags),
			("testHandlesXmlDeclarationAsDeclaration", testHandlesXmlDeclarationAsDeclaration),
			("testXmlFragment", testXmlFragment),
			("testXmlParseDefaultsToHtmlOutputSyntax", testXmlParseDefaultsToHtmlOutputSyntax),
			("testDoesHandleEOFInTag", testDoesHandleEOFInTag),
			("testParseDeclarationAttributes", testParseDeclarationAttributes),
			("testCaseSensitiveDeclaration", testCaseSensitiveDeclaration),
			("testCreatesValidProlog", testCreatesValidProlog),
			("testPreservesCaseByDefault", testPreservesCaseByDefault),
			("testCanNormalizeCase", testCanNormalizeCase),
            ("testNilReplaceInQueue", testNilReplaceInQueue)
		]
	}()

}
