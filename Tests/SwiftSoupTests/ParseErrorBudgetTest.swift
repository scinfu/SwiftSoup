import XCTest
@testable import SwiftSoup

final class ParseErrorBudgetTest: XCTestCase {
    func testReservedCapacityDoesNotConsumeTheErrorBudget() {
        for limit in [1, 2, 16, 17, 128] {
            let errors = ParseErrorList.tracking(limit)
            for index in 0..<limit {
                XCTAssertTrue(errors.canAddError(), "limit=\(limit), count=\(index)")
                errors.add(ParseError(index, "probe"))
            }
            XCTAssertFalse(errors.canAddError())
        }
    }

    func testNoTrackingAndZeroBudgetRemainDisabled() {
        XCTAssertFalse(ParseErrorList.noTracking().canAddError())
        XCTAssertFalse(ParseErrorList.tracking(0).canAddError())
    }

    func testParserConsumesBudgetOnlyForErrorsAndResetsItForEachInput() throws {
        let parser = Parser.htmlParser().setTrackErrors(1)
        let valid = "<!doctype html><html><head></head><body><p>valid</p></body></html>"
        _ = try parser.parseInput(valid, "")
        let first = parser.getErrors()
        XCTAssertTrue(first.canAddError())
        _ = try parser.parseInput(valid.replacingOccurrences(of: "valid", with: "&#;"), "")
        let second = parser.getErrors()
        XCTAssertFalse(first === second)
        XCTAssertFalse(second.canAddError())
        XCTAssertTrue(first.canAddError())
        _ = try parser.parseInput(valid, "")
        XCTAssertTrue(parser.getErrors().canAddError())
        parser.setTrackErrors(0)
        _ = try parser.parseInput(valid, "")
        XCTAssertFalse(parser.getErrors().canAddError())
    }
}
