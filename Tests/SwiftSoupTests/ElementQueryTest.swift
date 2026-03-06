//
//  ElementQueryTest.swift
//  SwiftSoup
//

import XCTest
import SwiftSoup

class ElementQueryTest: XCTestCase {

    private let testHtml = """
    <html><head><title>Test</title></head><body>
    <div class="content" id="main">
        <p class="intro">Hello <b>world</b></p>
        <a href="/link1" class="nav">Link 1</a>
        <a href="/link2" class="nav">Link 2</a>
        <input type="text" name="q" value="search term" />
        <script>var x = 1;</script>
    </div>
    </body></html>
    """

    // MARK: - Conformance verification

    func testElementConformsToElementQuery() throws {
        let doc = try SwiftSoup.parse(testHtml)
        let element: any ElementQuery = doc.body()!
        XCTAssertTrue(try element.hasText())
    }

    func testElementsConformsToElementQuery() throws {
        let doc = try SwiftSoup.parse(testHtml)
        let elements: any ElementQuery = try doc.select("a")
        XCTAssertTrue(try elements.hasText())
    }

    // MARK: - Generic function works with both types

    private func extractText(_ source: some ElementQuery) throws -> String {
        return try source.text()
    }

    private func extractAttr(_ source: some ElementQuery, _ key: String) throws -> String {
        return try source.attr(key)
    }

    private func findLinks(_ source: some ElementQuery) throws -> Elements {
        return try source.select("a[href]")
    }

    func testGenericFunctionWithElement() throws {
        let doc = try SwiftSoup.parse(testHtml)
        let div = try doc.select("div.content").first()!

        let text = try extractText(div)
        XCTAssertTrue(text.contains("Hello"))
        XCTAssertTrue(text.contains("world"))

        let id = try extractAttr(div, "id")
        XCTAssertEqual("main", id)

        let links = try findLinks(div)
        XCTAssertEqual(2, links.size())
    }

    func testGenericFunctionWithElements() throws {
        let doc = try SwiftSoup.parse(testHtml)
        let anchors = try doc.select("a")

        let text = try extractText(anchors)
        XCTAssertTrue(text.contains("Link 1"))
        XCTAssertTrue(text.contains("Link 2"))

        let href = try extractAttr(anchors, "href")
        XCTAssertEqual("/link1", href) // returns first match

        let links = try findLinks(anchors)
        XCTAssertEqual(2, links.size())
    }

    // MARK: - Protocol methods work consistently

    func testAttrThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("a").first()!
        XCTAssertEqual("/link1", try element.attr("href"))

        let elements: any ElementQuery = try doc.select("a")
        XCTAssertEqual("/link1", try elements.attr("href"))
    }

    func testHasAttrThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("a").first()!
        XCTAssertTrue(element.hasAttr("href"))
        XCTAssertFalse(element.hasAttr("data-foo"))

        let elements: any ElementQuery = try doc.select("a")
        XCTAssertTrue(elements.hasAttr("href"))
        XCTAssertFalse(elements.hasAttr("data-foo"))
    }

    func testHasClassThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("p").first()!
        XCTAssertTrue(element.hasClass("intro"))
        XCTAssertFalse(element.hasClass("outro"))

        let elements: any ElementQuery = try doc.select("a")
        XCTAssertTrue(elements.hasClass("nav"))
    }

    func testValThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("input").first()!
        XCTAssertEqual("search term", try element.val())

        let elements: any ElementQuery = try doc.select("input")
        XCTAssertEqual("search term", try elements.val())
    }

    func testTextThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("p.intro").first()!
        XCTAssertEqual("Hello world", try element.text())

        let elements: any ElementQuery = try doc.select("p.intro")
        XCTAssertEqual("Hello world", try elements.text())
    }

    func testHtmlThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("p.intro").first()!
        let elementHtml = try element.html()
        XCTAssertTrue(elementHtml.contains("Hello"))
        XCTAssertTrue(elementHtml.contains("<b>world</b>"))

        let elements: any ElementQuery = try doc.select("p.intro")
        let elementsHtml = try elements.html()
        XCTAssertTrue(elementsHtml.contains("Hello"))
        XCTAssertTrue(elementsHtml.contains("<b>world</b>"))
    }

    func testSelectThroughProtocol() throws {
        let doc = try SwiftSoup.parse(testHtml)

        let element: any ElementQuery = try doc.select("div").first()!
        let fromElement = try element.select("a")
        XCTAssertEqual(2, fromElement.size())

        let elements: any ElementQuery = try doc.select("div")
        let fromElements = try elements.select("a")
        XCTAssertEqual(2, fromElements.size())
    }
}
