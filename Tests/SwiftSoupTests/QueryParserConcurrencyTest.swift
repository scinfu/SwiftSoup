import Foundation
import XCTest

@testable import SwiftSoup

final class QueryParserConcurrencyTest: XCTestCase {
    func testQueryParserCacheThreadSafety() {
        let queries = [
            "div > a[href]",
            "ul li:nth-child(2)",
            "a[href^=http]:not(.external)",
            "table > tbody > tr > td",
            "p:has(span)"
        ]

        let iterations = 2000
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)

        for i in 0..<iterations {
            group.enter()
            queue.async {
                _ = try? QueryParser.parse(queries[i % queries.count])
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10.0)
        XCTAssertEqual(result, .success)
    }
}
