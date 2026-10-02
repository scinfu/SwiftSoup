import XCTest
import Foundation
@testable import SwiftSoup

final class StackOverflow393Test: XCTestCase {

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
    /// teardown fix a stack overflow crashed the whole process (EXC_BAD_ACCESS).
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

    // CONTROL A: shallow tree on a small stack — must survive.
    func testShallowOnSmallStackSurvives() {
        let html = makeDeepHTML(depth: 50)
        let ok = runOnSmallStack(stackSize: 512 * 1024) {
            var doc: Document? = try? SwiftSoup.parse(html)
            doc = nil
            _ = doc
        }
        XCTAssertTrue(ok, "shallow teardown should never overflow")
    }

    // CONTROL B: deep tree on the main thread's big stack — must survive.
    func testDeepOnMainThreadSurvives() throws {
        let html = makeDeepHTML(depth: 12_000)
        var doc: Document? = try SwiftSoup.parse(html)
        doc = nil
        _ = doc
    }

    // REGRESSION (#393): deep tree released on a small-stack thread.
    // Before the fix this overflowed the recursive Node.deinit chain.
    func testDeepTeardownOnSmallStackSurvives() {
        let html = makeDeepHTML(depth: 12_000)
        let ok = runOnSmallStack(stackSize: 512 * 1024) {
            var doc: Document? = try? SwiftSoup.parse(html)
            doc = nil // subtree torn down here
            _ = doc
        }
        XCTAssertTrue(ok, "deep teardown overflowed the small-stack thread")
    }

    // REGRESSION (#393): same shape via Element.empty() on a uniquely-held deep subtree.
    func testDeepEmptyOnSmallStackSurvives() {
        let html = makeDeepHTML(depth: 12_000)
        let ok = runOnSmallStack(stackSize: 512 * 1024) {
            guard let doc = try? SwiftSoup.parse(html), let body = doc.body() else { return }
            _ = body.empty()
        }
        XCTAssertTrue(ok, "deep Element.empty() overflowed the small-stack thread")
    }
}
