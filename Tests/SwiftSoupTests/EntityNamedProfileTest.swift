import Foundation
import XCTest
import SwiftSoup

final class EntityNamedProfileTest: XCTestCase {
    func testEntityNamedProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_ENTITY_PROFILE"] == "1" else {
            return
        }

        let namedChunk = String(repeating: "&amp; &lt; &gt; &quot; &apos; &nbsp; &copy; &reg; &trade; ", count: 600)
        let attrChunk = String(repeating: " data-x=\"&amp;&amp;&lt;&gt;&quot;&apos;&nbsp;&copy;&reg;&trade;\" ", count: 60)
        let chunk = """
        <section class="entity-named" data-kind="bench"\(attrChunk)>
          <h2>Entity Named</h2>
          <p>\(namedChunk)</p>
          <p>\(namedChunk)</p>
          <a href="/test?q=&amp;value=&lt;tag&gt;">link</a>
        </section>
        """
        let repeatCount = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_ENTITY_PROFILE_REPEAT"] ?? "5") ?? 5
        let iterations = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_ENTITY_PROFILE_ITERATIONS"] ?? "5") ?? 5
        let html = "<!doctype html><html><head><title>entity-named</title></head><body>" +
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
