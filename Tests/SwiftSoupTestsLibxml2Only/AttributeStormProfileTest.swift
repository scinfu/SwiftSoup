import Foundation
import XCTest
import SwiftSoup

final class AttributeStormProfileTest: SwiftSoupTestCase {
    func testAttributeStormProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_ATTRIBUTE_STORM_PROFILE"] == "1" else {
            return
        }

        let attrValue = String(repeating: "a=1&b=2&c=3&d=4&token=abcdef;", count: 20)
        let attrs = (0..<32).map { i in
            "data-s\(i)=\"\(attrValue)\""
        }.joined(separator: " ")
        let chunk = """
        <section class="attr-storm" data-kind="bench" \(attrs)>
          <div class="wrap" \(attrs)>
            <a href="/path?\(attrValue)" \(attrs)>Link</a>
            <img src="/img?\(attrValue)" alt="\(attrValue)" \(attrs)>
            <input type="text" name="q" value="\(attrValue)" \(attrs)>
            <span \(attrs)>\(attrValue)</span>
          </div>
        </section>
        """
        let repeatCount = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_ATTRIBUTE_STORM_REPEAT"] ?? "3") ?? 3
        let iterations = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_ATTRIBUTE_STORM_ITERATIONS"] ?? "3") ?? 3
        let html = "<!doctype html><html><head><title>attribute-storm</title></head><body>" +
            String(repeating: chunk, count: max(1, repeatCount)) +
            "</body></html>"

        var parsedCount = 0
        for _ in 0..<max(1, iterations) {
            _ = try SwiftSoup.parse(html)
            parsedCount += 1
        }
        XCTAssertGreaterThan(parsedCount, 0)

        print(Profiler.report(top: 30))
    }
}
