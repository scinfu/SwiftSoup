//
//  CleanerTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 13/01/17.
//

import XCTest
@testable import SwiftSoup

class CleanerTest: SwiftSoupTestCase {

    func testHandlesCustomProtocols() throws {
        let html = "<img src='cid:12345' /> <img src='data:gzzt' />"
        //        let dropped = try SwiftSoup.clean(html, Whitelist.basicWithImages())
        //        XCTAssertEqual("<img> \n<img>", dropped)

        let preserved = try SwiftSoup.clean(html, Whitelist.basicWithImages().addProtocols("img", "src", "cid", "data"))
        XCTAssertEqual("<img src=\"cid:12345\" /> \n<img src=\"data:gzzt\" />", preserved)
    }

    func testSimpleBehaviourTest() throws {
        let h = "<div><p class=foo><a href='http://evil.com'>Hello <b id=bar>there</b>!</a></div>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.simpleText())
        XCTAssertEqual("Hello <b>there</b>!", TextUtil.stripNewlines(cleanHtml!))
    }

    func testSimpleBehaviourTest2() throws {
        let h = "Hello <b>there</b>!"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.simpleText())

        XCTAssertEqual("Hello <b>there</b>!", TextUtil.stripNewlines(cleanHtml!))
    }

    func testBasicBehaviourTest() throws {
        let h = "<div><p><a href='javascript:sendAllMoney()'>Dodgy</a> <A HREF='HTTP://nice.com'>Nice</a></p><blockquote>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic())

        XCTAssertEqual("<p><a rel=\"nofollow\">Dodgy</a> <a href=\"HTTP://nice.com\" rel=\"nofollow\">Nice</a></p><blockquote>Hello</blockquote>",
                       TextUtil.stripNewlines(cleanHtml!))
    }

    func testBasicWithImagesTest() throws {
        let h = "<div><p><img src='http://example.com/' alt=Image></p><p><img src='ftp://ftp.example.com'></p></div>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basicWithImages())
        XCTAssertEqual("<p><img src=\"http://example.com/\" alt=\"Image\" /></p><p><img /></p>", TextUtil.stripNewlines(cleanHtml!))
    }

    func testRelaxed() throws {
        let h = "<h1>Head</h1><table><tr><td>One<td>Two</td></tr></table>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<h1>Head</h1><table><tbody><tr><td>One</td><td>Two</td></tr></tbody></table>", TextUtil.stripNewlines(cleanHtml!))
    }

    func testRemoveTags() throws {
        let h = "<div><p><A HREF='HTTP://nice.com'>Nice</a></p><blockquote>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeTags("a"))

        XCTAssertEqual("<p>Nice</p><blockquote>Hello</blockquote>", TextUtil.stripNewlines(cleanHtml!))
    }

    func testRemoveAttributes() throws {
        let h = "<div><p>Nice</p><blockquote cite='http://example.com/quotations'>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeAttributes("blockquote", "cite"))

        XCTAssertEqual("<p>Nice</p><blockquote>Hello</blockquote>", TextUtil.stripNewlines(cleanHtml!))
    }

    func testRemoveEnforcedAttributes() throws {
        let h = "<div><p><A HREF='HTTP://nice.com'>Nice</a></p><blockquote>Hello</blockquote>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeEnforcedAttribute("a", "rel"))

        XCTAssertEqual("<p><a href=\"HTTP://nice.com\">Nice</a></p><blockquote>Hello</blockquote>",
                       TextUtil.stripNewlines(cleanHtml!))
    }

    func testRemoveProtocols() throws {
        let h = "<p>Contact me <a href='mailto:info@example.com'>here</a></p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basic().removeProtocols("a", "href", "ftp", "mailto"))

        XCTAssertEqual("<p>Contact me <a rel=\"nofollow\">here</a></p>",
                       TextUtil.stripNewlines(cleanHtml!))
    }

    func testDropComments() throws {
        let h = "<p>Hello<!-- no --></p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<p>Hello</p>", cleanHtml)
    }

    func testDropXmlProc() throws {
        let h = "<?import namespace=\"xss\"><p>Hello</p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<p>Hello</p>", cleanHtml)
    }

    func testDropScript() throws {
        let h = "<SCRIPT SRC=//ha.ckers.org/.j><SCRIPT>alert(/XSS/.source)</SCRIPT>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("", cleanHtml)
    }

    func testDropImageScript() throws {
        let h = "<IMG SRC=\"javascript:alert('XSS')\">"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<img />", cleanHtml)
    }

    func testCleanJavascriptHref() throws {
        let h = "<A HREF=\"javascript:document.location='http://www.google.com/'\">XSS</A>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<a>XSS</a>", cleanHtml)
    }

    func testCleanAnchorProtocol() throws {
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

    func testDropsUnknownTags() throws {
        let h = "<p><custom foo=true>Test</custom></p>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.relaxed())
        XCTAssertEqual("<p>Test</p>", cleanHtml)
    }

    func testtestHandlesEmptyAttributes() throws {
        let h = "<img alt=\"\" src= unknown=''>"
        let cleanHtml = try SwiftSoup.clean(h, Whitelist.basicWithImages())
        XCTAssertEqual("<img alt=\"\" />", cleanHtml)
    }

    func testIsValid() throws {
        let ok = "<p>Test <b><a href='http://example.com/'>OK</a></b></p>"
        let nok1 = "<p><script></script>Not <b>OK</b></p>"
        let nok2 = "<p align=right>Test Not <b>OK</b></p>"
        let nok3 = "<!-- comment --><p>Not OK</p>" // comments and the like will be cleaned
        XCTAssertTrue(try SwiftSoup.isValid(ok, Whitelist.basic()))
        XCTAssertFalse(try SwiftSoup.isValid(nok1, Whitelist.basic()))
        XCTAssertFalse(try SwiftSoup.isValid(nok2, Whitelist.basic()))
        XCTAssertFalse(try SwiftSoup.isValid(nok3, Whitelist.basic()))
    }

    func testResolvesRelativeLinks() throws {
        let html = "<a href='/foo'>Link</a><img src='/bar'>"
        let clean = try SwiftSoup.clean(html, "http://example.com/", Whitelist.basicWithImages())
        XCTAssertEqual("<a href=\"http://example.com/foo\" rel=\"nofollow\">Link</a>\n<img src=\"http://example.com/bar\" />", clean)
    }

    func testPreservesRelativeLinksIfConfigured() throws {
        let html = "<a href='/foo'>Link</a><img src='/bar'> <img src='javascript:alert()'>"
        let clean = try SwiftSoup.clean(html, "http://example.com/", Whitelist.basicWithImages().preserveRelativeLinks(true))
        XCTAssertEqual("<a href=\"/foo\" rel=\"nofollow\">Link</a>\n<img src=\"/bar\" /> \n<img />", clean)
    }

    func testDropsUnresolvableRelativeLinks() throws {
        let html = "<a href='/foo'>Link</a>"
        let clean = try SwiftSoup.clean(html, Whitelist.basic())
        XCTAssertEqual("<a rel=\"nofollow\">Link</a>", clean)
    }

    func testHandlesAllPseudoTag() throws {
        let html = "<p class='foo' src='bar'><a class='qux'>link</a></p>"
        let whitelist: Whitelist = try Whitelist()
            .addAttributes(":all", "class")
            .addAttributes("p", "style")
            .addTags("p", "a")

        let clean = try SwiftSoup.clean(html, whitelist)
        XCTAssertEqual("<p class=\"foo\"><a class=\"qux\">link</a></p>", clean)
    }

    func testAddsTagOnAttributesIfNotSet() throws {
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

    func testHandlesFramesets() throws {
        let dirty = "<html><head><script></script><noscript></noscript></head><frameset><frame src=\"foo\" /><frame src=\"foo\" /></frameset></html>"
        let clean = try SwiftSoup.clean(dirty, Whitelist.basic())
        XCTAssertEqual("", clean) // nothing good can come out of that

        let dirtyDoc: Document = try SwiftSoup.parse(dirty)
        let cleanDoc: Document? = try Cleaner(Whitelist.basic()).clean(dirtyDoc)
        XCTAssertFalse(cleanDoc == nil)
        XCTAssertEqual(0, cleanDoc?.body()?.childNodeSize())
    }

    func testCleanHeadAndBody() throws {
        let dirty = "<html><head><title>Hello</title><style>body {}</style></head><body><p>Hey!</p></body></html>"
        // let clean = "<html><head><title>Hello</title></head><body><p>Hey!</p></body></html>"

        let headWhitelist = try Whitelist.none()
            .addTags("title")

        let dirtyDoc = try SwiftSoup.parse(dirty)
        let cleanDoc = try Cleaner(headWhitelist: headWhitelist, bodyWhitelist: .relaxed()).clean(dirtyDoc)

        let cleanHead = cleanDoc.head()
        XCTAssertNotNil(cleanHead)
        XCTAssertEqual(1, cleanHead?.childNodeSize())
        let title = try cleanHead?.select("title").first()
        XCTAssertNotNil(title)
        XCTAssertEqual("title", title?.tagName())
    }

    func testCleansInternationalText() throws {
        XCTAssertEqual("привет", try SwiftSoup.clean("привет", Whitelist.none()))
    }

    func testScriptTagInWhiteList() throws {
        let whitelist: Whitelist = try Whitelist.relaxed()
        try whitelist.addTags( "script" )
        XCTAssertTrue( try SwiftSoup.isValid("Hello<script>alert('Doh')</script>World !", whitelist ) )
    }
    
    func testEscapingInAttributeURLs() throws {
        // See https://github.com/scinfu/SwiftSoup/issues/268 for discussions about the issues tested here.
        
        let html = #"<a href="mailto:mail@example.com?subject=Job%20Requisition[NID]">Send</a></body></html>"#
        let document = try SwiftSoup.parse(html)
        
        let customWhitelist = Whitelist.none()
        try customWhitelist
            .addTags("a")
            .addAttributes("a", "href")
            .addProtocols("a", "href", "mailto")
        
        // Get the link text before any processing.
        let originalLink = try document.select("a").first()?.attr("href")
        
        // Clean it.
        let cleanedFirst = try Cleaner(headWhitelist: customWhitelist, bodyWhitelist: customWhitelist).clean(document)
        
        // Check the link text from the source document after processing. There was a bug where this was modified.
        let originalLinkAfterClean = try document.select("a").first()?.attr("href")
        XCTAssertNotNil(originalLink)
        XCTAssertEqual(originalLinkAfterClean, originalLink)
        
        // Due to Apple parsing issues, the `[` and `]` do get escaped. But the `%20` should not get escaped again.
        // Ideally this should return the `originalLink` but for now, no double-escaping is already an improvement.
        let cleanedLinkFirst = try cleanedFirst.select("a").first()?.attr("href")
        XCTAssertNotNil(cleanedLinkFirst)
        XCTAssertEqual("mailto:mail@example.com?subject=Job%20Requisition%5BNID%5D", cleanedLinkFirst)
        
        // Try again with `.preserveRelativeLinks(true)` which should not modify the link at all.
        customWhitelist.preserveRelativeLinks(true)
        let cleanedSecond = try Cleaner(headWhitelist: customWhitelist, bodyWhitelist: customWhitelist).clean(document)
        let cleanedLinkSecond = try cleanedSecond.select("a").first()?.attr("href")
        XCTAssertEqual(originalLink, cleanedLinkSecond)
    }

}
