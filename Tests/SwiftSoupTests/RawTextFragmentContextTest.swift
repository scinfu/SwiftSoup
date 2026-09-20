import XCTest
@testable import SwiftSoup

final class RawTextFragmentContextTest: XCTestCase {
    private let literalSource = "alpha&amp;<b>literal</b>&#x41;日本😀"

    private func target(
        _ tag: String,
        content: String = "",
        settings: ParseSettings = .htmlDefault
    ) throws -> Element {
        let parser = Parser.htmlParser().settings(settings)
        let document = try parser.parseInput("<\(tag) id='target'>\(content)</\(tag)>", "")
        return try XCTUnwrap(document.getElementById("target"))
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

    func testRawTextFragmentInsertionsMatchFullDocumentParsing() throws {
        for tag in ["iframe", "noembed", "noframes", "style", "xmp"] {
            let fullAppend = try target(tag, content: "seed" + literalSource)
            let appended = try target(tag, content: "seed")
            try appended.append(literalSource)
            XCTAssertEqual(contents(of: appended), contents(of: fullAppend), tag)
            XCTAssertEqual(contents(of: appended), "seed" + literalSource, tag)

            let fullPrepend = try target(tag, content: literalSource + "seed")
            let prepended = try target(tag, content: "seed")
            try prepended.prepend(literalSource)
            XCTAssertEqual(contents(of: prepended), contents(of: fullPrepend), tag)
            XCTAssertEqual(contents(of: prepended), literalSource + "seed", tag)

            let fullReplacement = try target(tag, content: literalSource)
            let replaced = try target(tag, content: "discarded")
            try replaced.html(literalSource)
            XCTAssertEqual(contents(of: replaced), contents(of: fullReplacement), tag)
            XCTAssertEqual(contents(of: replaced), literalSource, tag)
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

    func testStyleStorageReflectsFullParseAndSyntheticFragmentRoot() throws {
        let fullyParsed = try target("style", content: literalSource)
        XCTAssertEqual(fullyParsed.getChildNodes().count, 1)
        XCTAssertTrue(fullyParsed.childNode(0) is DataNode)

        let context = try target("style")
        let parsedFragment = try Parser.parseFragment(literalSource, context, [])
        XCTAssertEqual(parsedFragment.count, 1)
        XCTAssertTrue(parsedFragment[0] is TextNode)
        XCTAssertEqual((parsedFragment[0] as? TextNode)?.getWholeText(), literalSource)

        try context.append(literalSource)
        XCTAssertEqual(context.getChildNodes().count, 1)
        XCTAssertTrue(context.childNode(0) is TextNode)
        XCTAssertEqual(contents(of: context), contents(of: fullyParsed))
    }

    func testRcdataFragmentContextsStillDecodeReferencesAndKeepMarkupLiteral() throws {
        let expected = "alpha&<b>literal</b>A日本😀"
        for tag in ["title", "textarea"] {
            let fullyParsed = try target(tag, content: literalSource)
            XCTAssertEqual(contents(of: fullyParsed), expected, tag)

            for mutate in [
                { (element: Element) throws in try element.append(self.literalSource) },
                { (element: Element) throws in try element.prepend(self.literalSource) },
                { (element: Element) throws in try element.html(self.literalSource) }
            ] {
                let element = try target(tag)
                try mutate(element)
                XCTAssertEqual(contents(of: element), contents(of: fullyParsed), tag)
                XCTAssertTrue(element.children().isEmpty, tag)
            }
        }
    }

    func testScriptDataFragmentContextRemainsCompatible() throws {
        let fullyParsed = try target("script", content: literalSource)
        XCTAssertEqual(contents(of: fullyParsed), literalSource)
        XCTAssertTrue(fullyParsed.childNode(0) is DataNode)

        for mutate in [
            { (element: Element) throws in try element.append(self.literalSource) },
            { (element: Element) throws in try element.prepend(self.literalSource) },
            { (element: Element) throws in try element.html(self.literalSource) }
        ] {
            let element = try target("script")
            try mutate(element)
            XCTAssertEqual(contents(of: element), contents(of: fullyParsed))
            XCTAssertTrue(element.childNode(0) is TextNode)
        }
    }
}
