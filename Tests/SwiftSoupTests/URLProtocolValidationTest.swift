//
//  URLProtocolValidationTest.swift
//  SwiftSoup
//
//  Created by gua on 2026/10/16.
//

import XCTest
import SwiftSoup

final class URLProtocolValidationTest: XCTestCase {
    func testFailedResolutionDoesNotFallBackToBaseURI() {
        let baseURI = "https://example.test/path/"
        for value in ["http://[", "https://[::1"] {
            XCTAssertEqual(StringUtil.resolve(baseURI, relUrl: value), "", value.debugDescription)
        }
        XCTAssertEqual(StringUtil.resolve(baseURI, relUrl: ""), baseURI)
    }

    func testCleanRejectsEntityEncodedJavascriptProtocolWithBaseURI() throws {
        for control in ["&#x09;", "&#10;", "&#x0D;"] {
            let html = "<a href='java\(control)script:alert(1)'>link</a>"
            XCTAssertEqual(
                try SwiftSoup.clean(html, "https://example.test/", Whitelist.basic()),
                "<a rel=\"nofollow\">link</a>",
                control
            )
        }
    }

    func testRejectsControlCharacterProtocolsAcrossCleaningModes() throws {
        let values = [
            "java\tscript:alert(1)",
            "java\nscript:alert(1)",
            "java\rscript:alert(1)",
            "\u{01}javascript:alert(1)",
            "\u{1F}javascript:alert(1)",
            " \tjava\nscript:alert(1)\r ",
            "java\tscript:alert(1)\u{01}"
        ]
        let modes: [Whitelist.URLWhitespaceMode] = [.strict, .trim, .allow]
        for baseURI in ["", "https://example.test/path/"] {
            for preserve in [false, true] {
                for mode in modes {
                    let whitelist = try Whitelist.basicWithImages()
                        .preserveRelativeLinks(preserve)
                        .urlWhitespace(mode)
                    let cleaner = Cleaner(headWhitelist: nil, bodyWhitelist: whitelist)
                    for value in values {
                        let html = "<a href=\"\(value)\">link</a><img src=\"\(value)\">"
                        let dirty = try SwiftSoup.parse(html, baseURI)
                        XCTAssertFalse(try cleaner.isValid(dirty), value.debugDescription)
                        let clean = try cleaner.clean(dirty)
                        let link = try XCTUnwrap(clean.select("a").first())
                        let image = try XCTUnwrap(clean.select("img").first())
                        XCTAssertFalse(link.hasAttr("href"), value.debugDescription)
                        XCTAssertFalse(image.hasAttr("src"), value.debugDescription)
                    }
                }
            }
        }
    }

    func testRejectsControlCharacterProtocolsForAllAttributesPolicy() throws {
        let whitelist = try Whitelist.none()
            .addTags("a")
            .addAttributes(":all", "href")
            .addProtocols(":all", "href", "https")
            .preserveRelativeLinks(true)
        let html = "<a href='java&#x09;script:alert(1)'>link</a>"
        XCTAssertEqual(try SwiftSoup.clean(html, "https://example.test/", whitelist), "<a>link</a>")
    }

    func testValidRelativeAndAbsoluteLinksKeepConfiguredOutput() throws {
        let values = [
            ("/article", "https://example.test/article"),
            ("article.html", "article.html"),
            ("//other.test/article", "https://other.test/article"),
            ("https://other.test/article", "https://other.test/article")
        ]
        let modes: [Whitelist.URLWhitespaceMode] = [.strict, .trim, .allow]
        for preserve in [false, true] {
            for mode in modes {
                let whitelist = try Whitelist.basic()
                    .preserveRelativeLinks(preserve)
                    .urlWhitespace(mode)
                for (value, resolved) in values {
                    let html = "<a href='\(value)'>link</a>"
                    let clean = try XCTUnwrap(SwiftSoup.clean(html, "https://example.test/path/", whitelist))
                    let link = try XCTUnwrap(SwiftSoup.parse(clean).select("a").first())
                    XCTAssertEqual(try link.attr("href"), preserve ? value : resolved)
                }
            }
        }
    }

    func testValidURLPaddingStillFollowsWhitespaceMode() throws {
        let html = "<a href='\thttps://example.test/article\n'>link</a>"
        let modes: [Whitelist.URLWhitespaceMode] = [.strict, .trim, .allow]
        for mode in modes {
            let whitelist = try Whitelist.basic().urlWhitespace(mode)
            let clean = try XCTUnwrap(SwiftSoup.clean(html, whitelist))
            let link = try XCTUnwrap(SwiftSoup.parse(clean).select("a").first())
            switch mode {
            case .strict:
                XCTAssertFalse(link.hasAttr("href"))
            case .trim:
                XCTAssertEqual(try link.attr("href"), "https://example.test/article")
            case .allow:
                XCTAssertEqual(try link.attr("href"), "\thttps://example.test/article\n")
            }
        }
    }
}
