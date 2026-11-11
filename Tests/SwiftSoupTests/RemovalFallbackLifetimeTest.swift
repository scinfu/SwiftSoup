import XCTest
import SwiftSoup

final class RemovalFallbackLifetimeTest: XCTestCase {
    private final class Counter { var lookups = 0 }
    private final class CallbackAncestor: Element {
        var counter: Counter?
        var onLookup: (() -> Void)?
        override func ownerDocument() -> Document? {
            counter?.lookups += 1
            onLookup?()
            return super.ownerDocument()
        }
    }
    private struct Outcome: Equatable {
        let indexes: [Int]
        let lookups: Int
        let releasedDuringCallback: Bool?
    }

    private func scenario(dropOwnAncestor: Bool, batched: Bool) throws -> Outcome {
        let counter = Counter()
        var ancestor: CallbackAncestor? = CallbackAncestor(try Tag.valueOf("section"), "")
        var otherRoot: Element? = dropOwnAncestor ? nil : Element(try Tag.valueOf("div"), "")
        let first = Element(try Tag.valueOf("i"), "")
        let second = Element(try Tag.valueOf("b"), "")
        let third = Element(try Tag.valueOf("u"), "")
        ancestor!.counter = counter
        try ancestor!.appendChild(first)
        if dropOwnAncestor {
            try ancestor!.appendChild(second).appendChild(third)
        } else {
            try otherRoot!.appendElement("a")
            try otherRoot!.appendChild(second).appendChild(third)
        }
        weak var lifetime: Node? = dropOwnAncestor ? ancestor : otherRoot
        var releasedDuringCallback: Bool?
        ancestor!.onLookup = { [weak target = ancestor] in
            target?.onLookup = nil
            if dropOwnAncestor {
                ancestor = nil
            } else {
                otherRoot = nil
                releasedDuringCallback = lifetime == nil
            }
        }
        counter.lookups = 0
        let selected = [first, second, third]
        if batched {
            try Elements(selected).remove()
        } else {
            for node in selected { try node.remove() }
        }
        XCTAssertNil(lifetime)
        return Outcome(indexes: selected.map(\.siblingIndex), lookups: counter.lookups,
                       releasedDuringCallback: releasedDuringCallback)
    }

    func testOwnAncestorCanBeReleasedBetweenRemovals() throws {
        let expected = try scenario(dropOwnAncestor: true, batched: false)
        let actual = try scenario(dropOwnAncestor: true, batched: true)
        XCTAssertEqual(actual, expected)
    }

    func testUnrelatedParentIsNotRetainedDuringFallback() throws {
        let expected = try scenario(dropOwnAncestor: false, batched: false)
        let actual = try scenario(dropOwnAncestor: false, batched: true)
        XCTAssertEqual(actual, expected)
    }
}
