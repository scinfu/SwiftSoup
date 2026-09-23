import XCTest
@testable import SwiftSoup

final class CustomEvaluatorOrderTest: XCTestCase {
    private final class Stateful: Evaluator, @unchecked Sendable {
        var calls: [ObjectIdentifier] = []
        override func matches(_ root: Element, _ element: Element) throws -> Bool {
            calls.append(ObjectIdentifier(element))
            return calls.count.isMultiple(of: 2)
        }
    }

    private func assertOrdered(_ wrap: (Evaluator) -> Evaluator,
                               file: StaticString = #filePath, line: UInt = #line) throws {
        let root = try Element(Tag.valueOf("div"), "")
        try root.html("<i></i><p>one<b></b></p><p>two</p><i></i><p>three</p>")
        for css in [false, true] {
            let reference = Stateful()
            let referenceAnd = CombiningEvaluator.And([wrap(reference), Evaluator.Tag("p")])
            let expected = try root.getAllElements().array().filter { referenceAnd.matches(root, $0) }
            let actual = Stateful()
            let and = CombiningEvaluator.And([wrap(actual), Evaluator.Tag("p")])
            let result = try css ? CssSelector.select(and, root) : Collector.collect(and, root)
            XCTAssertEqual(result.array().map(ObjectIdentifier.init), expected.map(ObjectIdentifier.init),
                           "css=\(css)", file: file, line: line)
            XCTAssertEqual(actual.calls, reference.calls, "css=\(css)", file: file, line: line)
        }
    }

    func testCustomPredicatesKeepDFSCallOrderAndCount() throws {
        try assertOrdered { $0 }
    }

    func testNestedCustomPredicatesCannotBeHiddenByBuiltInWrappers() throws {
        try assertOrdered { CombiningEvaluator.And([$0, Evaluator.AllElements()]) }
        try assertOrdered { CombiningEvaluator.Or([$0, Evaluator.Id("missing")]) }
        try assertOrdered { StructuralEvaluator.Not($0) }
        try assertOrdered { StructuralEvaluator.Has($0) }
        try assertOrdered { StructuralEvaluator.Parent($0) }
        try assertOrdered { StructuralEvaluator.ImmediateParent($0) }
        try assertOrdered { StructuralEvaluator.PreviousSibling($0) }
        try assertOrdered { StructuralEvaluator.ImmediatePreviousSibling($0) }
    }

    private final class RenameBeforeTagMatch: Evaluator, @unchecked Sendable {
        override func matches(_ root: Element, _ element: Element) throws -> Bool {
            if element.tagName() == "i" { try element.tagName("p") }
            return true
        }
    }

    func testMutatingPredicateRunsBeforeIndexedPredicate() throws {
        for css in [false, true] {
            let root = try Element(Tag.valueOf("div"), "")
            try root.html("<i id=changed></i><p id=existing></p>")
            let and = CombiningEvaluator.And([RenameBeforeTagMatch(), Evaluator.Tag("p")])
            let result = try css ? CssSelector.select(and, root) : Collector.collect(and, root)
            XCTAssertEqual(result.array().map { $0.id() }, ["changed", "existing"])
            XCTAssertEqual(try root.select("i").size(), 0)
        }
    }
}
