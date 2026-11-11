import XCTest
@testable import SwiftSoup

final class MutationCompatibilityTest: XCTestCase {
    private final class MutatingContext: Element {
        var onParents: (() -> Void)?

        override func parents() -> Elements {
            onParents?()
            return super.parents()
        }
    }

    private final class MutatingSettings: ParseSettings, @unchecked Sendable {
        var onSpan: (() -> Void)?
        var callbackCount = 0

        override func normalizeTag(_ name: [UInt8]) -> [UInt8] {
            if name == Array("SPAN".utf8) {
                callbackCount += 1
                onSpan?()
                return Array("span".utf8)
            }
            return super.normalizeTag(name)
        }
    }

    func testSettingsCallbackCanRenameAnOpenBoundaryDuringPrivateParse() throws {
        for sourceRanges in [false, true] {
            for replaceSettings in [false, true] {
                let settings = MutatingSettings(true, false, sourceRanges)
                let parser = Parser.htmlParser().settings(settings)
                let builder = parser.getTreeBuilder()
                settings.onSpan = { [weak builder] in
                    if let button = builder?.stack.first(where: { $0.tagNameNormal() == "button" }) {
                        try? button.tagName("i")
                        if replaceSettings { builder?.settings = .preserveCase }
                    }
                }
                let document = try parser.parseInput("<p id=outer>a<button id=renamed>b<SPAN>c</span><p id=next>d", "")
                XCTAssertGreaterThan(settings.callbackCount, 0)
                XCTAssertEqual(try XCTUnwrap(document.getElementById("renamed")).tagName(), "i")
                XCTAssertTrue(try XCTUnwrap(document.getElementById("next")).parent() === document.body(), "sourceRanges=\(sourceRanges)")
            }
        }
    }

    func testRetainedRemovedNodesPreserveSequentialSiblingIndexes() throws {
        let selections = [[0, 1, 2], [2, 1, 0], [1, 2, 0], [1, 0, 2], [0, 2, 1], [2, 0, 1], [0, 0, 1, 2]]
        for selection in selections {
            let parents = try [Element(Tag.valueOf("div"), ""), Element(Tag.valueOf("div"), "")]
            let children = try parents.map { parent -> [Element] in
                let nodes = try (0..<3).map { _ in Element(try Tag.valueOf("i"), "") }
                for node in nodes { try parent.appendChild(node) }
                return nodes
            }
            try withExtendedLifetime(parents) {
                for index in selection { try children[0][index].remove() }
                try Elements(selection.map { children[1][$0] }).remove()
                XCTAssertEqual(children[0].map(\.siblingIndex), children[1].map(\.siblingIndex), "\(selection)")
                XCTAssertTrue(children[1].allSatisfy { $0.parent() == nil })
                XCTAssertTrue(parents.allSatisfy { $0.getChildNodes().isEmpty })
            }
        }
    }

    func testFragmentContextSetupCanChangeTheOpenStack() throws {
        for sourceRanges in [false, true] {
            let builder = HtmlTreeBuilder()
            let context = MutatingContext(try Tag.valueOf("div"), "")
            var inserted = false
            context.onParents = { [weak builder] in
                if let builder, let html = builder.stack.first {
                    do {
                        let paragraph = Element(try Tag.valueOf("p"), "")
                        try paragraph.attr("id", "outer")
                        try html.appendChild(paragraph)
                        builder.stack.append(paragraph)
                        inserted = true
                    } catch {
                        XCTFail("\(error)")
                    }
                }
            }
            _ = try builder.parseFragment(Array("<span>c</span><p id=next>d".utf8),
                                          context, [], .noTracking(), ParseSettings(false, false, sourceRanges))
            XCTAssertTrue(inserted)
            XCTAssertTrue(try XCTUnwrap(builder.doc.getElementById("next")).parent() === builder.doc.select("html").first())
        }
    }

    func testBatchRemovedSubtreesCanBeReattachedAfterWarmedQueries() throws {
        let source = try SwiftSoup.parse("<main><section class=x id=a><i>old</i></section><b>keep</b><section class=x id=c><i>other</i></section></main>")
        let destination = try SwiftSoup.parse("<main id=target></main>")
        let removed = try source.select("section.x")
        let inner = try removed.select("i").array()
        for root: Element in [source as Element] + removed.array() + inner {
            for _ in 0..<3 { _ = try root.select("i:contains(old)") }
        }
        for _ in 0..<3 { _ = try destination.select("section.x") }
        try removed.remove()
        let target = try XCTUnwrap(destination.getElementById("target"))
        for node in removed.array() { try target.appendChild(node) }
        try inner[0].text("new")
        XCTAssertEqual(try source.select("section.x").size(), 0)
        XCTAssertEqual(try destination.select("section.x").size(), 2)
        XCTAssertEqual(try destination.select("i:contains(old)").size(), 0)
        XCTAssertEqual(try removed.get(0).select("i:contains(old)").size(), 0)
        XCTAssertEqual(try removed.get(0).select("i:contains(new)").size(), 1)
        XCTAssertTrue(removed.array().allSatisfy { $0.ownerDocument() === destination })
        for (index, child) in target.getChildNodes().enumerated() { XCTAssertEqual(child.siblingIndex, index) }
    }
}
