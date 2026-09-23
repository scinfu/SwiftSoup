import XCTest
import SwiftSoup

final class WildcardNamespaceSelectorTest: XCTestCase {
    private func assertMatches(_ root: Element, _ query: String, _ ids: [String],
                               file: StaticString = #filePath, line: UInt = #line) throws {
        let evaluator = try QueryParser.parse(query)
        XCTAssertEqual(try root.select(evaluator).array().map { $0.id() }, ids,
                       "parsed evaluator: \(query)", file: file, line: line)
        for _ in 0..<3 {
            XCTAssertEqual(try root.select(query).array().map { $0.id() }, ids,
                           query, file: file, line: line)
        }
    }

    func testWildcardIncludesUnprefixedElementsAndRequiresWholeLocalName() throws {
        let document = try SwiftSoup.parse("<main><item id='plain'></item><a:item id='a'></a:item><b:item id='b'></b:item><otheritem id='other'></otheritem><a:otheritem id='suffix'></a:otheritem><itemized id='long'></itemized></main>")
        try assertMatches(document, "*|item", ["plain", "a", "b"])
        try assertMatches(document, "*|ITEM", ["plain", "a", "b"])
        try assertMatches(document, "a|item", ["a"])
        try assertMatches(document, "item", ["plain"])
    }

    func testPreservedTagCaseMatchesInXmlAndProgrammaticTrees() throws {
        let document = try Parser.xmlParser().parseInput("<root><ITEM id='plain'/><NS:Item id='mixed'/><ns:ITEM id='upper'/><ns:item id='lower'/><ns:other id='other'/></root>", "")
        for query in ["*|item", "*|ITEM", "*|ItEm"] {
            try assertMatches(document, query, ["plain", "mixed", "upper", "lower"])
        }
        let added = try document.createElement("Extra:ITEM")
        try added.attr("id", "added")
        try document.children().first()!.appendChild(added)
        try assertMatches(document, "*|item", ["plain", "mixed", "upper", "lower", "added"])
        try assertMatches(document, "NS|ITEM", ["mixed", "upper", "lower"])
    }

    func testWildcardWorksWithCombinatorsAndFilters() throws {
        let document = try SwiftSoup.parse("<main id='main'><item id='a' class='hit' data-v='yes'></item><x:item id='b' class='hit' data-v='yes'></x:item><item id='c'></item><other id='other'></other><section id='nested'><item id='d' class='hit'></item></section></main>")
        try assertMatches(document, "main > *|item.hit[data-v=yes]", ["a", "b"])
        try assertMatches(document, "main > *|item:nth-child(3)", ["c"])
        try assertMatches(document, "*|item + *|item", ["b", "c"])
        try assertMatches(document, "*|item:not(.hit)", ["c"])
        try assertMatches(document, "section:has(> *|item.hit)", ["nested"])
        try assertMatches(document, "main > :not(*|item)", ["other", "nested"])
        try assertMatches(document, "*|item, #a", ["a", "b", "c", "d"])
    }

    func testNamespaceAlternativesStayGroupedAcrossCombinators() throws {
        let document = try SwiftSoup.parse("<main><item id='p'><span id='a'></span></item><ns:item id='q'><span id='b'></span></ns:item><section id='s'><span id='c'></span></section><item id='t'></item><ns:item id='u'></ns:item></main>")
        try assertMatches(document, "*|item > span", ["a", "b"])
        try assertMatches(document, "*|item span", ["a", "b"])
        try assertMatches(document, "*|item + *|item", ["q", "u"])
        try assertMatches(document, "*|item ~ *|item", ["q", "t", "u"])
        try assertMatches(document, "section, *|item > span", ["a", "b", "s"])
        try assertMatches(document, "*|item, section > span", ["p", "q", "c", "t", "u"])
    }

    func testCachedQueriesObserveRetaggingInsertionAndRemoval() throws {
        let document = try Parser.xmlParser().parseInput("<root><item id='a'/><NS:other id='b'/></root>", "")
        let root = try XCTUnwrap(document.children().first())
        let a = try XCTUnwrap(document.getElementById("a"))
        let b = try XCTUnwrap(document.getElementById("b"))
        try assertMatches(root, "*|item", ["a"])
        try a.tagName("other")
        try b.tagName("NS:ITEM")
        try assertMatches(root, "*|item", ["b"])
        try root.appendElement("ITEM").attr("id", "c")
        try assertMatches(root, "*|item", ["b", "c"])
        try b.remove()
        try assertMatches(root, "*|item", ["c"])
        XCTAssertTrue(try b.iS("*|item"))
    }

    func testOverlappingRootsDeduplicateByIdentityAndRetainOrder() throws {
        let document = try Parser.xmlParser().parseInput("<root><item id='a'/><section><NS:ITEM id='b'/></section></root>", "")
        let root = try XCTUnwrap(document.children().first())
        let a = try XCTUnwrap(document.getElementById("a"))
        let b = try XCTUnwrap(document.getElementById("b"))
        let selected = try CssSelector.select("*|item", [a, root, b, root])
        XCTAssertEqual(selected.array().map { $0.id() }, ["a", "b"])
        XCTAssertTrue(selected.first() === a)
        XCTAssertTrue(selected.last() === b)
    }

    func testUnicodeLocalNamesUseTheSameNormalizationAsOrdinaryTags() throws {
        let document = Document("")
        let root = try document.appendElement("root")
        for (tag, id) in [("日本", "plain"), ("NS:日本", "ns"), ("Él", "accent"), ("NS:Él", "accent-ns"), ("él", "different")] {
            try root.appendElement(tag).attr("id", id)
        }
        try assertMatches(document, "*|日本", ["plain", "ns"])
        try assertMatches(document, "*|Él", ["accent", "accent-ns"])
        try assertMatches(document, "*|él", ["different"])
    }

    func testSuffixEvaluatorNormalizesAsciiCaseAndRetainsDescription() throws {
        let root = try Document("").createElement("root")
        let element = try root.appendElement("NS:ITEM")
        for suffix in [":item", ":ITEM", ":ItEm"] {
            let evaluator = Evaluator.TagEndsWith(suffix)
            XCTAssertTrue(try evaluator.matches(root, element))
            XCTAssertEqual(evaluator.toString(), suffix)
        }
        XCTAssertFalse(try Evaluator.TagEndsWith(":otheritem").matches(root, element))
        XCTAssertFalse(try Evaluator.TagEndsWith(":item").matches(root, root))
    }

    func testWildcardRequiresALocalName() {
        for query in ["*|", "*|.hit", "root > *|"] {
            XCTAssertThrowsError(try QueryParser.parse(query), query)
        }
    }
}
