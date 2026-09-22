import XCTest
@testable import SwiftSoup

final class CleanerConfiguredScopeValidationTest: XCTestCase {
    private func cleaner() throws -> Cleaner {
        Cleaner(headWhitelist: try Whitelist().addTags("title", "meta").addAttributes("meta", "name"),
                bodyWhitelist: try Whitelist().addTags("p"))
    }

    func testConfiguredHeadTagsAndAttributesParticipateInValidation() throws {
        let validator = try cleaner()
        for head in ["<script>example</script>", "<style>body{}</style>", "<meta name=ok content=removed>", "<!--removed-->"] {
            let doc = try SwiftSoup.parse("<html><head>\(head)</head><body><p>safe</p></body></html>")
            let original = try doc.outerHtmlUTF8WithoutSourceReuse()
            XCTAssertFalse(try validator.isValid(doc), head)
            XCTAssertEqual(try doc.outerHtmlUTF8WithoutSourceReuse(), original)
            XCTAssertTrue(try validator.isValid(validator.clean(doc)))
        }
    }

    func testAllowedHeadAndBodyAndRejectedBody() throws {
        let validator = try cleaner()
        let doc = try SwiftSoup.parse("<html><head><title>safe</title><meta name=ok></head><body><p>safe</p></body></html>")
        XCTAssertTrue(try validator.isValid(doc))
        try XCTUnwrap(doc.body()).appendElement("div")
        XCTAssertFalse(try validator.isValid(doc))
    }

    func testLegacyBodyOnlyValidationDoesNotAcquireAHeadPolicy() throws {
        let doc = try SwiftSoup.parse("<html><head><script>example</script></head><body><p>safe</p></body></html>")
        let bodyOnly = Cleaner(headWhitelist: nil, bodyWhitelist: try Whitelist().addTags("p"))
        XCTAssertTrue(try bodyOnly.isValid(doc))
        XCTAssertTrue(try bodyOnly.clean(doc).select("script").isEmpty())
    }

    func testEmptyAndMissingSectionsDoNotTrap() throws {
        let validator = try cleaner()
        // isValid, like clean, operates on configured sections rather than
        // validating an arbitrary XML document's complete structure.
        XCTAssertTrue(try validator.isValid(Document("")))
        let headOnly = try Parser.xmlParser().parseInput("<html><head><title>safe</title></head></html>", "")
        XCTAssertTrue(try validator.isValid(headOnly))
        try XCTUnwrap(headOnly.head()).appendElement("unsafe")
        XCTAssertFalse(try validator.isValid(headOnly))
        let bodyOnly = try Parser.xmlParser().parseInput("<body><p>safe</p></body>", "")
        XCTAssertTrue(try validator.isValid(bodyOnly))
    }
}
