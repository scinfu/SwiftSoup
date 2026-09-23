import Foundation
import XCTest
@testable import SwiftSoup

final class ApostropheReferenceBoundaryTest: XCTestCase {
    func testUnterminatedApostropheReferenceAgreesWithEntityTable() throws {
        XCTAssertFalse(Entities.isBaseNamedEntity(ArraySlice("apos".utf8)))
        XCTAssertNil(Entities.lookupNamedEntity(ByteSlice.fromArray(Array("apos".utf8)), allowExtended: false))
        for suffix in ["", "!", " ", "\n", "日本語", "é", "=value", "-tail", "_tail", "&amp;"] {
            let input = "&apos" + suffix
            let expected = "&apos" + (suffix == "&amp;" ? "&" : suffix)
            for strict in [false, true] {
                XCTAssertEqual(try Entities.unescape(string: input, strict: strict), expected,
                               "strict=\(strict), input=\(input.debugDescription)")
            }
        }
    }

    func testTerminatedApostropheAndLegacySemicolonlessNamesStillDecode() throws {
        for strict in [false, true] {
            for (input, expected) in [("&apos;", "'"), ("&apos;tail", "'tail"), ("&apos;;", "';"),
                                      ("&amp!", "&!"), ("&lt!", "<!"), ("&gt!", ">!"), ("&quot!", "\"!"),
                                      ("&aposz", "&aposz"), ("&apos1", "&apos1")] {
                XCTAssertEqual(try Entities.unescape(string: input, strict: strict), expected, input)
            }
        }
    }

    func testDocumentAndAttributeParsingAcrossStorageEntryPoints() throws {
        let html = "<p title=\"&apos! &apos;\">&apos! &apos;</p><textarea>&apos! &apos;</textarea>"
        let bytes = Array(html.utf8)
        let documents = try [SwiftSoup.parse(html), SwiftSoup.parse(Data(bytes)),
            SwiftSoup.parse(withBytes: { parse in try bytes.withUnsafeBufferPointer { try parse($0) } })]
        for doc in documents {
            let p = try XCTUnwrap(doc.select("p").first())
            XCTAssertEqual(try p.attr("title"), "&apos! '")
            XCTAssertEqual(try p.text(), "&apos! '")
            XCTAssertEqual(try doc.select("textarea").text(), "&apos! '")
            let reparsed = try SwiftSoup.parse(String(decoding: doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self))
            XCTAssertEqual(try reparsed.select("p").text(), "&apos! '")
        }
    }

    func testRejectedFastPathDoesNotConsumeTheNextEntity() throws {
        let input = "&apos&copy;&apos;&amp;&apos!&lt;&apos"
        XCTAssertEqual(try Entities.unescape(input), "&apos©'&&apos!<&apos")
        let reader = CharacterReader("apos!&amp;")
        let tokeniser = Tokeniser(reader, nil, ParseSettings.htmlDefault)
        XCTAssertNil(try tokeniser.consumeCharacterReference(nil, false))
        XCTAssertEqual(reader.getPos(), 0)
        XCTAssertEqual(reader.current(), "a")
    }
}
