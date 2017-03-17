//
//  CleanerTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 13/01/17.
//  Copyright © 2017 Nabil Chatbi. All rights reserved.
//

import XCTest
@testable import SwiftSoup

class CleanerTest: XCTestCase {
    
    func testHandlesCustomProtocols()throws{
        let html = "<img src='cid:12345' /> <img src='data:gzzt' />"
//        let dropped = try SwiftSoup.clean(html, Whitelist.basicWithImages())
//        XCTAssertEqual("<img> \n<img>", dropped)
        
        let preserved = try SwiftSoup.clean(html, Whitelist.basicWithImages().addProtocols("img", "src", "cid", "data"))
        XCTAssertEqual("<img src=\"cid:12345\"> \n<img src=\"data:gzzt\">", preserved)
    }
    
    
    func testSimpleBehaviourTest()throws {
        let h = "<div><p class=foo><a href='http://evil.com'>Hello <b id=bar>there</b>!</a></div>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.simpleText())
        XCTAssertEqual("Hello <b>there</b>!", TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testSimpleBehaviourTest2()throws {
        let h = "Hello <b>there</b>!"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.simpleText())
        
        XCTAssertEqual("Hello <b>there</b>!", TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testBasicBehaviourTest()throws {
        let h = "<div><p><a href='javascript:sendAllMoney()'>Dodgy</a> <A HREF='HTTP://nice.com'>Nice</a></p><blockquote>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic())
        
        XCTAssertEqual("<p><a rel=\"nofollow\">Dodgy</a> <a href=\"HTTP://nice.com\" rel=\"nofollow\">Nice</a></p><blockquote>Hello</blockquote>",
                     TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testBasicWithImagesTest()throws {
        let h = "<div><p><img src='http://example.com/' alt=Image></p><p><img src='ftp://ftp.example.com'></p></div>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basicWithImages())
        XCTAssertEqual("<p><img src=\"http://example.com/\" alt=\"Image\"></p><p><img></p>", TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testRelaxed()throws {
        let h = "<h1>Head</h1><table><tr><td>One<td>Two</td></tr></table>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<h1>Head</h1><table><tbody><tr><td>One</td><td>Two</td></tr></tbody></table>", TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testRemoveTags()throws {
        let h = "<div><p><A HREF='HTTP://nice.com'>Nice</a></p><blockquote>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeTags("a"))
        
        XCTAssertEqual("<p>Nice</p><blockquote>Hello</blockquote>", TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testRemoveAttributes()throws{
        let h = "<div><p>Nice</p><blockquote cite='http://example.com/quotations'>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeAttributes("blockquote", "cite"))
        
        XCTAssertEqual("<p>Nice</p><blockquote>Hello</blockquote>", TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testRemoveEnforcedAttributes()throws{
        let h = "<div><p><A HREF='HTTP://nice.com'>Nice</a></p><blockquote>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeEnforcedAttribute("a", "rel"))
        
        XCTAssertEqual("<p><a href=\"HTTP://nice.com\">Nice</a></p><blockquote>Hello</blockquote>",
                     TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testRemoveProtocols()throws{
        let h = "<p>Contact me <a href='mailto:info@example.com'>here</a></p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeProtocols("a", "href", "ftp", "mailto"))
        
        XCTAssertEqual("<p>Contact me <a rel=\"nofollow\">here</a></p>",
                     TextUtil.stripNewlines(cleanHtml!))
    }
    
    func testDropComments()throws{
        let h = "<p>Hello<!-- no --></p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<p>Hello</p>", cleanHtml)
    }
    
    func testDropXmlProc()throws{
        let h = "<?import namespace=\"xss\"><p>Hello</p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<p>Hello</p>", cleanHtml)
    }
    
    func testDropScript()throws{
        let h = "<SCRIPT SRC=//ha.ckers.org/.j><SCRIPT>alert(/XSS/.source)</SCRIPT>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("", cleanHtml)
    }
    
    func testDropImageScript()throws{
        let h = "<IMG SRC=\"javascript:alert('XSS')\">"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<img>", cleanHtml)
    }
    
    func testCleanJavascriptHref()throws{
        let h = "<A HREF=\"javascript:document.location='http://www.google.com/'\">XSS</A>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<a>XSS</a>", cleanHtml)
    }
    
    func testCleanAnchorProtocol()throws{
        let validAnchor = "<a href=\"#valid\">Valid anchor</a>"
        let invalidAnchor = "<a href=\"#anchor with spaces\">Invalid anchor</a>"
        
        // A Whitelist that does not allow anchors will strip them out.
        var cleanHtml = try SwiftSoup.clean(validAnchor, Whitelist.relaxed())
        XCTAssertEqual("<a>Valid anchor</a>", cleanHtml)
        
        cleanHtml = try SwiftSoup.clean(invalidAnchor, Whitelist.relaxed())
        XCTAssertEqual("<a>Invalid anchor</a>", cleanHtml)
        
        // A Whitelist that allows them will keep them.
        let relaxedWithAnchor: Whitelist = try Whitelist.relaxed().addProtocols("a", "href", "#")
        
        cleanHtml = try SwiftSoup.clean(validAnchor, relaxedWithAnchor)
        XCTAssertEqual(validAnchor, cleanHtml)
        
        // An invalid anchor is never valid.
        cleanHtml = try SwiftSoup.clean(invalidAnchor, relaxedWithAnchor)
        XCTAssertEqual("<a>Invalid anchor</a>", cleanHtml)
    }
    
    func testDropsUnknownTags()throws{
        let h = "<p><custom foo=true>Test</custom></p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<p>Test</p>", cleanHtml)
    }
    
    func testtestHandlesEmptyAttributes()throws{
        let h = "<img alt=\"\" src= unknown=''>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basicWithImages())
        XCTAssertEqual("<img alt=\"\">", cleanHtml)
    }
    
    func testIsValid()throws{
        let ok = "<p>Test <b><a href='http://example.com/'>OK</a></b></p>"
        let nok1 = "<p><script></script>Not <b>OK</b></p>"
        let nok2 = "<p align=right>Test Not <b>OK</b></p>"
        let nok3 = "<!-- comment --><p>Not OK</p>" // comments and the like will be cleaned
        XCTAssertTrue(try SwiftSoup.isValid(ok, Whitelist.basic()))
        XCTAssertFalse(try SwiftSoup.isValid(nok1, Whitelist.basic()))
        XCTAssertFalse(try SwiftSoup.isValid(nok2, Whitelist.basic()))
        XCTAssertFalse(try SwiftSoup.isValid(nok3, Whitelist.basic()))
    }
    
    func testResolvesRelativeLinks()throws{
        let html = "<a href='/foo'>Link</a><img src='/bar'>"
        let clean = try SwiftSoup.clean(html, "http://example.com/", Whitelist.basicWithImages())
        XCTAssertEqual("<a href=\"http://example.com/foo\" rel=\"nofollow\">Link</a>\n<img src=\"http://example.com/bar\">", clean)
    }
    
    func testPreservesRelativeLinksIfConfigured()throws{
        let html = "<a href='/foo'>Link</a><img src='/bar'> <img src='javascript:alert()'>"
        let clean = try SwiftSoup.clean(html, "http://example.com/", Whitelist.basicWithImages().preserveRelativeLinks(true))
        XCTAssertEqual("<a href=\"/foo\" rel=\"nofollow\">Link</a>\n<img src=\"/bar\"> \n<img>", clean)
    }
    
    func testDropsUnresolvableRelativeLinks()throws{
        let html = "<a href='/foo'>Link</a>"
        let clean = try SwiftSoup.clean(html, Whitelist.basic())
        XCTAssertEqual("<a rel=\"nofollow\">Link</a>", clean)
    }
    
    
    
    func testHandlesAllPseudoTag()throws{
        let html = "<p class='foo' src='bar'><a class='qux'>link</a></p>"
        let whitelist: Whitelist = try Whitelist()
            .addAttributes(":all", "class")
            .addAttributes("p", "style")
            .addTags("p", "a")
        
        let clean = try SwiftSoup.clean(html, whitelist)
        XCTAssertEqual("<p class=\"foo\"><a class=\"qux\">link</a></p>", clean)
    }
    
    func testAddsTagOnAttributesIfNotSet()throws{
        let html = "<p class='foo' src='bar'>One</p>"
        let whitelist = try Whitelist()
            .addAttributes("p", "class")
        // ^^ whitelist does not have explicit tag add for p, inferred from add attributes.
        let clean = try SwiftSoup.clean(html, whitelist)
        XCTAssertEqual("<p class=\"foo\">One</p>", clean)
    }
    
//    func testSupplyOutputSettings()throws{
//        // test that one can override the default document output settings
//        let os: OutputSettings = OutputSettings()
//        os.prettyPrint(pretty: false)
//        os.escapeMode(Entities.EscapeMode.extended)
//        os.charset(.ascii)
//        
//        let html = "<div><p>&bernou</p></div>"
//        let customOut = try SwiftSoup.clean(html, "http://foo.com/", Whitelist.relaxed(), os)
//        let defaultOut = try SwiftSoup.clean(html, "http://foo.com/", Whitelist.relaxed())
//        XCTAssertNotEqual(defaultOut, customOut)
//        
//        XCTAssertEqual("<div><p>&Bscr;</p></div>", customOut) // entities now prefers shorted names if aliased
//        XCTAssertEqual("<div>\n" +
//            " <p>ℬ</p>\n" +
//            "</div>", defaultOut)
//        
//        os.charset(.ascii)
//        os.escapeMode(Entities.EscapeMode.base)
//        let customOut2 = try SwiftSoup.clean(html, "http://foo.com/", Whitelist.relaxed(), os)
//        XCTAssertEqual("<div><p>&#x212c;</p></div>", customOut2)
//    }
    
    func testHandlesFramesets()throws{
        let dirty = "<html><head><script></script><noscript></noscript></head><frameset><frame src=\"foo\" /><frame src=\"foo\" /></frameset></html>"
        let clean = try SwiftSoup.clean(dirty, Whitelist.basic())
        XCTAssertEqual("", clean) // nothing good can come out of that
        
        let dirtyDoc: Document = try SwiftSoup.parse(dirty)
        let cleanDoc: Document? = try Cleaner(Whitelist.basic()).clean(dirtyDoc)
        XCTAssertFalse(cleanDoc == nil)
        XCTAssertEqual(0, cleanDoc?.body()?.childNodeSize())
    }
    
    func testCleansInternationalText()throws{
        XCTAssertEqual("привет", try SwiftSoup.clean("привет", Whitelist.none()))
    }
    
    
    func testScriptTagInWhiteList()throws{
        let whitelist: Whitelist = try Whitelist.relaxed()
        try whitelist.addTags( "script" )
        XCTAssertTrue( try SwiftSoup.isValid("Hello<script>alert('Doh')</script>World !", whitelist ) )
    }
    
    static var allTests = {
        return [
            ("testHandlesCustomProtocols", testHandlesCustomProtocols),
            ("testSimpleBehaviourTest", testSimpleBehaviourTest),
            ("testSimpleBehaviourTest2", testSimpleBehaviourTest2),
            ("testBasicBehaviourTest", testBasicBehaviourTest),
            ("testBasicWithImagesTest", testBasicWithImagesTest),
            ("testRelaxed", testRelaxed),
            ("testRemoveTags", testRemoveTags),
            ("testRemoveAttributes", testRemoveAttributes),
            ("testRemoveEnforcedAttributes", testRemoveEnforcedAttributes),
            ("testRemoveProtocols", testRemoveProtocols),
            ("testDropComments", testDropComments),
            ("testDropXmlProc", testDropXmlProc),
            ("testDropScript", testDropScript),
            ("testDropImageScript", testDropImageScript),
            ("testCleanJavascriptHref", testCleanJavascriptHref),
            ("testCleanAnchorProtocol", testCleanAnchorProtocol),
            ("testDropsUnknownTags", testDropsUnknownTags),
            ("testtestHandlesEmptyAttributes", testtestHandlesEmptyAttributes),
            ("testIsValid", testIsValid),
            ("testResolvesRelativeLinks", testResolvesRelativeLinks),
            ("testPreservesRelativeLinksIfConfigured", testPreservesRelativeLinksIfConfigured),
            ("testDropsUnresolvableRelativeLinks", testDropsUnresolvableRelativeLinks),
            ("testHandlesAllPseudoTag", testHandlesAllPseudoTag),
            ("testAddsTagOnAttributesIfNotSet", testAddsTagOnAttributesIfNotSet),
            ("testHandlesFramesets", testHandlesFramesets),
            ("testCleansInternationalText", testCleansInternationalText),
            ("testScriptTagInWhiteList", testScriptTagInWhiteList)
        ]
    }()
    
}
