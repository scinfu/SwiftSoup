import XCTest
@testable import SwiftSoup

final class DeferredAttributeLegacyContractTest: XCTestCase {
    private func pending(_ pairs: [(String, String?)]) throws -> Attributes {
        let token = Token.StartTag()
        for (key, value) in pairs {
            token.appendAttributeName(Array(key.utf8))
            if let value {
                if value.isEmpty { token.setEmptyAttributeValue() }
                else { token.appendAttributeValue(ByteSlice.fromArray(Array(value.utf8))) }
            }
            try token.newAttribute()
        }
        return token.getAttributes()
    }

    func testTextNodeBytePresenceBeforeAnyOtherAttributeAccess() throws {
        let text = TextNode("before", "")
        XCTAssertNil(text.attributes)
        XCTAssertTrue(text.hasAttr(Array("text".utf8)))
        XCTAssertTrue(text.hasAttr(Array("TeXt".utf8)))
        XCTAssertFalse(text.hasAttr(Array("missing".utf8)))
        XCTAssertEqual(text.getWholeText(), "before")
        XCTAssertTrue(text.hasAttr("text"))
    }

    func testDuplicateValueIsStableAcrossMaterialization() throws {
        for padding in [0, 1, 8] {
            let pairs: [(String, String?)] = [("duplicate", "before"), ("duplicate", "after")]
                + (0..<padding).map { ("k\($0)", "v\($0)") }
            let attributes = try pending(pairs)
            // HTML5 tokenizer: the repeated name is dropped, so the first value wins.
            XCTAssertEqual(attributes.get(key: "duplicate"), "before")
            XCTAssertEqual(try attributes.getIgnoreCase(key: "DUPLICATE"), "before")
            XCTAssertEqual(String(decoding: try attributes.getIgnoreCaseSlice(key: Array("duplicate".utf8)), as: UTF8.self), "before")
            XCTAssertEqual(attributes.size(), padding + 1)
            XCTAssertEqual(attributes.get(key: "duplicate"), "before")
        }
    }

    func testCaseVariantsRetainFirstKeyPositionAndFirstExactValue() throws {
        for pairs in [
            [("A", "first"), ("a", "lower"), ("A", "last")],
            [("A", "first"), ("A", "last"), ("a", "lower")]
        ] {
            let attributes = try pending(pairs.map { ($0.0, Optional($0.1)) })
            XCTAssertEqual(attributes.get(key: "A"), "first")
            XCTAssertEqual(attributes.get(key: "a"), "lower")
            XCTAssertEqual(try attributes.getIgnoreCase(key: "a"), "first")
            XCTAssertEqual(attributes.size(), 2)
            XCTAssertEqual(try attributes.getIgnoreCase(key: "a"), "first")
            XCTAssertEqual(attributes.asList().map { $0.getKey() }, ["A", "a"])
        }
    }

    func testTrimmedAndMalformedKeysHaveStablePresence() throws {
        let attributes = try pending([(" title ", "trimmed"), (" \t", "invalid")])
        XCTAssertEqual(attributes.get(key: "title"), "trimmed")
        XCTAssertTrue(attributes.hasKey(key: "title"))
        XCTAssertFalse(attributes.hasKey(key: " title "))
        XCTAssertFalse(attributes.hasKey(key: " \t"))
        XCTAssertEqual(try attributes.getIgnoreCase(key: "TITLE"), "trimmed")
        XCTAssertEqual(attributes.size(), 1)
        XCTAssertEqual(attributes.get(key: "title"), "trimmed")
    }

    func testDeferredHTMLMatchesMaterializedAttributeHTML() throws {
        let attributes = try pending([("checked", nil), ("duplicate", "before"), ("duplicate", "after"), (" title ", "x"), (" \t", "invalid")])
        let before = try attributes.html()
        _ = attributes.size()
        XCTAssertEqual(before, try attributes.html())
    }

    func testMalformedPresenceChecksStartFromFreshDeferredStorage() throws {
        for key in [" title ", " \t", ""] {
            let attributes = try pending([(" title ", "trimmed"), (" \t", "invalid")])
            XCTAssertFalse(attributes.hasKey(key: key), key)
            XCTAssertFalse(attributes.hasKeyIgnoreCase(key: Array(key.utf8)), key)
        }
    }

    func testDuplicateIdsAndClassesAgreeWithWarmedSelectors() throws {
        let html = "<p id='old' id='new' class='before' class='after' data-v='one' data-v='two'></p>"
        for firstRead in 0..<4 {
            let doc = try SwiftSoup.parse(html)
            let p = try XCTUnwrap(doc.body()?.child(0))
            let attrs = try XCTUnwrap(p.getAttributes())
            // HTML5 tokenizer: repeated attribute names are dropped, the first occurrence wins.
            if firstRead == 0 { XCTAssertEqual(try p.attr("id"), "old") }
            if firstRead == 1 { XCTAssertTrue(try doc.select("#old").first() === p) }
            if firstRead == 2 { XCTAssertTrue(try doc.select(".before").first() === p) }
            if firstRead == 3 { _ = attrs.clone() }
            for _ in 0..<3 {
                XCTAssertEqual(try p.attr("id"), "old")
                XCTAssertTrue(try doc.select("#old.before[data-v=one]").first() === p)
                XCTAssertEqual(try doc.select("#new, .after, [data-v=two]").size(), 0)
                _ = attrs.asList()
            }
        }
    }

