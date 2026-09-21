import XCTest
@testable import SwiftSoup

final class SourceSyntaxAdoptionTest: XCTestCase {
    func testCrossSyntaxAdoptionMatchesRebuiltSerialization() throws {
        for donorXML in [false, true] {
            for tracked in [false, true] {
                var donor: Document? = try (donorXML ? Parser.xmlParser() : Parser.htmlParser())
                    .settings(ParseSettings(donorXML, donorXML, tracked))
                    .parseInput("<group><iframe>A&amp;B</iframe></group>", "")
                weak var donorLifetime = donor
                let group = try XCTUnwrap(donor?.select("group").first())
                let receiver = try (donorXML ? Parser.htmlParser() : Parser.xmlParser())
                    .parseInput(donorXML ? "<html><head></head><body></body></html>" : "<root></root>", "")
                receiver.outputSettings().prettyPrint(pretty: false)
                let destination = try XCTUnwrap(donorXML ? receiver.body() : receiver.select("root").first())
                try destination.appendChild(group)
                donor = nil
                XCTAssertNil(donorLifetime)

                XCTAssertEqual(
                    try receiver.outerHtmlUTF8(),
                    try receiver.outerHtmlUTF8WithoutSourceReuse(),
                    "donorXML=\(donorXML), tracked=\(tracked)"
                )
            }
        }
    }

    func testSameSyntaxAdoptionStillPreservesChildSourceSpelling() throws {
        for xml in [false, true] {
            let donor = try (xml ? Parser.xmlParser() : Parser.htmlParser())
                .parseInput("<group><span data-x='one'>A&#38;B</span></group>", "")
            let group = try XCTUnwrap(donor.select("group").first())
            let span = try XCTUnwrap(group.select("span").first())
            let receiver = try (xml ? Parser.xmlParser() : Parser.htmlParser())
                .parseInput(xml ? "<root></root>" : "<body></body>", "")
            receiver.outputSettings().prettyPrint(pretty: false)
            let destination = try XCTUnwrap(xml ? receiver.select("root").first() : receiver.body())
            try destination.appendChild(group)
            XCTAssertEqual(try span.outerHtml(), "<span data-x='one'>A&#38;B</span>")
            XCTAssertEqual(try span.text(), "A&B")
        }
    }
}
