import Foundation
import XCTest
@testable import SwiftSoup

final class ElementsRemoveBatchTest: XCTestCase {
    private final class CustomElement: Element {
        var onRemove: (() throws -> Void)?

        override func remove() throws {
            try onRemove?()
            try super.remove()
        }
    }

    func testCustomRemovalKeepsSelectionOrderAndDuplicateCalls() throws {
        let parent = try Element(Tag.valueOf("div"), "")
        let first = try Element(Tag.valueOf("a"), "")
        let custom = try CustomElement(Tag.valueOf("b"), "")
        let last = try Element(Tag.valueOf("i"), "")
        try parent.appendChild(first).appendChild(custom).appendChild(last)
        var calls = 0
        custom.onRemove = {
            XCTAssertNil(first.parent())
            XCTAssertTrue(last.parent() === parent)
            calls += 1
        }
        try Elements([first, custom, custom, last]).remove()
        XCTAssertEqual(calls, 2)
        XCTAssertTrue(parent.getChildNodes().isEmpty)
    }

    func testCustomRemovalPropagatesErrorsBeforeLaterElements() throws {
        enum RemovalError: Error { case stopped }
        let parent = try Element(Tag.valueOf("div"), "")
        let first = try Element(Tag.valueOf("a"), "")
        let custom = try CustomElement(Tag.valueOf("b"), "")
        let last = try Element(Tag.valueOf("i"), "")
        try parent.appendChild(first).appendChild(custom).appendChild(last)
        custom.onRemove = { throw RemovalError.stopped }
        XCTAssertThrowsError(try Elements([first, custom, last]).remove()) { error in
            XCTAssertTrue(error is RemovalError)
        }
        XCTAssertNil(first.parent())
        XCTAssertTrue(custom.parent() === parent)
        XCTAssertTrue(last.parent() === parent)
    }

    private func document(_ html: String) throws -> Document {
        let document = try SwiftSoup.parse(html)
        document.outputSettings().prettyPrint(pretty: false)
        return document
    }

    private func assertSiblingIndexesAreCurrent(_ node: Node, file: StaticString = #filePath, line: UInt = #line) {
        for (index, child) in node.getChildNodes().enumerated() {
            XCTAssertEqual(child.siblingIndex, index, file: file, line: line)
            XCTAssertTrue(child.parent() === node, file: file, line: line)
            assertSiblingIndexesAreCurrent(child, file: file, line: line)
        }
    }

    func testRemovingInterleavedSiblingsKeepsOrderAndIndexes() throws {
        let doc = try document("<div><a class=x>1</a>t<b>2</b><a class=x>3</a><i>4</i><a class=x>5</a></div>")
        let removed = try doc.select("a.x").remove()
        XCTAssertEqual(try XCTUnwrap(doc.body()).html(), "<div>t<b>2</b><i>4</i></div>")
        assertSiblingIndexesAreCurrent(doc)
        XCTAssertEqual(removed.size(), 3)
        XCTAssertTrue(removed.array().allSatisfy { $0.parent() == nil })
    }

    func testRemovingAcrossParentsAndNestedSelections() throws {
        let doc = try document("<div><p class=x>a<span class=x>b</span></p>c</div><section><p class=x>d</p>e</section>")
        let selected = try doc.select(".x")
        XCTAssertEqual(selected.size(), 3)
        try selected.remove()
        XCTAssertEqual(try XCTUnwrap(doc.body()).html(), "<div>c</div><section>e</section>")
        assertSiblingIndexesAreCurrent(doc)
        XCTAssertTrue(selected.array().allSatisfy { $0.parent() == nil })
    }

    func testDuplicateAndDetachedEntriesAreHarmless() throws {
        let doc = try document("<div><a>1</a><b>2</b></div>")
        let link = try XCTUnwrap(doc.select("a").first())
        let other = try SwiftSoup.parse("<u>x</u>")
        let detached = try XCTUnwrap(other.select("u").first())
        try detached.remove()
        try Elements([link, link, detached]).remove()
        XCTAssertEqual(try XCTUnwrap(doc.body()).html(), "<div><b>2</b></div>")
        assertSiblingIndexesAreCurrent(doc)
    }

    func testCachedStateIsInvalidated() throws {
        let doc = try document("<div id=d><a class=x>one</a><b>two</b></div>")
        let div = try XCTUnwrap(doc.getElementById("d"))
        XCTAssertEqual(try div.text(), "onetwo")
        XCTAssertEqual(try doc.select("a.x").size(), 1)
        XCTAssertEqual(div.children().size(), 2)
        try doc.select("a.x").remove()
        XCTAssertEqual(try div.text(), "two")
        XCTAssertEqual(try doc.select("a.x").size(), 0)
        XCTAssertEqual(div.children().size(), 1)
        XCTAssertEqual(try div.outerHtml(), "<div id=\"d\"><b>two</b></div>")
    }

    func testEmptySelectionIsANoOp() throws {
        let doc = try document("<p>a</p>")
        XCTAssertEqual(try doc.select("nothing").remove().size(), 0)
        XCTAssertEqual(try XCTUnwrap(doc.body()).html(), "<p>a</p>")
    }

    func testRemovingTrailingSiblingsAndDuplicatesKeepsPrefix() throws {
        let doc = try document("<div><a>one</a>text<b>two</b><i>three</i><u>four</u></div>")
        let div = try XCTUnwrap(doc.select("div").first())
        let first = try XCTUnwrap(doc.select("a").first())
        let penultimate = try XCTUnwrap(doc.select("i").first())
        let last = try XCTUnwrap(doc.select("u").first())
        try Elements([last, penultimate, last]).remove()
        XCTAssertEqual(try div.html(), "<a>one</a>text<b>two</b>")
        XCTAssertTrue(div.childNode(0) === first)
        XCTAssertNil(last.parent())
        XCTAssertNil(penultimate.parent())
        assertSiblingIndexesAreCurrent(doc)
    }

    /// SWIFTSOUP_REMOVE_PROFILE=1 swift test -c release --filter ElementsRemoveBatchTest/testElementsRemoveProfile
    func testElementsRemoveProfile() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["SWIFTSOUP_REMOVE_PROFILE"] == "1" else {
            throw XCTSkip("Set SWIFTSOUP_REMOVE_PROFILE=1 to measure removing many siblings")
        }
        let count = max(1, Int(environment["SWIFTSOUP_REMOVE_PROFILE_COUNT"] ?? "40000") ?? 40000)
        let workloads = [
            ("all siblings", String(repeating: "<a class=x></a>", count: count)),
            ("every other sibling", String(repeating: "<a class=x></a><b></b>", count: count)),
        ]
        for (name, children) in workloads {
            let doc = try SwiftSoup.parse("<div>" + children + "</div>")
            let selected = try doc.select("a.x")
            let start = DispatchTime.now().uptimeNanoseconds
            try selected.remove()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            XCTAssertEqual(try doc.select("a.x").size(), 0)
            print("Elements.remove \(name) elapsed: \(elapsed) ms for \(selected.size()) elements")
        }
    }
}
