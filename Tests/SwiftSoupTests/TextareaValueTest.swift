import XCTest
import SwiftSoup

final class TextareaValueTest: XCTestCase {
    func testSetterWritesTextForEveryTextareaSpelling() throws {
        for name in ["textarea", "TEXTAREA", "TeXtArEa"] {
            let element = try Document("").createElement(name)
            try element.attr("value", "ignored")
            for (value, expected) in [("", ""), ("value", "value"), (" \tvalue\n ", "value"), ("\n日本 😀\t", "日本 😀")] {
                XCTAssertTrue(try element.val(value) === element)
                XCTAssertEqual(try element.val(), expected, name)
                XCTAssertEqual(try element.text(trimAndNormaliseWhitespace: false), value, name)
                XCTAssertEqual(try element.attr("value"), "ignored", name)
                XCTAssertEqual(element.tagName(), name)
            }
        }
    }

    func testGetterReadsExistingTextInsteadOfValueAttribute() throws {
        for name in ["textarea", "TEXTAREA", "TeXtArEa"] {
            let element = try Document("").createElement(name)
            try element.attr("value", "ignored")
            try element.appendText(" \t")
            try element.appendText("one two")
            try element.appendChild(Comment(Array("ignored".utf8), []))
            try element.appendText(" 日本 ")
            XCTAssertEqual(try element.val(), "one two 日本", name)
        }
    }

    func testRetaggedParsedTextareasRetainValueSemantics() throws {
        let document = try SwiftSoup.parse("<textarea>one &amp; two</textarea>")
        let textarea = try XCTUnwrap(document.select("textarea").first())
        for name in ["TEXTAREA", "TeXtArEa", "textarea"] {
            try textarea.tagName(name)
            XCTAssertEqual(try textarea.val(), "one & two")
        }
        try textarea.tagName("TEXTAREA")
        try textarea.val("changed < & >")
        XCTAssertEqual(try textarea.text(), "changed < & >")
        XCTAssertFalse(textarea.hasAttr("value"))
    }

    func testCollectionValueUpdatesMixedCaseTextareasAndInputs() throws {
        let document = Document.createShell("")
        let body = try XCTUnwrap(document.body())
        let first = try body.appendElement("TEXTAREA")
        let second = try body.appendElement("textarea")
        let input = try body.appendElement("INPUT")
        let elements = Elements([first, second, input])
        let value = " \tvalue\n "
        XCTAssertTrue(try elements.val(value) === elements)
        XCTAssertEqual(try elements.val(), "value")
        for textarea in [first, second] {
            XCTAssertEqual(try textarea.val(), "value")
            XCTAssertEqual(try textarea.text(trimAndNormaliseWhitespace: false), value)
            XCTAssertFalse(textarea.hasAttr("value"))
        }
        XCTAssertEqual(try input.attr("value"), value)
        XCTAssertEqual(try input.val(), value)
        XCTAssertEqual(input.childNodeSize(), 0)
    }

    func testOtherElementsContinueUsingValueAttributes() throws {
        for name in ["input", "INPUT", "output", "div"] {
            let element = try Document("").createElement(name)
            try element.text("existing text")
            try element.val("  attribute value  ")
            XCTAssertEqual(try element.val(), "  attribute value  ")
            XCTAssertEqual(try element.attr("value"), "  attribute value  ")
            XCTAssertEqual(try element.text(), "existing text")
        }
    }
}
