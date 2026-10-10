import XCTest
@testable import SwiftSoup

/// HTML parsing must retain the attributes selectors see in browser DOMs.
final class BrowserParityTest: XCTestCase {
    private final class RecordedErrors: ParseErrorList {
        var recorded: [ParseError] = []
        init() { super.init(16, 64) }
        override func add(_ error: ParseError) {
            recorded.append(error)
            super.add(error)
        }
    }

    private func tokenizerErrors(_ html: String) throws -> [ParseError] {
        let errors = RecordedErrors()
        let tokenizer = Tokeniser(CharacterReader(html), errors, ParseSettings.htmlDefault)
        while !(try tokenizer.read()).isEOF() {}
        return errors.recorded
    }

    func testDuplicateErrorPrecedesInvalidValueAndUsesNamePosition() throws {
        let html = "<p id='first' id='&#;'>"
        let errors = try tokenizerErrors(html)
        XCTAssertEqual(errors.first?.getErrorMessage(), "Duplicate attribute")
        XCTAssertEqual(errors.first?.getPosition(), Array("<p id='first' id".utf8).count)
        XCTAssertTrue(errors.dropFirst().contains { $0.getErrorMessage().contains("character reference") })
    }

    func testDuplicateErrorAtNameEOFAndBeforeValueEOF() throws {
        for suffix in ["id", "id ", "id='unfinished", "id=unfinished"] {
            let html = "<p id='first' " + suffix
            let duplicates = try tokenizerErrors(html).filter { $0.getErrorMessage() == "Duplicate attribute" }
            XCTAssertEqual(duplicates.count, 1, suffix)
            XCTAssertEqual(duplicates.first?.getPosition(), Array("<p id='first' id".utf8).count, suffix)
        }
    }

    func testMalformedNamesAfterWhitespaceStartANewAttribute() throws {
        for name in ["x\u{0}", "x\"", "x'", "x<"] {
            let html = "<p \(name)='first' \(name)='last'></p>"
            let p = try XCTUnwrap(SwiftSoup.parse(html).select("p").first())
            let key = name.replacingOccurrences(of: "\u{0}", with: "\u{fffd}")
            XCTAssertEqual(try p.attr(key), "first")
            XCTAssertEqual(p.getAttributes()?.size(), 1)
        }
        let p = try XCTUnwrap(SwiftSoup.parse("<p a \u{0}='second'></p>").select("p").first())
        XCTAssertTrue(p.hasAttr("a"))
        XCTAssertEqual(try p.attr("\u{fffd}"), "second")
        XCTAssertEqual(p.getAttributes()?.size(), 2)
    }

