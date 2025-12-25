import XCTest
import SwiftSoup

final class BenchmarkStreamingTest: XCTestCase {
    private func buildBenchmarkHTML(repeatCount: Int) -> [UInt8] {
        let chunk = """
        <div class=\"alpha beta\" data-x=\"123\" data-y='abc' data-z=foo id=\"node\">
          <span class=inner data-k=\"v&amp;v\">text</span>
          <a href=\"https://example.com?q=1&x=2\" rel=\"nofollow noopener\">link</a>
          <p class=\"body\">Paragraph <em>emphasis</em> and <strong>strong</strong>.</p>
        </div>
        """
        let html = "<!doctype html><html><head><title>t</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
        return Array(html.utf8)
    }

    private final class Counter: HtmlTokenReceiver {
        var tagCount = 0
        var textBytes = 0

        func startTag(name: ArraySlice<UInt8>, attributes: Attributes?, selfClosing: Bool) {
            tagCount += 1
        }

        func endTag(name: ArraySlice<UInt8>) {
            tagCount += 1
        }

        func text(_ data: ArraySlice<UInt8>) {
            textBytes += data.count
        }
    }

    func testStreamingBenchmark() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_STREAM_BENCHMARK"] == "1" else {
            return
        }

        let bytes = buildBenchmarkHTML(repeatCount: 300)
        let parser = StreamingHtmlParser()
        let counter = Counter()

        measure {
            for _ in 0..<5 {
                counter.tagCount = 0
                counter.textBytes = 0
                do {
                    try parser.parse(bytes, counter)
                } catch {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        XCTAssertGreaterThan(counter.tagCount, 0)
        XCTAssertGreaterThan(counter.textBytes, 0)
    }
}
