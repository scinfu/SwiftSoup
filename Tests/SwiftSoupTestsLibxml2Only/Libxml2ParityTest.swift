import XCTest
@testable import SwiftSoup

#if canImport(CLibxml2) || canImport(libxml2)

final class Libxml2ParityTest: SwiftSoupTestCase {
    private struct Sample {
        let name: String
        let html: String
        let baseUri: String?
        let selectors: [String]
        let absUrlTests: [(selector: String, attr: String)]
    }

    private func normalizeOutput(_ doc: Document) {
        doc.outputSettings().prettyPrint(pretty: false)
    }

    private struct ElementSignature: Equatable {
        let tag: String
        let text: String
        let attributes: [(String, String)]

        static func == (lhs: ElementSignature, rhs: ElementSignature) -> Bool {
            guard lhs.tag == rhs.tag, lhs.text == rhs.text else { return false }
            return lhs.attributes.elementsEqual(rhs.attributes, by: { $0.0 == $1.0 && $0.1 == $1.1 })
        }
    }

    private func elementSignatures(_ elements: Elements) throws -> [ElementSignature] {
        return try elements.array().map { element in
            let attrs: [(String, String)]
            if let attributes = element.getAttributes() {
                attrs = attributes.asList()
                    .map { ($0.getKey(), $0.getValue()) }
                    .sorted { $0.0 < $1.0 }
            } else {
                attrs = []
            }
            return ElementSignature(
                tag: element.tagName(),
                text: try element.text(),
                attributes: attrs
            )
        }
    }

    func testLibxml2ParityCorpus() throws {
        let samples: [Sample] = [
            Sample(
                name: "Basic nesting",
                html: "<html><head><title>One</title></head><body><div id=main class='a b'><p>Hello <b>there</b></p></div></body></html>",
                baseUri: nil,
                selectors: ["#main", ".a", "div > p", "b", "p:contains(Hello)"],
                absUrlTests: []
            ),
            Sample(
                name: "Attribute tokenization",
                html: "<img /onerror='doMyJob' src=x><div data-foo=bar></div>",
                baseUri: nil,
                selectors: ["img[onerror]", "div[data-foo]"],
                absUrlTests: []
            ),
            Sample(
                name: "Implied tags",
                html: "<div><p>One<p>Two</div>",
                baseUri: nil,
                selectors: ["div > p", "p"],
                absUrlTests: []
            ),
            Sample(
                name: "Tables and foster parenting",
                html: "<table><tr><td>Cell</table>",
                baseUri: nil,
                selectors: ["table", "tr", "td"],
                absUrlTests: []
            ),
            Sample(
                name: "Comments and doctype",
                html: "<!doctype html><!--c--><div>Hi</div>",
                baseUri: nil,
                selectors: ["div"],
                absUrlTests: []
            ),
            Sample(
                name: "Script and style data",
                html: "<style>.x{color:red}</style><script>var x=1<2;</script>",
                baseUri: nil,
                selectors: ["style", "script"],
                absUrlTests: []
            ),
            Sample(
                name: "Namespaces and svg",
                html: "<svg><text>Hi</text></svg>",
                baseUri: nil,
                selectors: ["svg", "text"],
                absUrlTests: []
            ),
            Sample(
                name: "AbsUrl resolution",
                html: "<a href=/path>Link</a>",
                baseUri: "https://example.com/base/",
                selectors: ["a"],
                absUrlTests: [("a", "href")]
            )
        ]

        for (index, sample) in samples.enumerated() {
            let swiftDoc: Document
            let libDoc: Document
            if let base = sample.baseUri {
                swiftDoc = try SwiftSoup.parse(sample.html, base, backend: .swiftSoup)
                libDoc = try SwiftSoup.parse(sample.html, base, backend: .libxml2(swiftSoupParityMode: .swiftSoupParity))
            } else {
                swiftDoc = try SwiftSoup.parse(sample.html, backend: .swiftSoup)
                libDoc = try SwiftSoup.parse(sample.html, backend: .libxml2(swiftSoupParityMode: .swiftSoupParity))
            }

            normalizeOutput(swiftDoc)
            normalizeOutput(libDoc)

            XCTAssertEqual(try swiftDoc.title(), try libDoc.title(), "Title mismatch: \(sample.name) [\(index)]")
            XCTAssertEqual(try swiftDoc.text(), try libDoc.text(), "Text mismatch: \(sample.name) [\(index)]")

            for selector in sample.selectors {
                let swiftEls = try swiftDoc.select(selector)
                let libEls = try libDoc.select(selector)
                XCTAssertEqual(swiftEls.size(), libEls.size(), "Selector count mismatch '\(selector)': \(sample.name) [\(index)]")
                XCTAssertEqual(try elementSignatures(swiftEls), try elementSignatures(libEls), "Selector signature mismatch '\(selector)': \(sample.name) [\(index)]")
            }

            for test in sample.absUrlTests {
                let swiftEl = try swiftDoc.select(test.selector).first()
                let libEl = try libDoc.select(test.selector).first()
                let swiftAbs = try swiftEl?.absUrl(test.attr) ?? ""
                let libAbs = try libEl?.absUrl(test.attr) ?? ""
                XCTAssertEqual(swiftAbs, libAbs, "absUrl mismatch '\(test.selector)[\(test.attr)]': \(sample.name) [\(index)]")
            }
        }
    }
}

#endif
