import Foundation
import XCTest
@testable import SwiftSoup

final class StackOverflow463Test: XCTestCase {
    private func deepHTML(depth: Int) -> String {
        String(repeating: "<div>", count: depth) + "x"
            + String(repeating: "</div>", count: depth)
    }

    private func runOnSmallStack(_ operation: @escaping @Sendable () throws -> Void) {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            defer { done.signal() }
            do {
                try operation()
            } catch {
                XCTFail("Small-stack operation failed: \(error)")
            }
        }
        thread.stackSize = 512 * 1024
        thread.start()
        XCTAssertEqual(done.wait(timeout: .now() + 30), .success)
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
        let root = try RecordingElement("root")
        let left = try RecordingElement("left")
        let right = try RecordingElement("right")
        try root.appendChild(left)
        try root.appendChild(right)
        try left.appendChild(RecordingElement("leaf"))
        left.onHead = {
            try right.remove()
            try root.appendChild(RecordingElement("added"))
        }
        defer { left.onHead = nil }
        let output = StringBuilder()
        try root.outerHtmlFastWithoutSourceReuse(output, 7, OutputSettings())
        // As with recursive for-in traversal, the parent's original child snapshot
        // includes the removed sibling and excludes the subsequently added sibling.
        XCTAssertEqual(output.toString(),
            "<root:7><left:8><leaf:9></leaf:9></left:8><right:8></right:8></root:7>")
    }

    func testWideTreePreservesAllSiblings() throws {
        let inner = "<section>" + String(repeating: "<i>x</i><b>y</b>", count: 1_024) + "</section>"
        let document = try SwiftSoup.parse(inner)
        document.outputSettings().prettyPrint(pretty: false)
        XCTAssertEqual(try document.body()?.htmlUTF8WithoutSourceReuse(), Array(inner.utf8))
    }

    func testThrowingHeadStopsBeforeLaterSiblingsAndTails() throws {
        let root = try RecordingElement("root")
        let first = try RecordingElement("first")
        let failing = try RecordingElement("failing")
        try root.appendChild(first)
        try root.appendChild(failing)
        try root.appendChild(RecordingElement("later"))
        failing.onHead = { throw SerializationFailure.expected }
        let output = StringBuilder()
        XCTAssertThrowsError(try root.outerHtmlFastWithoutSourceReuse(output, 0, OutputSettings())) {
            XCTAssertTrue($0 is SerializationFailure)
        }
        XCTAssertEqual(output.toString(), "<root:0><first:1></first:1><failing:1>")
    }

    private enum SerializationFailure: Error { case expected }

    private final class RecordingElement: Element {
        var onHead: (() throws -> Void)?

        init(_ name: String) throws {
            super.init(try Tag.valueOf(name), [])
        }

        override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
            accum.append("<\(tagName()):\(depth)>")
            try onHead?()
        }

        override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
            accum.append("</\(tagName()):\(depth)>")
        }
    }
}
