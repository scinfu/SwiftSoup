//
//  SwiftSoupTests.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/12/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class SwiftSoupTests: XCTestCase {
        
    override func setUp() {
        super.setUp()
        
//        // Put setup code here. This method is called before the invocation of each test method in the class.
//        
//        // In UI tests it is usually best to stop immediately when a failure occurs.
//        continueAfterFailure = false
//        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
//        XCUIApplication().launch()
//
//        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	private func createHtmlDocument(_ charset: String)->Document {
		let doc: Document = Document.createShell("");
		try! doc.head()?.appendElement("meta").attr("charset", charset);
		try! doc.head()?.appendElement("meta").attr("name", "charset").attr("content", charset);
		return doc;
	}
	//average: 58.562,
	//passed (586.015 seconds)
//	func testPerformanceExample() {
//		let h: String = "<!doctype html>\n" +
//			"<html>\n" +
//			" <head></head>\n" +
//			" <body>\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"  <img async checked src=\"&amp;<>&quot;\">&lt;&gt;&amp;\"\n" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"<div id=div1><p>Hello</p><p>Another <b>element</b></p><div id=div2><img src=foo.png></div></div>" +
//			"  <foo />bar\n" +
//			" </body>\n" +
//		"</html>"
//		self.measure {
//			do {
//				for _ in 0...1000{
//					let doc: Document = try! SwiftSoup.parse(h);
//					doc.updateMetaCharsetElement(true);
//					try doc.charset(String.Encoding.isoLatin2);
//					
//					_ = try doc.toString()
//					
//					let selectedElement: Element = try doc.select("meta[charset]").first()!;
//					_ = doc.charset().displayName()
//					_ = try selectedElement.attr("charset")
//					_ = doc.outputSettings().charset()
//					_ = try doc.select("div")
//					_ = try doc.cssSelector()
//					_ = doc.firstElementSibling()
//					_ = try doc.getElementsByAttributeValueContaining("key", "mm")
//					_ = selectedElement.children()
//					_ = try selectedElement.after(" c ")
//					_ = try selectedElement.select("dd")
//				}
//			}
//			catch {
//			}
//		}
//	}
	//passed (390.343 seconds).

}
