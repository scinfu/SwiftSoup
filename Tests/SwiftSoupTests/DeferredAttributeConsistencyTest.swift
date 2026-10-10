import XCTest
@testable import SwiftSoup

final class DeferredAttributeConsistencyTest: XCTestCase {
    private func item(_ key: String, _ value: String, bytes: Bool = false) -> Attributes.PendingAttribute {
        let keyBytes = Array(key.utf8)
        return Attributes.PendingAttribute(
            nameSlice: bytes ? nil : ByteSlice.fromArray(keyBytes),
            nameBytes: bytes ? keyBytes : nil,
            hasUppercase: Attributes.containsAsciiUppercase(keyBytes),
            value: .slice(ByteSlice.fromArray(Array(value.utf8))))
    }

    private func deferred(_ pairs: [(String, String)], bytes: Bool = false) -> Attributes {
        Attributes(pendingAttributes: pairs.map { item($0.0, $0.1, bytes: bytes) })
    }

    func testDuplicateExactLookupDoesNotChangeAfterMaterialization() throws {
        for bytes in [false, true] {
            let attrs = deferred([("id", "first"), ("title", "x"), ("id", "last")], bytes: bytes)
            XCTAssertTrue(attrs.attributes.isEmpty)
            XCTAssertEqual(attrs.get(key: "id"), "last")
            XCTAssertEqual(try attrs.getIgnoreCase(key: "ID"), "last")
            XCTAssertEqual(attrs.valueSliceCaseSensitive(Array("id".utf8))?.toArray(), Array("last".utf8))
            XCTAssertEqual(try attrs.getIgnoreCaseSlice(key: Array("ID".utf8)).toArray(), Array("last".utf8))
            XCTAssertEqual(attrs.size(), 2)
            XCTAssertEqual(attrs.get(key: "id"), "last")
        }
    }

    func testIgnoreCaseKeepsFirstVariantButItsLastExactValue() throws {
        for bytes in [false, true] {
            for count in [0, 2, 20] {
                let padding = (0..<count).map { ("k\($0)", "v\($0)") }
                let attrs = deferred(padding + [("ID", "old-upper"), ("id", "lower"), ("ID", "new-upper")], bytes: bytes)
                XCTAssertEqual(try attrs.getIgnoreCase(key: "Id"), "new-upper")
                XCTAssertEqual(try attrs.getIgnoreCaseSlice(key: Array("iD".utf8)).toArray(), Array("new-upper".utf8))
                XCTAssertEqual(attrs.get(key: "id"), "lower")
                _ = attrs.size()
                XCTAssertEqual(try attrs.getIgnoreCase(key: "Id"), "new-upper")
                XCTAssertEqual(attrs.get(key: "id"), "lower")
            }
        }
    }

    func testPaddedNamesAreNormalizedBeforeDeferredLookups() throws {
        for bytes in [false, true] {
            for query in ["id", " id ", "ID", " ID "] {
                let attrs = deferred([(" id ", "value")], bytes: bytes)
                let expected = query == "id" ? "value" : ""
                XCTAssertEqual(attrs.get(key: query), expected, query)
                let insensitive = query == "id" || query == "ID" ? "value" : ""
                XCTAssertEqual(try attrs.getIgnoreCase(key: query), insensitive, query)
                _ = attrs.size()
                XCTAssertEqual(attrs.get(key: query), expected, query)
            }
        }
    }

    func testPaddedSliceLookupDoesNotDependOnWhichGetterRanFirst() throws {
        for bytes in [false, true] {
            let attrs = deferred([(" id ", "value")], bytes: bytes)
            XCTAssertEqual(attrs.valueSliceCaseSensitive(Array("id".utf8))?.toArray(), Array("value".utf8))
            XCTAssertNil(attrs.valueSliceCaseSensitive(Array(" id ".utf8)))
        }
    }

