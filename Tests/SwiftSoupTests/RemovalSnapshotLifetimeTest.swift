import XCTest
@testable import SwiftSoup

final class RemovalSnapshotLifetimeTest: XCTestCase {
    private final class CallbackNode: Element {
        var onDeinit: (() -> Void)?
        deinit { onDeinit?() }
    }

    private struct Outcome: Equatable {
        let callbackCount: Int
        let callbackSawLaterAttached: Bool
        let destinationContainsLater: Bool
        let laterDetached: Bool
        let indexes: [Int]
    }

    // Install a stale snapshot through the cache's normal two-hit admission.
    // This models entries retained across an earlier tree mutation.
    @inline(never)
    private func installSnapshot(owner: Element, payload: Element, root: Node) {
        owner.selectorResultCache = SelectorResultCache(capacity: 8)
        owner.selectorResultCacheRoot = root
        let result = SelectorResultCache.Result(elements: [payload], includesOwner: false)
        owner.selectorResultCache?.put("stale-probe", result)
        owner.selectorResultCache?.put("stale-probe", result)
    }

    private func scenario(cacheOnSelected: Bool, batched: Bool, wrapped: Bool) throws -> Outcome {
        let root = Element(try Tag.valueOf("main"), "")
        let first = Element(try Tag.valueOf("i"), "")
        let later = Element(try Tag.valueOf("b"), "")
        let destination = Element(try Tag.valueOf("section"), "")
        var payload: Element? = Element(try Tag.valueOf("div"), "")
        var callbackNode: CallbackNode? = CallbackNode(try Tag.valueOf("span"), "")
        let callbackCount = Box()
        try payload!.appendChild(callbackNode!)
        var callbackError: String?
        var callbackSawLaterAttached = false
        callbackNode!.onDeinit = {
            callbackCount.value += 1
            callbackSawLaterAttached = later.parent() === root
            do { try destination.appendChild(later) }
            catch { callbackError = String(describing: error) }
        }
        weak var payloadLifetime: Element? = payload
        weak var callbackLifetime: CallbackNode? = callbackNode
        try root.appendChild(first).appendChild(later)
        if wrapped {
            installSnapshot(owner: cacheOnSelected ? first : root, payload: payload!, root: root)
        } else {
            installSnapshot(owner: cacheOnSelected ? first : root, payload: callbackNode!, root: root)
        }
        // Drop every external payload reference; the cache is its sole owner.
        payload = nil
        callbackNode = nil
        XCTAssertNotNil(callbackLifetime)
        let selection = Elements([first, later])
        if batched {
            try selection.remove()
        } else {
            for node in selection { try node.remove() }
        }
        XCTAssertNil(callbackError)
        XCTAssertNil(payloadLifetime)
        XCTAssertNil(callbackLifetime)
        return Outcome(callbackCount: callbackCount.value,
                       callbackSawLaterAttached: callbackSawLaterAttached,
                       destinationContainsLater: destination.getChildNodes().contains { $0 === later },
                       laterDetached: later.parent() == nil,
                       indexes: [first.siblingIndex, later.siblingIndex])
    }

    private final class Box { var value = 0 }

    func testCachedSnapshotReleaseMatchesSequentialRemoval() throws {
        for cacheOnSelected in [false, true] {
            for wrapped in [false, true] {
                let sequential = try scenario(cacheOnSelected: cacheOnSelected, batched: false, wrapped: wrapped)
                let batched = try scenario(cacheOnSelected: cacheOnSelected, batched: true, wrapped: wrapped)
                XCTAssertEqual(sequential.callbackCount, 1)
                XCTAssertTrue(sequential.callbackSawLaterAttached)
                XCTAssertTrue(sequential.laterDetached)
                XCTAssertFalse(sequential.destinationContainsLater)
                XCTAssertEqual(batched, sequential,
                               "cacheOnSelected=\(cacheOnSelected), wrapped=\(wrapped)")
            }
        }
    }

