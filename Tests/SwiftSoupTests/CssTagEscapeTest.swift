import XCTest
@testable import SwiftSoup

final class CssTagEscapeTest: XCTestCase {
    private func assertMatches(_ root: Element, _ query: String, _ expected: [Element],
                               file: StaticString = #filePath, line: UInt = #line) throws {
        let identities = expected.map(ObjectIdentifier.init)
        for _ in 0..<3 {
            XCTAssertEqual(try root.select(query).map(ObjectIdentifier.init), identities,
                           query, file: file, line: line)
        }
        let evaluator = try QueryParser.parse(query)
        XCTAssertEqual(try Collector.collect(evaluator, root).map(ObjectIdentifier.init), identities,
                       query, file: file, line: line)
        XCTAssertEqual(try root.getAllElements().filter { try evaluator.matches(root, $0) }
            .map(ObjectIdentifier.init), identities, query, file: file, line: line)
    }

    func testEscapedTypeSelectorsInCompoundsAndCombinators() throws {
        let doc = try SwiftSoup.parseXML("<root><my.tag class='hit'><leaf /></my.tag><my class='tag' /><my.tag /></root>")
        let root = try XCTUnwrap(doc.children().first())
        let target = root.child(0)
        try assertMatches(doc, #"my\.tag"#, [target, root.child(2)])
        try assertMatches(doc, #"my\2e tag.hit"#, [target])
        try assertMatches(doc, #"\6d y\2e tag.hit"#, [target])
        try assertMatches(doc, #"root > my\.tag.hit"#, [target])
        try assertMatches(doc, #"my\.tag > leaf"#, [target.child(0)])
        try assertMatches(doc, #"my\.tag:not(:not(.hit))"#, [target])
        try assertMatches(doc, #"root:has(> my\.tag.hit)"#, [root])
    }

    func testNamespaceSeparatorsDifferFromEscapedLiteralPipes() throws {
        let doc = Document("")
        let root = try doc.appendElement("root")
        let names = ["ns:item.name", "item.name", "other:item.name", "ns|item.name", "*|item.name"]
        let elements = try names.map { try root.appendElement($0) }
        try assertMatches(doc, #"ns|item\.name"#, [elements[0]])
        try assertMatches(doc, #"ns\:item\.name"#, [elements[0]])
        try assertMatches(doc, #"*|item\.name"#, Array(elements.prefix(3)))
        try assertMatches(doc, #"ns\|item\.name"#, [elements[3]])
        try assertMatches(doc, #"\*\|item\.name"#, [elements[4]])
    }

    func testGeneratedSelectorsRoundTripUnusualTagNamesAndRepeatedSiblings() throws {
        for name in ["my.tag", "ns:item.name", "_item", "-item", ":item", "item:", "ns|item", "item+name", "item\\name", "item,name", "item(name)", "123", "日本", "a\u{301}", "\u{301}item", "☃"] {
            let doc = Document("")
            let root = try doc.appendElement("root")
            try root.appendElement(name)
            let target = try root.appendElement(name)
            let leaf = try target.appendElement("leaf")
            do {
                try assertMatches(doc, target.cssSelector(), [target])
                try assertMatches(doc, leaf.cssSelector(), [leaf])
            } catch {
                XCTFail("Tag \(name.debugDescription): \(error)")
            }
        }
    }

    func testNamespaceMarkerBeforeCombiningMarkUsesCodePointBoundary() throws {
        let doc = Document("")
        let root = try doc.appendElement("root")
        let plain = try root.appendElement("\u{301}item")
        let namespaced = try root.appendElement("ns:\u{301}item")
        try assertMatches(doc, "*|\u{301}item", [plain, namespaced])
        try assertMatches(doc, "ns|\u{301}item", [namespaced])
        try assertMatches(doc, namespaced.cssSelector(), [namespaced])
    }

    func testWhitespaceAndCombinatorsBeforeCombiningTagName() throws {
        let doc = Document("")
        let root = try doc.appendElement("root")
        let preceding = try root.appendElement("before")
        let target = try root.appendElement("\u{301}item")
        for query in ["root \u{301}item", "root>\u{301}item", "root > \u{301}item",
                      "before+\u{301}item", "before~\u{301}item", "missing,\u{301}item"] {
            try assertMatches(doc, query, [target])
        }
        try assertMatches(root, ">\u{301}item", [target])
        try assertMatches(doc, "before:has(+\u{301}item)", [preceding])
    }

    func testCachedEscapedTagSelectorsObserveMutation() throws {
        let doc = try SwiftSoup.parseXML("<root><my.tag /><other /></root>")
        let root = try XCTUnwrap(doc.children().first())
        let first = root.child(0)
        let second = root.child(1)
        try assertMatches(doc, #"my\.tag"#, [first])
        try first.tagName("other")
        try second.tagName("my.tag")
        try assertMatches(doc, #"my\.tag"#, [second])
    }
}