    func testInvalidPendingNamesAreNeverPresent() throws {
        for bytes in [false, true] {
            for key in [" ", "\t", " \n\t "] {
                let attrs = deferred([(key, "discard")], bytes: bytes)
                XCTAssertFalse(attrs.hasKey(key: key))
                XCTAssertFalse(attrs.hasKeyIgnoreCase(key: Array(key.utf8)[...]))
                XCTAssertEqual(attrs.get(key: key), "")
                XCTAssertEqual(attrs.size(), 0)
            }
        }
    }

    func testDeferredSerializationMatchesMaterializedSerialization() throws {
        for bytes in [false, true] {
            for syntax in [OutputSettings.Syntax.html, .xml] {
                let attrs = deferred([("id", "old"), ("title", "日本<&\""), ("id", "new"), (" \t ", "drop"), (" data-x ", "x")], bytes: bytes)
                let settings = OutputSettings().syntax(syntax: syntax)
                let before = StringBuilder()
                try attrs.html(accum: before, out: settings)
                _ = attrs.size()
                let after = StringBuilder()
                try attrs.html(accum: after, out: settings)
                XCTAssertEqual(before.toString(), after.toString())
                XCTAssertEqual(attrs.asList().map { $0.getKey() }, ["id", "title", "data-x"])
                XCTAssertFalse(before.toString().contains("old"))
                XCTAssertFalse(before.toString().contains("drop"))
            }
        }
    }

    func testNameBytesTakePrecedenceOverNameSliceOnEveryPath() throws {
        var pending = item("slice-key", "v")
        pending.nameBytes = Array("byte-key".utf8)
        let attrs = Attributes(pendingAttributes: [pending])
        XCTAssertEqual(try attrs.html(), " byte-key=\"v\"")
        XCTAssertEqual(attrs.get(key: "byte-key"), "v")
        XCTAssertEqual(attrs.get(key: "slice-key"), "")
        XCTAssertEqual(attrs.asList().map { $0.getKey() }, ["byte-key"])
    }

    func testMalformedMissingNameDoesNotLeaveSerializationWhitespace() throws {
        var pending = item("unused", "v")
        pending.nameSlice = nil
        let attrs = Attributes(pendingAttributes: [pending])
        XCTAssertEqual(try attrs.html(), "")
        XCTAssertEqual(attrs.size(), 0)
    }

    func testDuplicateBooleanAndExplicitEmptyValuesAgreeBeforeAndAfter() throws {
        for lastIsBoolean in [false, true] {
            var first = item("custom", "old")
            var last = item("custom", "")
            if lastIsBoolean { last.value = .none } else { first.value = .none }
            let attrs = Attributes(pendingAttributes: [first, item("id", "kept"), last])
            let before = try attrs.html()
            XCTAssertEqual(attrs.get(key: "custom"), "")
            _ = attrs.size()
            XCTAssertEqual(try attrs.html(), before)
            XCTAssertEqual(attrs.asList().first is BooleanAttribute, lastIsBoolean)
        }
    }

    func testFragmentedDuplicateValueKeepsSelectedExactVariant() throws {
        var fragments = item("ID", "unused")
        fragments.value = .slices([ByteSlice.fromArray(Array("日本".utf8)), ByteSlice.fromArray(Array("語".utf8))], 9)
        let attrs = Attributes(pendingAttributes: [item("ID", "old"), item("id", "lower"), fragments])
        XCTAssertEqual(try attrs.getIgnoreCase(key: "id"), "日本語")
        XCTAssertEqual(try attrs.getIgnoreCaseSlice(key: Array("id".utf8)).toArray(), Array("日本語".utf8))
        XCTAssertEqual(attrs.get(key: "id"), "lower")
        _ = attrs.size()
        XCTAssertEqual(try attrs.getIgnoreCase(key: "id"), "日本語")
    }

