import Foundation
import XCTest
import SwiftSoup
#if canImport(ObjectiveC)
import ObjectiveC
#endif

final class FoundationRemovalCompatibilityTest: XCTestCase {
    #if canImport(ObjectiveC)
    private final class Counter {
        var calls = 0
        var countReads = 0
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
    private final class ReleaseCallback {
        let onRelease: () -> Void
        init(_ onRelease: @escaping () -> Void) { self.onRelease = onRelease }
        deinit { onRelease() }
    }
    private final class CallbackArray: NSArray, @unchecked Sendable {
        var values: [Any] = []
        var onRead: ((Int) -> Void)?
        var onCount: (() -> Void)?
        var onCopy: (() -> Void)?
        override var count: Int {
            onCount?()
            return values.count
        }
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

    private struct CountOutcome: Equatable {
        let countReads: Int
        let result: Outcome
    }

    private enum QueryStorage { case custom, cocoa, native }

    @inline(never)
    private func warm(_ root: Element, _ later: Element, _ destination: Element,
                      _ counter: Counter, mode: Int, storage: QueryStorage) throws {
        let nativeQuery = String(repeating: "x", count: 64)
        if mode == 1 {
            for _ in 0..<4 { _ = try root.select(nativeQuery) }
        }
        var query: String? = autoreleasepool {
            let onRelease = {
                counter.calls += 1
                do { try destination.appendChild(later) }
                catch { counter.error = String(describing: error) }
            }
            if storage != .custom {
                // A heap-backed Cocoa ASCII string supplies contiguous UTF-8,
                // as does native String storage bridged to NSString. Both can
                // retain caller-owned objects through Objective-C associations.
                let object = storage == .cocoa
                    ? NSString(data: Data(nativeQuery.utf8), encoding: String.Encoding.ascii.rawValue)!
                    : nativeQuery as NSString
                let callback = ReleaseCallback(onRelease)
                let key = UnsafeRawPointer(Unmanaged.passUnretained(callback).toOpaque())
                objc_setAssociatedObject(object, key, callback, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                counter.string = object
                let bridged = object as String
                XCTAssertTrue(bridged.isContiguousUTF8, "Exercise retained storage with directly accessible UTF-8")
                return bridged
            }
            let object = CallbackString()
            object.backing = nativeQuery as NSString
            object.onDeinit = onRelease
            counter.string = object
            return object as String
        }
        for _ in 0..<(mode == 2 ? 4 : 1) { _ = try root.select(query!) }
        query = nil
    }

    private func stringScenario(mode: Int, batched: Bool, storage: QueryStorage = .custom) throws -> Outcome {
        let root = Element(Tag("main"), "")
        let first = Element(Tag("i"), "")
        let later = Element(Tag("b"), "")
        let destination = Element(Tag("aside"), "")
        let counter = Counter()
        try root.appendChild(first).appendChild(later)
        try warm(root, later, destination, counter, mode: mode, storage: storage)
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

    private func arrayCountScenario(batched: Bool) throws -> CountOutcome {
        let root = Element(Tag("main"), "")
        let first = Element(Tag("i"), "")
        let later = Element(Tag("b"), "")
        let destination = Element(Tag("aside"), "")
        let counter = Counter()
        try root.appendChild(first).appendChild(later)
        let raw = CallbackArray()
        raw.values = [first, later]
        let array = raw as! [Element]
        let selection = Elements(array)
        // Array's bridged endIndex can call NSArray.count. An extra count
        // read before the original loop moves this callback ahead of removal.
        raw.onCount = {
            counter.countReads += 1
            guard counter.countReads == 2 else { return }
            counter.calls += 1
            do { try destination.appendChild(first) }
            catch { counter.error = String(describing: error) }
        }
        return try withExtendedLifetime((root, destination, raw)) {
            if batched { try selection.remove() }
            else { for node in array { try node.remove() } }
            XCTAssertNil(counter.error)
            return CountOutcome(countReads: counter.countReads,
                                result: Outcome(callbacks: counter.calls,
                                                firstInDestination: first.parent() === destination,
                                                laterDetached: later.parent() == nil,
                                                destinationChildren: destination.children().size()))
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

    func testContiguousCocoaSelectorStringsPreserveRemovalOrder() throws {
        #if canImport(ObjectiveC)
        for mode in 0..<3 {
            let expected = try stringScenario(mode: mode, batched: false, storage: .cocoa)
            let actual = try stringScenario(mode: mode, batched: true, storage: .cocoa)
            XCTAssertEqual(actual, expected, "mode=\(mode)")
            XCTAssertEqual(actual.callbacks, 1)
            XCTAssertTrue(actual.laterDetached)
            XCTAssertEqual(actual.destinationChildren, 0)
        }
        #else
        throw XCTSkip("Requires Objective-C string bridging")
        #endif
    }

    func testNativeSelectorStringsPreserveAssociatedObjectReleaseOrder() throws {
        #if canImport(ObjectiveC)
        for mode in 0..<3 {
            let expected = try stringScenario(mode: mode, batched: false, storage: .native)
            let actual = try stringScenario(mode: mode, batched: true, storage: .native)
            XCTAssertEqual(actual, expected, "mode=\(mode)")
            XCTAssertEqual(actual.callbacks, 1)
            XCTAssertTrue(actual.laterDetached)
            XCTAssertEqual(actual.destinationChildren, 0)
        }
        #else
        throw XCTSkip("Requires Objective-C string bridging")
        #endif
    }

    func testBridgedArrayCountPreservesRemovalOrder() throws {
        #if canImport(ObjectiveC)
        let expected = try arrayCountScenario(batched: false)
        let actual = try arrayCountScenario(batched: true)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.result.callbacks, 1)
        XCTAssertTrue(actual.result.laterDetached)
        #else
        throw XCTSkip("Requires Objective-C array bridging")
        #endif
    }
}
