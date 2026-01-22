import Foundation
import XCTest
import SwiftSoup

final class TokenizerProfileTest: XCTestCase {
    func testTokenizerProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_PROFILE"] == "1" else {
            return
        }

        let chunk = """
        <div class="alpha beta" data-x="123" data-y='abc' data-z=foo id="node">
          <span class=inner data-k="v&amp;v">text</span>
          <a href="https://example.com?q=1&x=2" rel="nofollow noopener">link</a>
        </div>
        """

        let html = "<!doctype html><html><head><title>t</title></head><body>" +
            String(repeating: chunk, count: 200) +
            "</body></html>"

        var parsedCount = 0
        for _ in 0..<50 {
            _ = try SwiftSoup.parse(html)
            parsedCount += 1
        }
        XCTAssertGreaterThan(parsedCount, 0)

        print(Profiler.report(top: 30))
    }
}
