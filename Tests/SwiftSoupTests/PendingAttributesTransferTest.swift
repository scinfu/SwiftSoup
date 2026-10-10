import XCTest
@testable import SwiftSoup

final class PendingAttributesTransferTest: XCTestCase {
    private func add(_ token: Token.StartTag, _ name: String, _ value: String? = nil) throws {
        token.appendAttributeName(Array(name.utf8))
        if let value {
            if value.isEmpty {
                token.setEmptyAttributeValue()
            } else {
                token.appendAttributeValue(ByteSlice.fromArray(Array(value.utf8)))
            }
        }
        try token.newAttribute()
    }

    func testTokenResetDoesNotClearTransferredAttributes() throws {
        let token = Token.StartTag()
        try add(token, "data-first", "one")
        try add(token, "checked")
        let first = token.getAttributes()
        token.reset()
        try add(token, "data-second", "two")
        let second = token.getAttributes()

        XCTAssertFalse(first === second)
        XCTAssertEqual(first.get(key: "data-first"), "one")
        XCTAssertTrue(first.hasKey(key: "checked"))
        XCTAssertFalse(first.hasKey(key: "data-second"))
        XCTAssertEqual(second.get(key: "data-second"), "two")
        XCTAssertFalse(second.hasKey(key: "data-first"))
    }

    func testExistingMaterializedAttributesKeepIdentityAndInvalidateSelectors() throws {
        let doc = try SwiftSoup.parse("<div class='before' data-keep='value'></div>")
        let element = try XCTUnwrap(doc.select(".before").first())
        let attributes = try XCTUnwrap(element.getAttributes())
        _ = attributes.size()
        let token = Token.StartTag()
        token._attributes = attributes
        try add(token, "class", "after")
        try add(token, "data-new", "added")

        XCTAssertTrue(token.getAttributes() === attributes)
        XCTAssertEqual(attributes.get(key: "data-keep"), "value")
        XCTAssertEqual(attributes.get(key: "data-new"), "added")
        XCTAssertEqual(try doc.select(".before").size(), 0)
        XCTAssertTrue(try doc.select(".after").first() === element)
    }

    func testExistingDeferredAttributesAreAppendedNotReplaced() throws {
        let first = Token.StartTag()
        try add(first, "data-keep", "one")
        try add(first, "data-replace", "before")
        let attributes = first.getAttributes()
        let next = Token.StartTag()
        next._attributes = attributes
        try add(next, "data-replace", "after")
        try add(next, "data-new", "two")

        XCTAssertTrue(next.getAttributes() === attributes)
        XCTAssertEqual(attributes.size(), 3)
        XCTAssertEqual(attributes.get(key: "data-keep"), "one")
        XCTAssertEqual(attributes.get(key: "data-replace"), "after")
        XCTAssertEqual(attributes.get(key: "data-new"), "two")
    }

    func testUppercaseMetadataComesFromPendingNames() throws {
        let token = Token.StartTag()
        try add(token, "DATA-X", "one")
        try add(token, "Class", "before")
        // Do not infer Attributes.hasUppercaseKeys from this separate token flag.
        token.setAttributesNormalized(true)
        let attributes = token.getAttributes()
        XCTAssertTrue(attributes.hasUppercaseKeys)
        attributes.lowercaseAllKeys()
        XCTAssertEqual(attributes.get(key: "data-x"), "one")
        XCTAssertEqual(attributes.get(key: "class"), "before")
        XCTAssertFalse(attributes.hasKey(key: "DATA-X"))
    }

    func testBooleanEmptyDuplicateAndMalformedNames() throws {
        let token = Token.StartTag()
        try add(token, "checked")
        try add(token, "empty", "")
        try add(token, "duplicate", "before")
        try add(token, "duplicate", "after")
        try add(token, " \t", "invalid")
        let attributes = token.getAttributes()
        XCTAssertEqual(attributes.size(), 3)
        XCTAssertTrue(Array(attributes).first { $0.getKey() == "checked" } is BooleanAttribute)
        XCTAssertFalse(Array(attributes).first { $0.getKey() == "empty" } is BooleanAttribute)
        // HTML5 tokenizer: the repeated name is dropped, so the first value wins.
        XCTAssertEqual(attributes.get(key: "duplicate"), "before")
    }

    func testMultipleValueSlicesSurviveTokenReuse() throws {
        let token = Token.StartTag()
        token.appendAttributeName(Array("title".utf8))
        token.appendAttributeValue(ByteSlice.fromArray(Array("日本語".utf8)))
        token.appendAttributeValue(ByteSlice.fromArray(Array(" & text".utf8)))
        try token.newAttribute()
        let attributes = token.getAttributes()
        token.reset()
        try add(token, "title", "replacement")
        _ = token.getAttributes()
        XCTAssertEqual(attributes.get(key: "title"), "日本語 & text")
    }

    func testXMLPreservesCaseAndDistinctKeysAcrossElements() throws {
        let doc = try SwiftSoup.parse("<root><item A='one' a='two'/><item A='three'/></root>", "", Parser.xmlParser())
        let items = try doc.select("item")
        let first = try XCTUnwrap(items.get(0).getAttributes())
        let second = try XCTUnwrap(items.get(1).getAttributes())
        XCTAssertEqual(first.get(key: "A"), "one")
        XCTAssertEqual(first.get(key: "a"), "two")
        XCTAssertEqual(second.get(key: "A"), "three")
    }

    func testNoSourceRangesMaterializesAttributesBeforeInputIsReleased() throws {
        var bytes = Array("<div DATA-X='one' title='a&amp;b'></div><div data-x='two'></div>".utf8)
        let parser = Parser.htmlParser()
        parser.settings(ParseSettings(false, false, false))
        let doc = try parser.parseInput(bytes, "")
        bytes = Array(repeating: 0, count: bytes.count)
        let divs = try doc.select("div")
        XCTAssertEqual(try divs.get(0).attr("data-x"), "one")
        XCTAssertEqual(try divs.get(0).attr("title"), "a&b")
        XCTAssertEqual(try divs.get(1).attr("data-x"), "two")
    }
}
