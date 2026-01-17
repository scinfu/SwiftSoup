import Foundation
import XCTest
import SwiftSoup

final class AttributeValueProfileTest: SwiftSoupTestCase {
    func testAttributeValueProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_ATTRIBUTE_PROFILE"] == "1" else {
            return
        }

        let attrValue = String(repeating: "name=swift-soup&token=abcdef0123456789&v=1.0.0&mode=fast;", count: 80)
        let attrs = (0..<24).map { i in
            "data-mega-\(i)=\"\(attrValue)\""
        }.joined(separator: " ")
        let chunk = """
        <section class="attr-mega" data-kind="bench" \(attrs)>
          <div class="wrap" \(attrs)>
            <a href="/path?\(attrValue)" \(attrs)>Link</a>
            <img src="/img?\(attrValue)" alt="\(attrValue)" \(attrs)>
            <input type="text" name="q" value="\(attrValue)" \(attrs)>
          </div>
        </section>
        """
        let repeatCount = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_ATTRIBUTE_PROFILE_REPEAT"] ?? "20") ?? 20
        let iterations = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_ATTRIBUTE_PROFILE_ITERATIONS"] ?? "20") ?? 20
        let html = "<!doctype html><html><head><title>attr-mega</title></head><body>" +
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