    func testAppendingAfterADeferredReadInvalidatesCanonicalView() throws {
        let attrs = try pending([("data-v", "first")])
        XCTAssertEqual(attrs.get(key: "data-v"), "first")
        attrs.appendPending(Attributes.PendingAttribute(nameSlice: ByteSlice.fromArray(Array("data-v".utf8)), nameBytes: nil, hasUppercase: false, value: .bytes(Array("last".utf8))))
        XCTAssertEqual(attrs.get(key: "data-v"), "last")
        XCTAssertEqual(attrs.size(), 1)
        XCTAssertEqual(attrs.get(key: "data-v"), "last")
    }

    func testAmbiguousDeferredReadsMaterializeWithoutDirtyingOwners() throws {
        let doc = try SwiftSoup.parse("<p id='old' id='new' class='before' class='after'></p>")
        let p = try XCTUnwrap(doc.body()?.child(0))
        let attrs = try XCTUnwrap(p.getAttributes())
        XCTAssertTrue(attrs.attributes.isEmpty)
        let dirty = p.sourceRangeDirty
        let version = doc.textMutationVersion
        // Repeated names are dropped by the tokenizer (first wins), so the batch is
        // no longer ambiguous; reads must still not dirty the owner or the source.
        XCTAssertEqual(try p.attr("id"), "old")
        _ = try attrs.html()
        XCTAssertEqual(attrs.get(key: "class"), "before")
        XCTAssertEqual(p.sourceRangeDirty, dirty)
        XCTAssertEqual(doc.textMutationVersion, version)
    }

    func testBooleanExplicitValuesSerializeConsistently() throws {
        for key in ["disabled", "DISABLED", "custom"] {
            for value in [nil, "", key, key.lowercased(), "different"] as [String?] {
                for syntax in [OutputSettings.Syntax.html, .xml] {
                    let attrs = try pending([(key, value)])
                    let out = OutputSettings().syntax(syntax: syntax)
                    let before = StringBuilder()
                    try attrs.html(accum: before, out: out)
                    _ = attrs.size()
                    let after = StringBuilder()
                    try attrs.html(accum: after, out: out)
                    XCTAssertEqual(before.toString(), after.toString(), "\(key)=\(String(describing: value)), \(syntax)")
                }
            }
        }
    }

    func testReadsPreserveSourceReuseAndStableRegeneratedSerialization() throws {
        let html = "<p id='old' id='new' class='before' class='after'>日本語</p>"
        let doc = try SwiftSoup.parse(html)
        let p = try XCTUnwrap(doc.body()?.child(0))
        let settings = doc.outputSettings().prettyPrint(pretty: false)
        let original = try p.outerHtmlUTF8Internal(settings, allowRawSource: true)
        let regenerated = try p.outerHtmlUTF8Internal(settings, allowRawSource: false)
        XCTAssertEqual(p.getAttributes()?.get(key: "id"), "old")
        XCTAssertEqual(try p.attr("id"), "old")
        _ = p.getAttributes()?.asList()
        XCTAssertEqual(try p.outerHtmlUTF8Internal(settings, allowRawSource: true), original)
        XCTAssertEqual(try p.outerHtmlUTF8Internal(settings, allowRawSource: false), regenerated)
        try p.attr("id", "edited")
        let edited = try SwiftSoup.parse(String(decoding: p.outerHtmlUTF8Internal(settings, allowRawSource: true), as: UTF8.self))
        XCTAssertEqual(try edited.select("#edited.before").size(), 1)
        XCTAssertEqual(try edited.select("#old, #new, .after").size(), 0)
    }

    func testTextBytePresenceOnParsedNodesDoesNotDirtySourceOrRestoreRemovedText() throws {
        let doc = try SwiftSoup.parse("<p>日本語</p>")
        let p = try XCTUnwrap(doc.body()?.child(0))
        let text = try XCTUnwrap(p.getChildNodes().first as? TextNode)
        let dirty = text.sourceRangeDirty
        let version = doc.textMutationVersion
        XCTAssertNil(text.attributes)
        XCTAssertTrue(text.hasAttr(Array("TEXT".utf8)))
        XCTAssertEqual(text.sourceRangeDirty, dirty)
        XCTAssertEqual(doc.textMutationVersion, version)
        try text.removeAttr(Array("text".utf8))
        XCTAssertFalse(text.hasAttr(Array("text".utf8)))
        XCTAssertEqual(text.getWholeText(), "")
    }
}
