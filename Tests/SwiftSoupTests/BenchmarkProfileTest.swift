import XCTest
import SwiftSoup

final class BenchmarkProfileTest: XCTestCase {
    private func envInt(_ key: String, _ defaultValue: Int) -> Int {
        if let value = ProcessInfo.processInfo.environment[key], let parsed = Int(value) {
            return parsed
        }
        return defaultValue
    }

    private func buildBenchmarkHTML(repeatCount: Int) -> String {
        let chunk = """
        <div class=\"alpha beta\" data-x=\"123\" data-y='abc' data-z=foo id=\"node\">
          <span class=inner data-k=\"v&amp;v\">text</span>
          <a href=\"https://example.com?q=1&x=2\" rel=\"nofollow noopener\">link</a>
          <p class=\"body\">Paragraph <em>emphasis</em> and <strong>strong</strong>.</p>
        </div>
        """

        return "<!doctype html><html><head><title>t</title></head><body>" +
            String(repeating: chunk, count: repeatCount) +
            "</body></html>"
    }

    func testParseBenchmarkProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_BENCHMARK"] == "1" else {
            return
        }

        let repeatCount = envInt("SWIFTSOUP_BENCHMARK_REPEAT", 1000)
        let warmupIterations = envInt("SWIFTSOUP_BENCHMARK_WARMUP", 5)
        let iterations = envInt("SWIFTSOUP_BENCHMARK_ITERATIONS", 60)
        let html = buildBenchmarkHTML(repeatCount: repeatCount)
        let data = Data(html.utf8)
        let bytes = [UInt8](data)

        Profiler.reset()
        let useFastParse = ProcessInfo.processInfo.environment["SWIFTSOUP_FAST_PARSE"] == "1"
        let parser: Parser? = {
            if useFastParse {
                let parser = Parser.htmlParser()
                parser.settings(ParseSettings(false, false, false))
                return parser
            }
            return nil
        }()

        for _ in 0..<warmupIterations {
            let doc: Document
            if let parser {
                doc = try parser.parseInput(bytes, "")
            } else {
                doc = try SwiftSoup.parse(data, "")
            }
            _ = try doc.select("a[href]")
            _ = try doc.text()
        }

        measure {
            do {
                for _ in 0..<iterations {
                    let doc: Document
                    if let parser {
                        doc = try parser.parseInput(bytes, "")
                    } else {
                        doc = try SwiftSoup.parse(data, "")
                    }
                    _ = try doc.select("a[href]")
                    _ = try doc.text()
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        let report = Profiler.report(top: 40)
        if !report.isEmpty {
            print(report)
        }
    }
}
