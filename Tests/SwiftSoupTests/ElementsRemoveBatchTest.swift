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

    func testFirstRemovalCallbackKeepsTheOriginalSelectionSnapshot() throws {
        for batched in [false, true] {
            let parent = Element(Tag("div"), "")
            let first = CustomElement(Tag("a"), "")
            let second = Element(Tag("b"), "")
            let third = Element(Tag("i"), "")
            let inserted = Element(Tag("u"), "")
            try parent.appendChild(first).appendChild(second).appendChild(third).appendChild(inserted)
            let selection = Elements([first, second, third])
            var calls = 0
            first.onRemove = { [weak selection] in
                calls += 1
                // The original array iterator ignores later collection edits.
                // Inserting at the next index also catches stale batch ranges
                // being applied to the modified Elements storage.
                selection?.add(1, inserted)
            }
            defer { first.onRemove = nil }

            if batched {
                XCTAssertTrue(try selection.remove() === selection)
            } else {
                for node in selection.array() { try node.remove() }
            }

            XCTAssertEqual(calls, 1, "batched=\(batched)")
            XCTAssertEqual(selection.size(), 4)
            XCTAssertTrue(selection.get(1) === inserted)
            XCTAssertTrue([first, second, third].allSatisfy { $0.parent() == nil })
            XCTAssertTrue(inserted.parent() === parent)
            XCTAssertEqual(parent.getChildNodes().count, 1)
            XCTAssertEqual(inserted.siblingIndex, 0)
        }
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

    func testSingleRemovalInvalidatesCachedState() throws {
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
        enum Order { case forward, reverse, tail }
        let plain = String(repeating: "<a class=x></a>", count: count)
        let workloads: [(String, String, Order)] = [
            ("all siblings", plain, .forward),
            ("every other sibling", String(repeating: "<a class=x></a><b></b>", count: count), .forward),
            ("all siblings reversed", plain, .reverse),
            ("last two siblings reversed", plain, .tail),
        ]
        for (name, children, order) in workloads {
            let doc = try SwiftSoup.parse("<div>" + children + "</div>")
            let matches = try doc.select("a.x")
            let selected: Elements
            switch order {
            case .forward: selected = matches
            case .reverse: selected = Elements(Array(matches.array().reversed()))
            case .tail: selected = Elements(Array(matches.array().suffix(2).reversed()))
            }
            let remaining = matches.size() - selected.size()
            let start = DispatchTime.now().uptimeNanoseconds
            try selected.remove()
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            XCTAssertEqual(try doc.select("a.x").size(), remaining)
            print("Elements.remove \(name) elapsed: \(elapsed) ms for \(selected.size()) elements")
        }

        // Include the selector cache's normal admission cost outside the timer,
        // then measure the same all-sibling removal while snapshots are warm.
        let cachedDocument = try SwiftSoup.parse("<div>" + plain + "</div>")
        let cachedOwner = try XCTUnwrap(cachedDocument.select("div").first())
        let warmSelection = try cachedDocument.select("a.x")
        let cachedOwnerSelection = try cachedOwner.select("a.x")
        for _ in 0..<4 {
            XCTAssertEqual(try cachedDocument.select("a.x").size(), count)
            XCTAssertEqual(try cachedOwner.select("a.x").size(), count)
        }
        XCTAssertNotNil(cachedDocument.cachedSelectorResult("a.x"))
        XCTAssertNotNil(cachedOwner.cachedSelectorResult("a.x"))
        XCTAssertEqual(cachedOwnerSelection.size(), count)
        let cachedStart = DispatchTime.now().uptimeNanoseconds
        try warmSelection.remove()
        let cachedElapsed = Double(DispatchTime.now().uptimeNanoseconds - cachedStart) / 1_000_000
        XCTAssertEqual(try cachedDocument.select("a.x").size(), 0)
        print("Elements.remove warm selector cache elapsed: \(cachedElapsed) ms for \(warmSelection.size()) elements")

        let tailDocument = try SwiftSoup.parse("<div>" + plain + "</div>")
        for _ in 0..<4 { _ = try tailDocument.select("a.x") }
        let retainedMatches = try tailDocument.select("a.x")
        let cachedTail = Elements(Array(retainedMatches.array().suffix(2).reversed()))
        try withExtendedLifetime((tailDocument, retainedMatches)) {
            let tailStart = DispatchTime.now().uptimeNanoseconds
            try cachedTail.remove()
            let tailElapsed = Double(DispatchTime.now().uptimeNanoseconds - tailStart) / 1_000_000
            XCTAssertEqual(try tailDocument.select("a.x").size(), count - cachedTail.size())
            print("Elements.remove warm cached tail elapsed: \(tailElapsed) ms for \(cachedTail.size()) elements")
        }
    }

    private func shape(_ root: Node) -> [String] {
        var pending: [(Node, Int)] = [(root, 0)]
        var result: [String] = []
        while let (node, depth) = pending.popLast() {
            let elementID = (node as? Element)?.id() ?? ""
            let text = (node as? TextNode)?.getWholeText() ?? ""
            result.append("\(depth):\(node.nodeName()):\(elementID):\(text)")
            for child in node.getChildNodes().reversed() { pending.append((child, depth + 1)) }
        }
        return result
    }

    func testBulkRemovalInvalidatesStoredResultsAndExternalTextVersion() throws {
        let doc = try document("<div id=d><a class=x>one</a><b>two</b><a class=x>three</a></div>")
        let div = try XCTUnwrap(doc.getElementById("d"))
        for root: Element in [doc, div] {
            for _ in 0..<3 { XCTAssertEqual(try root.select("a.x").size(), 2) }
            XCTAssertNotNil(root.cachedSelectorResult("a.x"))
        }
        let version = doc.textMutationVersionToken()
        let selected = try doc.select("a.x")
        try selected.remove()
        XCTAssertNotEqual(doc.textMutationVersionToken(), version)
        XCTAssertEqual(try div.text(), "two")
        XCTAssertEqual(try doc.select("a.x").size(), 0)
        XCTAssertEqual(try div.select("a.x").size(), 0)
        XCTAssertTrue(selected.array().allSatisfy { $0.parent() == nil })
        XCTAssertEqual(try div.outerHtml(), "<div id=\"d\"><b>two</b></div>")
        XCTAssertEqual(div.getChildNodes().map(\.siblingIndex), [0])
    }

    func testOrderedBulkSelectionsMatchSequentialPublicRemoval() throws {
        let html = "<main id=r><section id=a><i id=n0 class=x>zero</i>t<!--keep--><b id=n1 class=x>one</b><i id=n2 class=x>two</i></section><form id=b><i id=n3 class=x>three</i><em id=n4 class=x>four</em></form></main>"
        let ids = ["r", "a", "n0", "n1", "n2", "b", "n3", "n4", "detached", "document"]
        let queries = [".x", "i", "[id]", ":contains(zero)", ":empty"]
        var state: UInt64 = 0x475
        func next(_ limit: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(limit))
        }
        for caseIndex in 0..<128 {
            let docs = try [document(html), document(html)]
            var maps: [[String: Element]] = []
            for doc in docs {
                var map = Dictionary(uniqueKeysWithValues: try doc.select("[id]").array().map { ($0.id(), $0) })
                map["detached"] = Element(try Tag.valueOf("u"), "")
                map["document"] = doc
                for key in ["r", "a", "b", "n0"] {
                    for query in queries { for _ in 0..<3 { _ = try map[key]!.select(query) } }
                }
                maps.append(map)
            }
            var selection = (0..<next(13)).map { _ in ids[next(ids.count)] }
            if caseIndex == 0 { selection = ["n0", "a", "n2", "r", "n3", "b", "detached", "a"] }
            for id in selection { try maps[0][id]!.remove() }
            try Elements(selection.map { maps[1][$0]! }).remove()
            XCTAssertEqual(shape(docs[0]), shape(docs[1]), "case \(caseIndex), \(selection)")
            for id in ids {
                let lhs = maps[0][id]!
                let rhs = maps[1][id]!
                XCTAssertEqual(shape(lhs), shape(rhs), "\(caseIndex): \(id)")
                XCTAssertEqual(lhs.parent()?.nodeName(), rhs.parent()?.nodeName())
                XCTAssertEqual((lhs.parent() as? Element)?.id(), (rhs.parent() as? Element)?.id())
                XCTAssertEqual(lhs.siblingIndex, rhs.siblingIndex, "\(caseIndex): \(id)")
                XCTAssertEqual(lhs.textMutationVersionToken(), rhs.textMutationVersionToken(), "\(caseIndex): \(id)")
                XCTAssertEqual(try lhs.text(), try rhs.text())
                XCTAssertEqual(try lhs.outerHtml(), try rhs.outerHtml())
                for query in queries {
                    XCTAssertEqual(try lhs.select(query).array().map { $0.nodeName() + ":" + $0.id() }, try rhs.select(query).array().map { $0.nodeName() + ":" + $0.id() })
                }
                for (index, child) in rhs.getChildNodes().enumerated() {
                    XCTAssertEqual(child.siblingIndex, index)
                    XCTAssertTrue(child.parent() === rhs)
                }
            }
        }
    }
}
