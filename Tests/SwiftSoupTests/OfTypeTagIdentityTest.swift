import XCTest
import SwiftSoup

final class OfTypeTagIdentityTest: XCTestCase {
    func testMixedSelfClosingSyntaxUsesTheSameElementType() throws {
        for trackSource in [false, true] {
            let doc = try Parser.xmlParser().settings(ParseSettings(true, true, trackSource))
                .parseInput("<root><item id='first' /><item id='second'></item><other /><item id='third' /></root>", "")
            let expected: [(String, [String])] = [
                ("item:first-of-type", ["first"]),
                ("item:last-of-type", ["third"]),
                ("item:nth-of-type(2)", ["second"]),
                ("item:nth-last-of-type(2)", ["second"]),
                ("item:nth-of-type(odd)", ["first", "third"]),
                ("item:only-of-type", [])
            ]
            for (query, ids) in expected {
                XCTAssertEqual(try doc.select(query).array().map { $0.id() }, ids, query)
            }
        }
    }

    func testOnlyOfTypeDoesNotDependOnSelfClosingSyntax() throws {
        let doc = try SwiftSoup.parseXML("<root><item id='first' /><item id='second'></item><other id='only' /></root>")
        XCTAssertEqual(try doc.select("root > :only-of-type").array().map { $0.id() }, ["only"])
    }
}
