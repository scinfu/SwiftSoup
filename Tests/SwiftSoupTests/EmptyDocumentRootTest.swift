import XCTest
@testable import SwiftSoup

final class EmptyDocumentRootTest: XCTestCase {
    func testEmptyDocumentHasNoRootElement() throws {
        let doc = Document("")
        XCTAssertFalse(try Evaluator.IsRoot().matches(doc, doc))
        XCTAssertEqual(try Collector.collect(Evaluator.IsRoot(), doc).size(), 0)
        for _ in 0..<4 { XCTAssertEqual(try doc.select(":root").size(), 0) }
    }

    func testNonElementChildrenDoNotStandInForADocumentElement() throws {
        let doc = try Parser.xmlParser().parseInput("<!-- comment --><?instruction value?>", "")
        XCTAssertEqual(doc.children().size(), 0)
        XCTAssertEqual(try doc.select(":root").size(), 0)
        let root = try doc.appendElement("root")
        XCTAssertEqual(try doc.select(":root").array().map(ObjectIdentifier.init), [ObjectIdentifier(root)])
    }

    func testWarmRootSelectionTracksInsertionRemovalAndReplacement() throws {
        let doc = Document("")
        for _ in 0..<4 { XCTAssertEqual(try doc.select(":root").size(), 0) }
        let first = try doc.appendElement("first")
        let second = try doc.appendElement("second")
        for _ in 0..<4 { XCTAssertTrue(try doc.select(":root").first() === first) }
        try first.remove()
        for _ in 0..<4 { XCTAssertTrue(try doc.select(":root").first() === second) }
        try second.remove()
        for _ in 0..<4 { XCTAssertEqual(try doc.select(":root").size(), 0) }
    }

    func testElementScopedRootStillMatchesTheScopeElement() throws {
        let scope = try Element(Tag.valueOf("section"), "")
        try scope.appendElement("div")
        XCTAssertTrue(try Evaluator.IsRoot().matches(scope, scope))
        XCTAssertEqual(try scope.select(":root").array().map(ObjectIdentifier.init), [ObjectIdentifier(scope)])
    }
}
