import XCTest
@testable import SwiftSoup

final class PlaintextFragmentContextTest: XCTestCase {
    private let payload = "A&amp;<b>literal</b></plaintext><p>still text</p>日本😀"

    private func wholeText(_ element: Element) -> String {
        element.textNodes().map { $0.getWholeText() }.joined()
    }

    func testPlaintextFragmentsPreserveMarkupAndCharacterReferences() throws {
        for name in ["plaintext", "PLAINTEXT"] {
            let context = try Element(Tag.valueOf(name, .preserveCase), "")
            let nodes = try Parser.parseFragment(payload, context, [])
            XCTAssertEqual(nodes.count, 1)
            XCTAssertTrue(nodes.allSatisfy { $0 is TextNode })
            XCTAssertEqual(nodes.compactMap { ($0 as? TextNode)?.getWholeText() }.joined(), payload)
        }
    }

    func testPlaintextMutationsAgreeWithFullDocumentParsing() throws {
        for tracked in [false, true] {
            for operation in 0..<3 {
                let parser = Parser.htmlParser().settings(ParseSettings(false, false, tracked))
                let doc = try parser.parseInput("<body><plaintext>seed", "")
                let target = try XCTUnwrap(doc.select("plaintext").first())
                let expected: String
                switch operation {
                case 0:
                    try target.append(payload)
                    expected = "seed" + payload
                case 1:
                    try target.prepend(payload)
                    expected = payload + "seed"
                default:
                    try target.html(payload)
                    expected = payload
                }
                let full = try Parser.htmlParser().parseInput("<body><plaintext>" + expected, "")
                let fullTarget = try XCTUnwrap(full.select("plaintext").first())
                XCTAssertEqual(wholeText(target), wholeText(fullTarget))
                XCTAssertEqual(wholeText(target), expected)
                XCTAssertTrue(target.children().isEmpty)
            }
        }
    }
}
