import XCTest
import Foundation
@testable import SwiftSoup

final class StackOverflow463Test: XCTestCase {

    private func makeDeepHTML(depth: Int) -> String {
        var s = "<html><body>"
        for _ in 0..<depth { s += "<div>" }
        s += "x"
        for _ in 0..<depth { s += "</div>" }
        s += "</body></html>"
        return s
    }

    /// Runs `body` on a Thread with an explicitly small stack and waits for it.
    /// Returns true if the thread finished cleanly. Before the iterative
    /// outerHtmlFast fix a stack overflow crashed the whole process (EXC_BAD_ACCESS).
    private func runOnSmallStack(stackSize: Int, _ body: @escaping @Sendable () -> Void) -> Bool {
        let done = DispatchSemaphore(value: 0)
        let thread = Thread {
            body()
            done.signal()
        }
        thread.stackSize = stackSize // bytes, multiple of 4 KiB
        thread.start()
        return done.wait(timeout: .now() + 30) == .success
    }

    // REGRESSION (#463): deep tree .html() serialization on a small-stack thread.
    // Before the iterative outerHtmlFast fix this overflowed the recursive
    // serialization chain. Parsing is done on the main thread (large stack);
    // only serialization runs on the small stack.
    func testDeepHtmlSerializationOnSmallStackSurvives() throws {
        // 3000 depth matches real-world Outlook emails. Parsing on main thread
        // (large stack); only serialization runs on the small stack.
        let html = makeDeepHTML(depth: 3_000)
        nonisolated(unsafe) let doc = try SwiftSoup.parse(html)
        doc.outputSettings().prettyPrint(pretty: false)
        let ok = runOnSmallStack(stackSize: 512 * 1024) {
            _ = try? doc.body()?.html()
        }
        XCTAssertTrue(ok, "deep .html() serialization overflowed the small-stack thread")
    }

    // REGRESSION (#463): same shape via outerHtml() on a small-stack thread.
    func testDeepOuterHtmlOnSmallStackSurvives() throws {
        let html = makeDeepHTML(depth: 3_000)
        nonisolated(unsafe) let doc = try SwiftSoup.parse(html)
        doc.outputSettings().prettyPrint(pretty: false)
        let ok = runOnSmallStack(stackSize: 512 * 1024) {
            _ = try? doc.body()?.outerHtml()
        }
        XCTAssertTrue(ok, "deep .outerHtml() serialization overflowed the small-stack thread")
    }

    // REGRESSION (#463): setting an attribute on the deepest node triggers
    // markSourceDirty walking up through all ancestors recursively.
    // This overflows a 512 KB thread at ~300 levels before the iterative fix.
    func testDeepMutationMarkSourceDirtyOnSmallStackSurvives() throws {
        let html = makeDeepHTML(depth: 3_000)
        nonisolated(unsafe) let doc = try SwiftSoup.parse(html)
        let ok = runOnSmallStack(stackSize: 512 * 1024) {
            try? doc.body()?.select("div").last()?.attr("data-x", "1")
        }
        XCTAssertTrue(ok, "markSourceDirty walked parent chain and overflowed the small-stack thread")
    }

    // Verify iterative serialization produces correct output.
    func testDeepHtmlSerializationOutputCorrect() throws {
        let html = makeDeepHTML(depth: 500)
        let doc = try SwiftSoup.parse(html)
        doc.outputSettings().prettyPrint(pretty: false)
        let output = try doc.body()!.html()
        XCTAssertTrue(output.contains("x"), "content must survive serialization")
        XCTAssertTrue(output.contains("<div>"), "structure must survive serialization")
        // Verify correct nesting: 500 opening divs and 500 closing divs
        let openCount = output.components(separatedBy: "<div>").count - 1
        let closeCount = output.components(separatedBy: "</div>").count - 1
        XCTAssertEqual(openCount, 500, "must preserve all 500 nested divs")
        XCTAssertEqual(closeCount, 500, "must preserve all 500 closing divs")
    }
}
