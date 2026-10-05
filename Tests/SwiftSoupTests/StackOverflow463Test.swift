import Foundation
import XCTest
@testable import SwiftSoup

final class StackOverflow463Test: XCTestCase {
    private func deepHTML(depth: Int) -> String {
        String(repeating: "<div>", count: depth) + "x"
            + String(repeating: "</div>", count: depth)
    }

    private func runOnSmallStack(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ operation: @escaping @Sendable () throws -> Void
    ) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            defer { done.signal() }
            do {
                try operation()
            } catch {
                XCTFail("Small-stack operation failed: \(error)", file: file, line: line)
            }
        }
        thread.stackSize = 512 * 1024
        thread.start()
        XCTAssertEqual(done.wait(timeout: .now() + 30), .success, file: file, line: line)
    }

    func testDeepSerializationWithoutSourceReuseOnSmallStack() throws {
        let inner = deepHTML(depth: 3_000)
        // Build the fixture on the caller's stack to isolate serialization.
        nonisolated(unsafe) let document = try SwiftSoup.parse(inner)
        document.outputSettings().prettyPrint(pretty: false)
        runOnSmallStack {
            let body = try XCTUnwrap(document.body())
            XCTAssertEqual(try body.htmlUTF8WithoutSourceReuse(), Array(inner.utf8))
            let output = StringBuilder()
            try body.outerHtmlFast(output, 0, document.outputSettings(), allowRawSource: false)
            XCTAssertEqual(output.toString(), "<body>" + inner + "</body>")
        }
    }

    func testDeepMutationAndSourceReuseSerializationOnSmallStack() throws {
        let depth = 3_000
        nonisolated(unsafe) let document = try SwiftSoup.parse(
            "<html><head></head><body>" + deepHTML(depth: depth) + "</body></html>"
        )
        document.outputSettings().prettyPrint(pretty: false)
        // Resolve the target before starting the thread to isolate dirty propagation.
        nonisolated(unsafe) let leaf = try XCTUnwrap(document.select("div").last())
        let expected = String(repeating: "<div>", count: depth - 1)
            + "<div data-x=\"1\">x</div>"
            + String(repeating: "</div>", count: depth - 1)
        runOnSmallStack {
            try leaf.attr("data-x", "1")
            XCTAssertTrue(leaf.sourceRangeDirty)
            let body = try XCTUnwrap(document.body())
            XCTAssertTrue(body.childNode(0).sourceRangeDirty)
            // The mutation dirties every ancestor, preventing a clean-source shortcut.
            XCTAssertEqual(try body.html(), expected)
            XCTAssertEqual(try body.outerHtml(), "<body>" + expected + "</body>")
        }
    }

    func testTraversalPreservesDepthOrderAndChildSnapshot() throws {
        let root = RecordingNode("root")
        let left = RecordingNode("left")
        let right = RecordingNode("right")
        try root.appendChild(left)
        try root.appendChild(right)
        try left.appendChild(RecordingNode("leaf"))
        left.onHead = {
            try right.remove()
            try root.appendChild(RecordingNode("added"))
        }
        defer { left.onHead = nil }
        let output = StringBuilder()
        try root.outerHtmlFastWithoutSourceReuse(output, 7, OutputSettings())
        // As with recursive for-in traversal, the parent's original child snapshot
        // includes the removed sibling and excludes the subsequently added sibling.
        XCTAssertEqual(output.toString(),
            "<root:7><left:8><leaf:9></leaf:9></left:8><right:8></right:8></root:7>")
    }

    func testChildrenAddedDuringHeadAreIncludedInSnapshot() throws {
        let root = RecordingNode("root")
        root.onHead = { try root.appendChild(RecordingNode("added")) }
        defer { root.onHead = nil }
        let output = StringBuilder()
        try root.outerHtmlFastWithoutSourceReuse(output, 4, OutputSettings())
        XCTAssertEqual(output.toString(), "<root:4><added:5></added:5></root:4>")
    }

    func testFormattingMatchesRecursiveTraversal() throws {
        let fixtures = [
            (false, "<!doctype html><html><head><title>A &amp; B</title></head><body>"
                + "<section>before<span title='日本 &amp;'>日本 &amp; text</span>after"
                + "<!--comment--><br><pre> a\n b </pre><script>if (a < b) x()</script>"
                + "<div><p>nested</p><p></p></div></section></body></html>"),
            (true, "<?xml version='1.0'?><Root a='日本 &amp;'><Empty/>before"
                + "<Child><![CDATA[a < b]]></Child><!--comment--><Nested><Leaf/></Nested>"
                + "after</Root>")
        ]
        for (xml, source) in fixtures {
            let document = try (xml ? Parser.xmlParser() : Parser.htmlParser())
                .parseInput(source, "")
            for pretty in [false, true] {
                for outline in [false, true] {
                    for charset in [String.Encoding.utf8, .ascii] {
                        for mode in [Entities.EscapeMode.base, .extended, .xhtml] {
                            for depth in [0, 5] {
                                let settings = document.outputSettings()
                                    .prettyPrint(pretty: pretty).outline(outlineMode: outline)
                                    .indentAmount(indentAmount: 3).charset(charset).escapeMode(mode)
                                let expected = StringBuilder()
                                try serializeRecursively(document, expected, depth, settings)
                                let actual = StringBuilder()
                                try document.outerHtmlFastWithoutSourceReuse(actual, depth, settings)
                                XCTAssertEqual(actual.toString(), expected.toString(),
                                    "xml=\(xml), pretty=\(pretty), outline=\(outline), "
                                    + "charset=\(charset), mode=\(mode), depth=\(depth)")
                            }
                        }
                    }
                }
            }
        }
    }

    // Keep this oracle recursive and fixtures shallow: it reproduces the original
    // callback order independently of the continuation-frame implementation.
    private func serializeRecursively(
        _ node: Node, _ output: StringBuilder, _ depth: Int, _ settings: OutputSettings
    ) throws {
        try node.outerHtmlHead(output, depth, settings)
        for child in node.childNodes {
            try serializeRecursively(child, output, depth + 1, settings)
        }
        try node.outerHtmlTail(output, depth, settings)
    }

    func testDetachingActiveSubtreePreservesAncestorContinuations() throws {
        let root = RecordingNode("root")
        let first = RecordingNode("first")
        try first.appendChild(RecordingNode("leaf"))
        try root.addChildren(first, RecordingNode("later"))
        first.onHead = {
            for child in root.childNodes { try child.remove() }
        }
        defer { first.onHead = nil }
        let output = StringBuilder()
        try root.outerHtmlFastWithoutSourceReuse(output, 2, OutputSettings())
        XCTAssertTrue(root.childNodes.isEmpty)
        XCTAssertNil(first.parent())
        XCTAssertEqual(output.toString(),
            "<root:2><first:3><leaf:4></leaf:4></first:3><later:3></later:3></root:2>")
    }

    func testWideTreePreservesAllSiblings() throws {
        let inner = "<section>" + String(repeating: "<i>x</i><b>y</b>", count: 1_024) + "</section>"
        let document = try SwiftSoup.parse(inner)
        document.outputSettings().prettyPrint(pretty: false)
        XCTAssertEqual(try document.body()?.htmlUTF8WithoutSourceReuse(), Array(inner.utf8))
    }

    func testThrowingHeadStopsBeforeLaterSiblingsAndTails() throws {
        let root = RecordingNode("root")
        let first = RecordingNode("first")
        let failing = RecordingNode("failing")
        try root.appendChild(first)
        try root.appendChild(failing)
        try root.appendChild(RecordingNode("later"))
        failing.onHead = { throw SerializationFailure.expected }
        let output = StringBuilder()
        XCTAssertThrowsError(try root.outerHtmlFastWithoutSourceReuse(output, 0, OutputSettings())) {
            XCTAssertTrue($0 is SerializationFailure)
        }
        XCTAssertEqual(output.toString(), "<root:0><first:1></first:1><failing:1>")
    }

    func testThrowingAncestorTailStopsBeforeLaterSiblings() throws {
        let root = RecordingNode("root")
        let first = RecordingNode("first")
        try first.appendChild(RecordingNode("leaf"))
        try root.appendChild(first)
        try root.appendChild(RecordingNode("later"))
        first.onTail = { throw SerializationFailure.expected }
        let output = StringBuilder()
        XCTAssertThrowsError(try root.outerHtmlFastWithoutSourceReuse(output, 3, OutputSettings())) {
            XCTAssertTrue($0 is SerializationFailure)
        }
        XCTAssertEqual(output.toString(), "<root:3><first:4><leaf:5></leaf:5></first:4>")
    }

    func testReusedSubtreeSkipsCallbacksAndPreservesFollowingSiblingDepth() throws {
        let source = "<raw><nested/></raw>"
        let document = Document("")
        document.sourceBuffer = SourceBuffer(Array(source.utf8), parsedAsXml: false)
        document.outputSettings().prettyPrint(pretty: false)
        let root = RecordingNode("root")
        let reused = RecordingNode("reused")
        let hidden = RecordingNode("hidden")
        let following = RecordingNode("following")
        try reused.appendChild(hidden)
        try following.appendChild(RecordingNode("leaf"))
        try root.addChildren(reused, following)
        try document.addChildren(root)
        // Model a complete source-backed subtree; its visitor callbacks must be skipped.
        reused.setSourceRange(SourceRange(start: 0, end: source.utf8.count), complete: true)
        reused.onHead = { XCTFail("Reused subtree head must not run") }
        reused.onTail = { XCTFail("Reused subtree tail must not run") }
        hidden.onHead = { XCTFail("Reused descendants must not be visited") }
        let output = StringBuilder()
        try root.outerHtmlFast(output, 5, document.outputSettings(), allowRawSource: true)
        XCTAssertEqual(output.toString(),
            "<root:5>" + source + "<following:6><leaf:7></leaf:7></following:6></root:5>")
    }

    func testForcedDirtyPropagationBypassesBulkBuildSuppression() throws {
        let source = "<html><head></head><body><p>value</p></body></html>"
        let document = try SwiftSoup.parse(source)
        document.outputSettings().prettyPrint(pretty: false)
        let paragraph = try XCTUnwrap(document.select("p").first())
        let builder = TreeBuilder()
        builder.doc = document
        builder.isBulkBuilding = true
        paragraph.treeBuilder = builder
        defer { builder.isBulkBuilding = false }
        try paragraph.attr("data-state", "changed")
        // Bulk parsing suppresses dirty propagation, keeping the source reusable.
        XCTAssertEqual(try document.outerHtml(), source)
        paragraph.markSourceDirty(force: true)
        XCTAssertEqual(try document.outerHtml(),
            source.replacingOccurrences(of: "<p>", with: "<p data-state=\"changed\">"))
    }

    func testDirtyPropagationStopsAtAncestorGuards() throws {
        for alreadyDirty in [false, true] {
            for force in [false, true] {
                for register in [false, true] {
                    let document = Document("")
                    let ancestor = RecordingNode("ancestor")
                    let boundary = RecordingNode("boundary")
                    let leaf = RecordingNode("leaf")
                    try document.addChildren(ancestor)
                    try ancestor.addChildren(boundary)
                    try boundary.addChildren(leaf)
                    // Reset construction bookkeeping to isolate the parent walk.
                    for node in [document, ancestor, boundary, leaf] {
                        node.sourceRangeDirty = false
                    }
                    document.dirtySourceRoots.removeAll()
                    let builder = TreeBuilder()
                    builder.doc = document
                    builder.isBulkBuilding = true
                    boundary.treeBuilder = builder
                    defer { builder.isBulkBuilding = false }
                    boundary.sourceRangeDirty = alreadyDirty
                    leaf.markSourceDirty(force: force, registerDirtyRoot: register)
                    let reachesRoot = force && !alreadyDirty
                    XCTAssertTrue(leaf.sourceRangeDirty)
                    XCTAssertEqual(boundary.sourceRangeDirty, alreadyDirty || force)
                    XCTAssertEqual(ancestor.sourceRangeDirty, reachesRoot)
                    XCTAssertEqual(document.sourceRangeDirty, reachesRoot)
                    let roots = document.currentDirtySourceRoots()
                    XCTAssertEqual(roots.count, register ? 1 : 0)
                    if register { XCTAssertTrue(roots.first === leaf) }
                }
            }
        }
    }

    func testAlreadyDirtyNodeCanRegisterAfterRegistrationWasSuppressed() throws {
        let document = try SwiftSoup.parse(
            "<html><head></head><body><p title='source'>value</p></body></html>")
        let paragraph = try XCTUnwrap(document.select("p").first())
        let range = try XCTUnwrap(paragraph.sourceRange)
        // Start with an empty registration set, independently of parser bookkeeping.
        document.dirtySourceRoots.removeAll()
        paragraph.markSourceDirty(registerDirtyRoot: false)
        XCTAssertTrue(document.currentDirtySourceRoots().isEmpty)
        paragraph.markSourceDirty()
        let roots = document.currentDirtySourceRoots()
        XCTAssertEqual(roots.count, 1)
        XCTAssertTrue(roots.first === paragraph)
        XCTAssertEqual(try document.sourcePatches(), [
            SourcePatch(range: range, replacement: Array("<p title=\"source\">value</p>".utf8))
        ])
    }

    private enum SerializationFailure: Error { case expected }

    private final class RecordingNode: Node {
        private let name: String
        var onHead: (() throws -> Void)?
        var onTail: (() throws -> Void)?

        init(_ name: String) {
            self.name = name
            super.init()
        }

        func appendChild(_ child: Node) throws {
            try addChildren(child)
        }

        override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
            accum.append("<\(name):\(depth)>")
            try onHead?()
        }

        override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
            accum.append("</\(name):\(depth)>")
            try onTail?()
        }
    }
}