    func testPublicParsedDuplicateAttributeLookupIsReadOrderIndependent() throws {
        let doc = try SwiftSoup.parse("<p id='old' id='new' class='before' class='after'></p>")
        let p = try XCTUnwrap(doc.body()?.getChildNodes().first as? Element)
        let attrs = try XCTUnwrap(p.getAttributes())
        // HTML5 tokenizer: repeated attribute names are dropped, the first occurrence wins.
        XCTAssertEqual(try p.attr("id"), "old")
        XCTAssertEqual(p.id(), "old")
        XCTAssertEqual(try p.className(), "before")
        _ = attrs.size()
        XCTAssertEqual(try p.attr("id"), "old")
        for _ in 0..<4 {
            XCTAssertEqual(try doc.select("#new, .after").size(), 0)
            XCTAssertTrue(try doc.select("#old.before").first() === p)
        }
    }

    func testDeferredLookupAndSerializationDoNotDirtyOwners() throws {
        let attrs = deferred([("id", "old"), ("id", "new"), (" \t ", "drop")])
        let element = Element(try Tag.valueOf("p"), "", attrs)
        let version = element.textMutationVersionToken()
        let dirty = element.sourceRangeDirty
        XCTAssertEqual(try element.attr("id"), "new")
        let before = try attrs.html()
        _ = attrs.size()
        XCTAssertEqual(try attrs.html(), before)
        XCTAssertEqual(element.textMutationVersionToken(), version)
        XCTAssertEqual(element.sourceRangeDirty, dirty)
    }

