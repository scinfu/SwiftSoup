//
//  AttributeTest.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 07/10/16.
//

import XCTest
@testable import SwiftSoup
class AttributeTest: XCTestCase {
    func testHtml() throws {
        let attr = try Attribute(key: "key", value: "value &")
        XCTAssertEqual("key=\"value &amp;\"", attr.html())
        XCTAssertEqual(attr.html(), attr.toString())
    }

    func testWithSupplementaryCharacterInAttributeKeyAndValue() throws {
        let string =  "135361"
        let attr = try Attribute(key: string, value: "A" + string + "B")
        XCTAssertEqual(string + "=\"A" + string + "B\"", attr.html())
        XCTAssertEqual(attr.html(), attr.toString())
    }

    func testRemoveCaseSensitive() throws {
        let atteibute: Attributes = Attributes()
        try atteibute.put("Tot", "a&p")
        try atteibute.put("tot", "one")
        try atteibute.put("Hello", "There")
        try atteibute.put("hello", "There")
        try atteibute.put("data-name", "Jsoup")

        XCTAssertEqual(5, atteibute.size())
        try atteibute.remove(key: "Tot")
        try atteibute.remove(key: "Hello")
        XCTAssertEqual(3, atteibute.size())
        XCTAssertTrue(atteibute.hasKey(key: "tot"))
        XCTAssertFalse(atteibute.hasKey(key: "Tot"))
    }

    func testSliceBackedAttributeMaterialization() throws {
        let key = "href".utf8Array
        let value = "/one?x=1&y=2".utf8Array
        let attr = try Attribute(keySlice: key[...], valueSlice: value[...])
        XCTAssertEqual("href", attr.getKey())
        XCTAssertEqual("/one?x=1&y=2", attr.getValue())
        XCTAssertEqual("href=\"/one?x=1&amp;y=2\"", attr.html())

        let old = attr.setValue(value: "two".utf8Array)
        XCTAssertEqual(value, old)
        XCTAssertEqual("two", attr.getValue())
        try attr.setKey(key: "HREF")
        XCTAssertEqual("HREF", attr.getKey())
    }

    func testSliceBackedBooleanAttributeHtml() throws {
        let attr = try BooleanAttribute(keySlice: "disabled".utf8Array[...])
        let out = Document([]).outputSettings()
        let sb = StringBuilder()
        attr.html(accum: sb, out: out)
        XCTAssertEqual("disabled", sb.toString())
    }

    func testCrossoriginWithoutValueCollapsesInOutput() throws {
        // <script crossorigin> is parsed as a BooleanAttribute and should round-trip without =""
        let html = "<script crossorigin src=\"app.js\"></script>"
        let doc = try SwiftSoup.parse(html)
        let script = try doc.select("script").first()!

        XCTAssertTrue(try script.hasAttr("crossorigin"))
        let output = try script.outerHtml()
        XCTAssertTrue(output.contains("crossorigin"))
        XCTAssertFalse(output.contains("crossorigin=\"\""))
    }

    func testCrossoriginEmptyValueCollapsesInOutput() throws {
        // <script crossorigin=""> should also collapse to <script crossorigin> because
        // crossorigin is in the boolean attributes list
        let html = "<script crossorigin=\"\" src=\"app.js\"></script>"
        let doc = try SwiftSoup.parse(html)
        let script = try doc.select("script").first()!

        let output = try script.outerHtml()
        XCTAssertTrue(output.contains("crossorigin"))
        XCTAssertFalse(output.contains("crossorigin=\"\""))
    }

    func testCrossoriginWithValuePreservesValue() throws {
        let html = "<script crossorigin=\"use-credentials\" src=\"app.js\"></script>"
        let doc = try SwiftSoup.parse(html)
        let script = try doc.select("script").first()!

        XCTAssertEqual("use-credentials", try script.attr("crossorigin"))
    }

    func testCrossoriginSetProgrammaticallyCollapsesWhenEmpty() throws {
        let doc = try SwiftSoup.parse("<script src=\"app.js\"></script>")
        let script = try doc.select("script").first()!
        try script.attr("crossorigin", "")

        let output = try script.outerHtml()
        XCTAssertTrue(output.contains("crossorigin"))
        XCTAssertFalse(output.contains("crossorigin=\"\""))
    }
}
