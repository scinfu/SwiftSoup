import XCTest
@testable import SwiftSoup

final class RawTextFragmentContextTest: XCTestCase {
    private let literalSource = "alpha&amp;<b>literal</b>&#x41;日本😀"

    private func target(
        _ tag: String,
        settings: ParseSettings = .htmlDefault
    ) throws -> Element {
        Element(try Tag.valueOf(tag, settings), "")
    }

    private func contents(
        of element: Element,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> String {
        element.getChildNodes().map { node in
            if let data = node as? DataNode {
                return data.getWholeData()
            }
            if let text = node as? TextNode {
                return text.getWholeText()
            }
            XCTFail("Expected character data, got \(type(of: node))", file: file, line: line)
            return ""
        }.joined()
    }

    func testRawTextFragmentMutationsKeepReferencesAndMarkupLiteral() throws {
        for tag in ["iframe", "noembed", "noframes", "style", "xmp"] {
            for mutate in [
                { (element: Element) throws in try element.append(self.literalSource) },
                { (element: Element) throws in try element.prepend(self.literalSource) },
                { (element: Element) throws in try element.html(self.literalSource) }
            ] {
                let element = try target(tag)
                try mutate(element)
                XCTAssertEqual(contents(of: element), literalSource, tag)
                XCTAssertTrue(element.children().isEmpty, tag)
            }
        }
    }

    func testRawTextFragmentContextUsesNormalizedPreserveCaseTagName() throws {
        for tag in ["IFRAME", "NOEMBED", "NOFRAMES", "STYLE", "XMP"] {
            let element = try target(tag, settings: .preserveCase)
            XCTAssertEqual(element.tagName(), tag)
            try element.append(literalSource)
            XCTAssertEqual(contents(of: element), literalSource, tag)
            XCTAssertTrue(element.children().isEmpty, tag)
        }
    }

    func testRawTextParseFragmentReturnsLiteralText() throws {
        for tag in ["iframe", "noembed", "noframes", "style", "xmp"] {
            let context = try target(tag)
            let parsed = try Parser.parseFragment(literalSource, context, [])
            XCTAssertEqual(parsed.count, 1, tag)
            XCTAssertTrue(parsed[0] is TextNode, tag)
            XCTAssertEqual((parsed[0] as? TextNode)?.getWholeText(), literalSource, tag)
        }
    }

    func testRcdataFragmentContextsStillDecodeReferencesAndKeepMarkupLiteral() throws {
        let expected = "alpha&<b>literal</b>A日本😀"
        for tag in ["title", "textarea"] {
            for mutate in [
                { (element: Element) throws in try element.append(self.literalSource) },
                { (element: Element) throws in try element.prepend(self.literalSource) },
                { (element: Element) throws in try element.html(self.literalSource) }
            ] {
                let element = try target(tag)
                try mutate(element)
                XCTAssertEqual(contents(of: element), expected, tag)
                XCTAssertTrue(element.children().isEmpty, tag)
            }
        }
    }

    func testScriptDataFragmentContextRemainsCompatible() throws {
        for mutate in [
            { (element: Element) throws in try element.append(self.literalSource) },
            { (element: Element) throws in try element.prepend(self.literalSource) },
            { (element: Element) throws in try element.html(self.literalSource) }
        ] {
            let element = try target("script")
            try mutate(element)
            XCTAssertEqual(contents(of: element), literalSource)
            XCTAssertTrue(element.children().isEmpty)
        }
    }
}