    func testGeneratedDeferredStatesMatchImmediateInsertionModel() throws {
        let names = ["id", "ID", "class", "CLASS", "data-x", " data-x ", "x", " x\t", "\t", " ", "é", "e\u{301}"]
        let queries = ["id", "ID", "class", "CLASS", "data-x", " data-x ", "x", " x\t", "missing", "é", "e\u{301}"]
        var state: UInt64 = 0x7a91_264e_310b_882f
        func next(_ upper: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 32) % UInt64(upper))
        }
        for fixture in 0..<256 {
            var pending: [Attributes.PendingAttribute] = []
            let model = Attributes()
            let length = fixture % 4 == 0 ? 1 : 4 + next(40)
            for index in 0..<length {
                let name = names[next(names.count)]
                let text = ["", "value\(index)", "日本<&\"", "é", "e\u{301}"][next(5)]
                var attr = item(name, text, bytes: next(2) == 0)
                let rawName = Array(name.utf8)
                let rawValue = Array(text.utf8)
                let kind = next(5)
                if kind == 0 {
                    attr.value = .none
                    if let value = try? BooleanAttribute(key: rawName) { model.put(attribute: value) }
                } else {
                    switch kind {
                    case 1: attr.value = .bytes(rawValue)
                    case 2:
                        let middle = rawValue.count / 2
                        attr.value = .slices([ByteSlice.fromArray(Array(rawValue[..<middle])), ByteSlice.fromArray(Array(rawValue[middle...]))], rawValue.count)
                    default: break
                    }
                    if let value = try? Attribute(key: rawName, value: rawValue) { model.put(attribute: value) }
                }
                pending.append(attr)
            }
            // Each API starts from fresh deferred storage: a missing-key lookup
            // through a different API must not materialize later test cases.
            func fresh() -> Attributes { Attributes(pendingAttributes: pending) }
            for query in queries {
                let raw = Array(query.utf8)
                XCTAssertEqual(fresh().get(key: query), model.get(key: query), "fixture \(fixture) \(query)")
                XCTAssertEqual(try fresh().getIgnoreCase(key: query), try model.getIgnoreCase(key: query), "fixture \(fixture) \(query)")
                XCTAssertEqual(fresh().hasKey(key: query), model.hasKey(key: query))
                XCTAssertEqual(fresh().hasKeyIgnoreCase(key: raw[...]), model.hasKeyIgnoreCase(key: raw[...]))
                XCTAssertEqual(fresh().valueSliceCaseSensitive(raw)?.toArray(), model.valueSliceCaseSensitive(raw)?.toArray())
                XCTAssertEqual(try fresh().getIgnoreCaseSlice(key: raw), try model.getIgnoreCaseSlice(key: raw))
            }
            for syntax in [OutputSettings.Syntax.html, .xml] {
                let settings = OutputSettings().syntax(syntax: syntax)
                let actual = StringBuilder()
                let expected = StringBuilder()
                try fresh().html(accum: actual, out: settings)
                try model.html(accum: expected, out: settings)
                XCTAssertEqual(actual.buffer, expected.buffer, "fixture \(fixture)")
            }
            XCTAssertEqual(fresh().asList().map { $0.getKeyUTF8() }, model.asList().map { $0.getKeyUTF8() })
            XCTAssertEqual(fresh().asList().map { $0.getValueUTF8() }, model.asList().map { $0.getValueUTF8() })
        }
    }

    func testUnambiguousDeferredReadsAndSerializationStayDeferred() throws {
        let attrs = deferred([("id", "new"), ("title", "text")])
        XCTAssertEqual(attrs.get(key: "id"), "new")
        XCTAssertEqual(try attrs.getIgnoreCase(key: "ID"), "new")
        XCTAssertTrue(attrs.hasKey(key: "title"))
        XCTAssertEqual(try attrs.html(), " id=\"new\" title=\"text\"")
        XCTAssertTrue(attrs.attributes.isEmpty, "successful reads must not allocate mutable attributes")
    }

    func testAppendingAfterDeferredReadsCannotReuseStaleValues() throws {
        let attrs = deferred([("ID", "old"), ("id", "lower")])
        XCTAssertEqual(try attrs.getIgnoreCase(key: "id"), "old")
        _ = try attrs.html()
        attrs.appendPending(item("ID", "new"))
        XCTAssertEqual(try attrs.getIgnoreCase(key: "id"), "new")
        XCTAssertEqual(attrs.get(key: "id"), "lower")
        XCTAssertEqual(try attrs.html(), " ID=\"new\" id=\"lower\"")
        _ = attrs.size()
        XCTAssertEqual(try attrs.getIgnoreCase(key: "id"), "new")
    }

    func testReplacingValidatedPendingBatchRevalidatesNames() throws {
        let attrs = deferred([("id", "old")])
        XCTAssertEqual(attrs.get(key: "id"), "old")
        XCTAssertTrue(attrs.attributes.isEmpty)
        attrs.pendingAttributes = [item("id", "first"), item("id", "last")]
        attrs.pendingAttributesCount = 2
        XCTAssertEqual(attrs.get(key: "id"), "last")
        XCTAssertEqual(try attrs.html(), " id=\"last\"")
    }

    func testSmallAndWideValidationAgreeOnAllTrimWhitespace() throws {
        for count in [0, 7, 8, 32] {
            for byte in [9, 10, 11, 12, 13, 32] {
                let space = String(UnicodeScalar(byte)!)
                for bytes in [false, true] {
                    let pairs = (0..<count).map { ("k\($0)", "v") } + [(space + "id" + space, "value"), (space, "drop")]
                    let attrs = deferred(pairs, bytes: bytes)
                    XCTAssertEqual(attrs.get(key: "id"), "value")
                    XCTAssertFalse(attrs.hasKey(key: space))
                    XCTAssertFalse(try attrs.html().contains("drop"))
                    XCTAssertEqual(attrs.size(), count + 1)
                }
            }
        }
    }

    func testWideDeferredDuplicateLookupUsesLastValueImmediately() throws {
        let pairs = (0..<4096).map { ("key-\($0)", "v\($0)") }
        let attrs = deferred(pairs + [("key-0", "last")])
        XCTAssertEqual(attrs.get(key: "key-0"), "last")
        XCTAssertEqual(attrs.size(), 4096)
        XCTAssertEqual(attrs.asList().first?.getKey(), "key-0")
        XCTAssertEqual(attrs.get(key: "key-4095"), "v4095")
    }
}
