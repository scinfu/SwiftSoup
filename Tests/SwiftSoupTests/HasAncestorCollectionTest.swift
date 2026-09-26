import Foundation
import XCTest
@testable import SwiftSoup

final class HasAncestorCollectionTest: XCTestCase {
    func testOverlappingMatchesPreserveScopeAndDocumentOrder() throws {
        let doc = try SwiftSoup.parseXML("<outside class='hit'><root class='hit'><a class='hit'><b class='hit'/><c><d class='hit'/></c></a><e><f class='hit'/></e><empty/></root><sibling class='hit'/></outside>")
        let root = try XCTUnwrap(doc.select("root").first())
        let evaluator = StructuralEvaluator.Has(Evaluator.Class("hit"))
        for scope in [doc, root] {
            let expected = try scope.getAllElements().array().filter { try evaluator.matches(scope, $0) }
            XCTAssertEqual(try Collector.collect(evaluator, scope).array().map(ObjectIdentifier.init), expected.map(ObjectIdentifier.init))
        }
        XCTAssertEqual(try Collector.collect(evaluator, root).array().map { $0.tagName() }, ["root", "a", "c", "e"])
        let empty = try XCTUnwrap(root.select("empty").first())
        try empty.addClass("hit")
        XCTAssertTrue(try Collector.collect(evaluator, empty).isEmpty())
    }

    func testDeepAndBranchedMatchesAreCollectedOnce() throws {
        let depth = 256
        let xml = "<root>" + String(repeating: "<level class='hit'><leaf class='hit'/>", count: depth) + String(repeating: "</level>", count: depth) + "</root>"
        let doc = try SwiftSoup.parseXML(xml)
        let root = try XCTUnwrap(doc.children().first())
        let evaluator = StructuralEvaluator.Has(Evaluator.Class("hit"))
        let matches = try Collector.collect(evaluator, root).array()
        XCTAssertEqual(matches.count, depth + 1)
        XCTAssertTrue(matches.first === root)
        XCTAssertEqual(Set(matches.map(ObjectIdentifier.init)).count, matches.count)
        XCTAssertTrue(matches.dropFirst().allSatisfy { $0.tagName() == "level" })
    }

    func testHasAncestorProfile() throws {
        let env = ProcessInfo.processInfo.environment
        guard env["SWIFTSOUP_HAS_PROFILE"] == "1" else {
            throw XCTSkip("Set SWIFTSOUP_HAS_PROFILE=1 to measure uncached :has ancestor collection")
        }
        let depth = max(1, Int(env["SWIFTSOUP_HAS_PROFILE_DEPTH"] ?? "1000") ?? 1000)
        let iterations = max(1, Int(env["SWIFTSOUP_HAS_PROFILE_ITERATIONS"] ?? "50") ?? 50)
        let xml = "<root>" + String(repeating: "<level class='hit'>", count: depth) + String(repeating: "</level>", count: depth) + "</root>"
        let doc = try SwiftSoup.parseXML(xml)
        let root = try XCTUnwrap(doc.children().first())
        let evaluator = StructuralEvaluator.Has(Evaluator.Class("hit"))
        for _ in 0..<2 { XCTAssertEqual(try Collector.collect(evaluator, root).size(), depth) }
        var checksum = 0
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations { checksum += try Collector.collect(evaluator, root).size() }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        XCTAssertEqual(checksum, depth * iterations)
        print("Has ancestor elapsed: \(elapsed) ms over \(iterations) iterations at depth \(depth)")
    }
}