    func testDuplicateRemovalAndMutationCannotResurrectDiscardedValues() throws {
        for trackSource in [true, false] {
            let parser = Parser.htmlParser().settings(ParseSettings(false, false, trackSource))
            let html = "<p id='first' id='last' class='first' class='last' data-v='one&amp;two' data-v='discarded'>日本語</p>"
            let doc = try parser.parseInput(html, "")
            let p = try XCTUnwrap(doc.select("p").first())
            _ = p.getAttributes()?.clone()
            try p.removeAttr("id")
            try p.attr("class", "edited")
            let out = doc.outputSettings().prettyPrint(pretty: false)
            for reuseSource in [true, false] {
                let serialized = try p.outerHtmlUTF8Internal(out, allowRawSource: reuseSource)
                let reparsed = try SwiftSoup.parse(Data(serialized))
                let updated = try XCTUnwrap(reparsed.select("p").first())
                XCTAssertFalse(updated.hasAttr("id"))
                XCTAssertEqual(try updated.className(), "edited")
                XCTAssertEqual(try updated.attr("data-v"), "one&two")
                XCTAssertEqual(try updated.text(), "日本語")
            }
        }
    }
    func testRepeatedAttributeNameKeepsTheFirstOccurrence() throws {
        let doc = try SwiftSoup.parse(#"<a class="movie-list-subject cr2" href="/s" class="hot-item">t</a><input class="first" class="second">"#)
        XCTAssertEqual(try doc.select("a").first()?.className(), "movie-list-subject cr2")
        XCTAssertEqual(try doc.select("input").first()?.className(), "first")
        XCTAssertEqual(try doc.select(".hot-item, .second").size(), 0)
    }

    func testBlockStartTagClosesAnOpenParagraph() throws {
        let doc = try SwiftSoup.parse(#"<li><p class="vodlist_title"><center><a href="/voddetail/1/">t</a></center></p></li>"#)
        XCTAssertEqual(try doc.select("[class*='title'] a").size(), 0)
        XCTAssertEqual(try doc.select("p.vodlist_title").first()?.children().size(), 0)
        XCTAssertEqual(try doc.select("li > center > a").size(), 1)
    }

    func testMixedCaseBooleanAndEmptyDuplicatesAcrossInputTypes() throws {
        let html = "<input CLASS='first' class='second' disabled disabled='later' value='' value='later'>"
        for doc in [try SwiftSoup.parse(html), try SwiftSoup.parse(Data(html.utf8))] {
            let input = try XCTUnwrap(doc.select("input").first())
            let attrs = try XCTUnwrap(input.getAttributes())
            XCTAssertEqual(try input.className(), "first")
            XCTAssertEqual(try input.attr("value"), "")
            XCTAssertTrue(attrs.asList().first { $0.getKey() == "disabled" } is BooleanAttribute)
            XCTAssertFalse(attrs.asList().first { $0.getKey() == "value" } is BooleanAttribute)
            XCTAssertEqual(attrs.size(), 3)
            try input.attr("class", "edited")
            XCTAssertEqual(try input.className(), "edited")
        }
    }

    func testDuplicatesAcrossIndexBoundaryAndTokenReuse() throws {
        for count in [1, 7, 8, 9, 32, 256] {
            let first = (0..<count).map { "data-k\($0)='first-\($0)'" }.joined(separator: " ")
            let later = (0..<count).reversed().map { "DATA-K\($0)='later'" }.joined(separator: " ")
            let html = "<p \(first) \(later)></p><p data-k0='next'></p>"
            let doc = try SwiftSoup.parse(html)
            let ps = try doc.select("p")
            let p = try XCTUnwrap(ps.first())
            XCTAssertEqual(p.getAttributes()?.size(), count)
            for i in 0..<count { XCTAssertEqual(try p.attr("data-k\(i)"), "first-\(i)") }
            XCTAssertEqual(try ps.get(1).attr("data-k0"), "next")
        }
    }

    func testCasePreservingHTMLAndXMLKeepDistinctNames() throws {
        for parser in [Parser.htmlParser().settings(ParseSettings.preserveCase), Parser.xmlParser()] {
            let doc = try parser.parseInput("<p A='first' a='lower' A='last'></p>", "")
            let attrs = try XCTUnwrap(doc.select("p").first()?.getAttributes())
            XCTAssertEqual(attrs.get(key: "A"), "first")
            XCTAssertEqual(attrs.get(key: "a"), "lower")
            XCTAssertEqual(attrs.size(), 2)
        }
    }

    func testPrefilterCollisionsNeverDiscardDistinctNames() throws {
        var groups: [UInt64: [String]] = [:]
        for i in 0..<512 {
            let name = "data-collision-\(i)"
            let pending = Attributes.PendingAttribute(nameSlice: nil, nameBytes: Array(name.utf8), hasUppercase: false, value: .none)
            let mask = try XCTUnwrap(pending.canonicalNameMask())
            groups[mask, default: []].append(name)
        }
        let collisionMask = try XCTUnwrap(groups.keys.sorted().first { groups[$0]!.count >= 9 })
        let names = groups[collisionMask]!.prefix(9)
        let html = "<p " + names.map { "\($0)='first'" }.joined(separator: " ") + " " + names.map { "\($0)='last'" }.joined(separator: " ") + "></p>"
        let p = try XCTUnwrap(SwiftSoup.parse(html).select("p").first())
        XCTAssertEqual(p.getAttributes()?.size(), names.count)
        for name in names { XCTAssertEqual(try p.attr(name), "first") }
    }

    func testTrimmedTokenNamesAndResetReleaseTheIndex() throws {
        let token = Token.StartTag()
        for (name, value) in [(" title ", "first"), ("title", "last"), (" \t", "invalid")] {
            token.appendAttributeName(Array(name.utf8))
            token.appendAttributeValue(ByteSlice.fromArray(Array(value.utf8)))
            try token.newAttribute()
        }
        let first = token.getAttributes()
        XCTAssertEqual(first.get(key: "title"), "first")
        XCTAssertEqual(first.size(), 1)
        token.reset()
        token.appendAttributeName(Array("title".utf8))
        token.appendAttributeValue(ByteSlice.fromArray(Array("next".utf8)))
        try token.newAttribute()
        XCTAssertEqual(token.getAttributes().get(key: "title"), "next")
        XCTAssertEqual(first.get(key: "title"), "first")
    }

    func testDuplicateAttributesConsumeTheParseErrorBudget() throws {
        let parser = Parser.htmlParser().setTrackErrors(1)
        let doc = try parser.parseInput("<!doctype html><p id='first' id='last'></p>", "")
        XCTAssertFalse(parser.getErrors().canAddError())
        XCTAssertEqual(try doc.select("p").first()?.id(), "first")
        _ = try parser.parseInput("<!doctype html><p id='only'></p>", "")
        XCTAssertTrue(parser.getErrors().canAddError())
    }

    func testEveryDuplicateConsumesOneErrorBudgetSlot() throws {
        for duplicates in [2, 7, 8, 9, 32] {
            let repeats = String(repeating: " id='last'", count: duplicates)
            let html = "<!doctype html><p id='first'\(repeats)></p><p id='next'></p>"
            for limit in [1, duplicates, duplicates + 1] {
                let parser = Parser.htmlParser().setTrackErrors(limit)
                let doc = try parser.parseInput(html, "")
                let ps = try doc.select("p")
                XCTAssertEqual(ps.first()?.id(), "first")
                XCTAssertEqual(ps.get(1).id(), "next")
                let errors = parser.getErrors()
                XCTAssertEqual(errors.canAddError(), limit > duplicates)
                if limit > duplicates {
                    errors.add(ParseError(0, "budget probe"))
                    XCTAssertFalse(errors.canAddError(), "each duplicate must consume exactly one slot")
                }
            }
        }
    }

    func testIndexResetAfterManyUniqueAttributesAndDuplicates() throws {
        let token = Token.StartTag()
        for i in 0..<32 {
            token.appendAttributeName(Array("data-k\(i)".utf8))
            token.appendAttributeValue(ByteSlice.fromArray(Array("first".utf8)))
            try token.newAttribute()
        }
        token.appendAttributeName(Array("data-k0".utf8))
        token.appendAttributeValue(ByteSlice.fromArray(Array("last".utf8)))
        try token.newAttribute()
        token.reset() // Exercise reset before transferring the indexed batch.
        token.appendAttributeName(Array("data-k0".utf8))
        token.appendAttributeValue(ByteSlice.fromArray(Array("next".utf8)))
        try token.newAttribute()
        let attrs = token.getAttributes()
        XCTAssertEqual(attrs.get(key: "data-k0"), "next")
        XCTAssertEqual(attrs.size(), 1)
    }

    func testDeferredDeduplicationMatchesFirstWinsReference() throws {
        let names = ["A", "a", " id ", "id", "class", " foo", "foo ", "foo", " \t", "data-κ", "data-Κ"]
        var seed: UInt64 = 462
        let token = Token.StartTag()
        for count in [0, 1, 7, 8, 9, 32, 128] {
            for run in 0..<20 {
                token.reset()
                var expected: [String: String] = [:]
                var order: [String] = []
                for i in 0..<count {
                    seed = seed &* 6364136223846793005 &+ 1
                    let name = names[Int(seed >> 32) % names.count]
                    let value = "\(run)-\(i)"
                    let bytes = Array(name.utf8)
                    if i.isMultiple(of: 2) { token.appendAttributeName(bytes) }
                    else { token.appendAttributeName(ByteSlice.fromArray(bytes)) }
                    token.appendAttributeValue(ByteSlice.fromArray(Array(value.utf8)))
                    try token.newAttribute()
                    let key = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !key.isEmpty && expected[key] == nil {
                        expected[key] = value
                        order.append(key)
                    }
                }
                let attrs = token.getAttributes()
                for (key, value) in expected { XCTAssertEqual(attrs.get(key: key), value) }
                XCTAssertEqual(attrs.asList().map { $0.getKey() }, order)
                for (key, value) in expected { XCTAssertEqual(attrs.get(key: key), value) }
            }
        }
    }
}