    func testLaterSelectedSnapshotPreservesCallbacksAfterFirstRemoval() throws {
        func run(batched: Bool) throws -> Outcome {
            let root = Element(Tag("main"), "")
            let first = Element(Tag("i"), "")
            let second = Element(Tag("b"), "")
            let later = Element(Tag("u"), "")
            let last = Element(Tag("em"), "")
            let destination = Element(Tag("aside"), "")
            var payload: CallbackNode? = CallbackNode(Tag("span"), "")
            weak var lifetime = payload
            var callbackCount = 0
            var callbackSawLaterAttached = false
            payload!.onDeinit = {
                callbackCount += 1
                XCTAssertNil(first.parent())
                XCTAssertNil(second.parent())
                XCTAssertTrue(last.parent() === root)
                callbackSawLaterAttached = later.parent() === root
                do { try destination.appendChild(later) }
                catch { XCTFail("Unexpected callback reparent error: \(error)") }
            }
            try root.appendChild(first).appendChild(second).appendChild(later).appendChild(last)
            // The first ordinary removal does not clear a later sibling's
            // snapshots. Planning the remaining suffix must notice this owner.
            installSnapshot(owner: second, payload: payload!, root: root)
            payload = nil
            let selected = [first, second, later, last]
            if batched { try Elements(selected).remove() }
            else { for node in selected { try node.remove() } }
            XCTAssertNil(lifetime)
            XCTAssertTrue(root.getChildNodes().isEmpty)
            return Outcome(callbackCount: callbackCount,
                           callbackSawLaterAttached: callbackSawLaterAttached,
                           destinationContainsLater: destination.getChildNodes().contains { $0 === later },
                           laterDetached: later.parent() == nil,
                           indexes: selected.map(\.siblingIndex))
        }

        let expected = try run(batched: false)
        let actual = try run(batched: true)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.callbackCount, 1)
        XCTAssertTrue(actual.callbackSawLaterAttached)
        XCTAssertTrue(actual.laterDetached)
        XCTAssertFalse(actual.destinationContainsLater)
    }

    func testSnapshotRootCycleReleaseMatchesSequentialRemoval() throws {
        func run(batched: Bool) throws -> Outcome {
            var root: Element? = Element(try Tag.valueOf("main"), "")
            var owner: Element? = Element(try Tag.valueOf("section"), "")
            let child = Element(try Tag.valueOf("i"), "")
            let later = Element(try Tag.valueOf("b"), "")
            let destination = Element(try Tag.valueOf("aside"), "")
            var callbackNode: CallbackNode? = CallbackNode(try Tag.valueOf("u"), "")
            let callbackCount = Box()
            var callbackSawLaterAttached = false
            weak var rootLifetime: Element? = root
            callbackNode!.onDeinit = {
                callbackCount.value += 1
                callbackSawLaterAttached = later.parent() != nil
                do { try destination.appendChild(later) }
                catch { XCTFail("Unexpected callback reparent error: \(error)") }
            }
            try owner!.appendChild(child)
            try root!.appendChild(owner!).appendChild(later).appendChild(callbackNode!)
            installSnapshot(owner: owner!, payload: root!, root: root!)
            callbackNode = nil
            owner = nil
            root = nil
            XCTAssertNotNil(rootLifetime, "The snapshot forms the root lifetime cycle")
            let selected = Elements([child, later])
            if batched { try selected.remove() }
            else { for node in selected { try node.remove() } }
            XCTAssertNil(rootLifetime, "Clearing the snapshot must release the cycle")
            return Outcome(callbackCount: callbackCount.value,
                           callbackSawLaterAttached: callbackSawLaterAttached,
                           destinationContainsLater: destination.getChildNodes().contains { $0 === later },
                           laterDetached: later.parent() == nil,
                           indexes: [child.siblingIndex, later.siblingIndex])
        }
        let sequential = try run(batched: false)
        let batched = try run(batched: true)
        XCTAssertEqual(batched, sequential)
        XCTAssertEqual(batched.callbackCount, 1)
        XCTAssertTrue(batched.laterDetached)
        XCTAssertFalse(batched.destinationContainsLater)
    }

    func testWeakParentBacklinkIsNotAnOwningTreeEdge() throws {
        func run(batched: Bool) throws -> Outcome {
            let root = Element(try Tag.valueOf("main"), "")
            let first = Element(try Tag.valueOf("i"), "")
            let later = Element(try Tag.valueOf("b"), "")
            let destination = Element(try Tag.valueOf("section"), "")
            var orphan: Element? = Element(try Tag.valueOf("u"), "")
            var custom: CallbackNode? = CallbackNode(try Tag.valueOf("span"), "")
            let callbackCount = Box()
            var callbackSawLaterAttached = false
            var callbackError: String?
            try orphan!.appendChild(custom!)
            custom!.onDeinit = {
                callbackCount.value += 1
                callbackSawLaterAttached = later.parent() === root
                do { try destination.appendChild(later) }
                catch { callbackError = String(describing: error) }
            }
            try root.appendChild(first).appendChild(later)
            try orphan!.setParentNode(root)
            installSnapshot(owner: root, payload: orphan!, root: root)
            weak var lifetime: Element? = orphan
            custom = nil
            orphan = nil
            XCTAssertNotNil(lifetime)
            XCTAssertFalse(root.getChildNodes().contains { $0 === lifetime })
            let selected = Elements([first, later])
            if batched { try selected.remove() }
            else { for node in selected { try node.remove() } }
            XCTAssertNil(callbackError)
            XCTAssertNil(lifetime)
            return Outcome(callbackCount: callbackCount.value,
                           callbackSawLaterAttached: callbackSawLaterAttached,
                           destinationContainsLater: destination.getChildNodes().contains { $0 === later },
                           laterDetached: later.parent() == nil,
                           indexes: [first.siblingIndex, later.siblingIndex])
        }
        let sequential = try run(batched: false)
        let batched = try run(batched: true)
        XCTAssertEqual(batched, sequential)
        XCTAssertEqual(batched.callbackCount, 1)
        XCTAssertTrue(batched.callbackSawLaterAttached)
    }

}
