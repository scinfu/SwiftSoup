//
//  PerformanceTest.swift
//  SwiftSoupTests
//

import XCTest
import SwiftSoup

final class PerformanceTest: XCTestCase {

    private func buildManyElements(count: Int) -> String {
        var html = "<div id=wrap>"
        for i in 0..<count {
            let cls = (i % 3 == 0) ? "lead" : "body"
            let href = (i % 5 == 0) ? "one" : "two"
            html += "<p id=p\(i) class=\(cls) href=\(href)>Item \(i)</p>"
        }
        html += "</div>"
        return html
    }

    func testSelectPerformanceIndexedAnd() throws {
        let doc = try SwiftSoup.parse(buildManyElements(count: 2000))
        measure {
            do {
                _ = try doc.select("p.lead[href=one]")
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testTextCachePerformance() throws {
        let doc = try SwiftSoup.parse(buildManyElements(count: 2000))
        _ = try doc.text() // warm cache
        measure {
            do {
                _ = try doc.text()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
