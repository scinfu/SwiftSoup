import Foundation
import XCTest
import SwiftSoup

final class AmpersandProfileTest: XCTestCase {
    func testAmpersandProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_AMPERSAND_PROFILE"] == "1" else {
            return
        }

        let textChunk = String(repeating: "a & b & c & token=123 & value=abc & next=def ", count: 400)
        let attrChunk = String(repeating: " data-q=\"a&b&c&token=123&value=abc\" ", count: 40)
        let chunk = """
        <section class="ampersand-heavy" data-kind="bench"\(attrChunk)>
          <h2>Ampersand Heavy</h2>
          <p>\(textChunk)</p>
          <p>\(textChunk)</p>
          <a href="/test?q=a&b&c&token=123&value=abc">link</a>
        </section>
        """
        let repeatCount = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_AMPERSAND_PROFILE_REPEAT"] ?? "5") ?? 5
        let iterations = Int(ProcessInfo.processInfo.environment["SWIFTSOUP_AMPERSAND_PROFILE_ITERATIONS"] ?? "5") ?? 5
        let html = "<!doctype html><html><head><title>ampersand-heavy</title></head><body>" +
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
