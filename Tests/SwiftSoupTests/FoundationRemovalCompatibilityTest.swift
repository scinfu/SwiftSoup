import Foundation
import XCTest
import SwiftSoup

final class FoundationRemovalCompatibilityTest: XCTestCase {
    #if canImport(ObjectiveC)
    private final class Counter {
        var calls = 0
        var error: String?
        weak var string: NSString?
    }
    private final class CallbackString: NSString, @unchecked Sendable {
        var backing: NSString = ""
        var onDeinit: (() -> Void)?
        override var length: Int { backing.length }
        override func character(at index: Int) -> unichar { backing.character(at: index) }
        override func copy(with zone: NSZone? = nil) -> Any { self }
        deinit { onDeinit?() }
    }
    private final class CallbackArray: NSArray, @unchecked Sendable {
        var values: [Any] = []
        var onRead: ((Int) -> Void)?
        var onCopy: (() -> Void)?
        override var count: Int { values.count }
        override func object(at index: Int) -> Any {
            onRead?(index)
            return values[index]
        }
        override func copy(with zone: NSZone? = nil) -> Any {
            onCopy?()
            return self
        }
    }
    private struct Outcome: Equatable {
        let callbacks: Int
        let firstInDestination: Bool
        let laterDetached: Bool
        let destinationChildren: Int
    }

    @inline(never)
    private func warm(_ root: Element, _ later: Element, _ destination: Element,
                      _ counter: Counter, mode: Int) throws {
        let nativeQuery = String(repeating: "x", count: 64)
        if mode == 1 {
            for _ in 0..<4 { _ = try root.select(nativeQuery) }
        }
        var query: String? = autoreleasepool {
            let object = CallbackString()
            object.backing = nativeQuery as NSString
            object.onDeinit = {
                counter.calls += 1
                do { try destination.appendChild(later) }
                catch { counter.error = String(describing: error) }
            }
            counter.string = object
            return object as String
        }
        for _ in 0..<(mode == 2 ? 4 : 1) { _ = try root.select(query!) }
        query = nil
    }

    private func stringScenario(mode: Int, batched: Bool) throws -> Outcome {
        let root = Element(Tag("main"), "")
        let first = Element(Tag("i"), "")
        let later = Element(Tag("b"), "")
        let destination = Element(Tag("aside"), "")
        let counter = Counter()
        try root.appendChild(first).appendChild(later)
        try warm(root, later, destination, counter, mode: mode)
        XCTAssertEqual(counter.calls, 0)
        XCTAssertNotNil(counter.string, "Only cache keys or statistics retain the bridged string")
        return try withExtendedLifetime((root, destination)) {
            if batched { try Elements([first, later]).remove() }
            else { for node in [first, later] { try node.remove() } }
            XCTAssertNil(counter.error)
            XCTAssertNil(counter.string)
            return Outcome(callbacks: counter.calls, firstInDestination: first.parent() === destination,
                           laterDetached: later.parent() == nil, destinationChildren: destination.children().size())
        }
    }

    private func arrayScenario(duplicates: Bool, batched: Bool) throws -> Outcome {
        let root = Element(Tag("main"), "")
        let first = Element(Tag("i"), "")
        let later = Element(Tag("b"), "")
        let destination = Element(Tag("aside"), "")
        let counter = Counter()
        try root.appendChild(first).appendChild(later)
        let raw = CallbackArray()
        raw.values = duplicates ? [first, first, later] : [first, later]
        let array = raw as! [Element]
        let selection = Elements(array)
        let trigger = array.count - 1
        raw.onRead = { index in
            guard index == trigger, counter.calls == 0 else { return }
            counter.calls += 1
            do { try destination.appendChild(first) }
            catch { counter.error = String(describing: error) }
        }
        raw.onCopy = { [weak raw] in raw?.onRead?(trigger) }
        return try withExtendedLifetime((root, destination, raw)) {
            if batched { try selection.remove() }
            else { for node in array { try node.remove() } }
            XCTAssertNil(counter.error)
            return Outcome(callbacks: counter.calls, firstInDestination: first.parent() === destination,
                           laterDetached: later.parent() == nil, destinationChildren: destination.children().size())
        }
    }
    #endif

    func testForeignSelectorStringsPreserveRemovalOrder() throws {
        #if canImport(ObjectiveC)
        // Cover first admission, a foreign key used only by hit statistics,
        // and an entry promoted into the protected cache segment.
        for mode in 0..<3 {
            let expected = try stringScenario(mode: mode, batched: false)
            let actual = try stringScenario(mode: mode, batched: true)
            XCTAssertEqual(actual, expected, "mode=\(mode)")
            XCTAssertEqual(actual.callbacks, 1)
            XCTAssertTrue(actual.laterDetached)
            XCTAssertEqual(actual.destinationChildren, 0)
        }
        #else
        throw XCTSkip("Requires Objective-C string bridging")
        #endif
    }

    func testBridgedArrayAccessorsPreserveRemovalOrder() throws {
        #if canImport(ObjectiveC)
        for duplicates in [false, true] {
            let expected = try arrayScenario(duplicates: duplicates, batched: false)
            let actual = try arrayScenario(duplicates: duplicates, batched: true)
            XCTAssertEqual(actual, expected, "duplicates=\(duplicates)")
            XCTAssertEqual(actual.callbacks, 1)
            XCTAssertTrue(actual.firstInDestination)
            XCTAssertTrue(actual.laterDetached)
            XCTAssertEqual(actual.destinationChildren, 1)
        }
        #else
        throw XCTSkip("Requires Objective-C array bridging")
        #endif
    }
}
