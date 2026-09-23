import Foundation
import XCTest
@testable import SwiftSoup

final class TextNodeNBSPPrefilterTest: XCTestCase {
    func testEarlierNonNBSPTwoByteScalarsCannotHideLaterNBSP() throws {
        let doc = Document.createShell("")
        doc.outputSettings().prettyPrint(pretty: false)
        let p = try XCTUnwrap(doc.body()).appendElement("p")
        for prefix in ["¢", "£", "§", "©", "®", "µ", "¿", "©©©", "日本©😀", "©\u{301}"] {
            for tail in ["", "tail", "\u{a0}more", "©\u{a0}"] {
                let text = prefix + "\u{a0}" + tail
                try p.text(text)
                XCTAssertEqual(try p.html(), text.replacingOccurrences(of: "\u{a0}", with: "&nbsp;"))
                XCTAssertEqual(try p.text(trimAndNormaliseWhitespace: false), text)
            }
        }
    }

    func testCompactSerializationAgreesWithEntityEscapePolicy() throws {
        let doc = Document.createShell("")
        let p = try XCTUnwrap(doc.body()).appendElement("p")
        for mode in [Entities.EscapeMode.base, .extended, .xhtml] {
            for encoder in [String.Encoding.utf8, .ascii] {
                doc.outputSettings().prettyPrint(pretty: false).escapeMode(mode).charset(encoder)
                for text in ["©\u{a0}", "©\u{a0}日本😀", "©<>&\u{a0}", "© ordinary", "\u{a0}©"] {
                    try p.text(text)
                    let expected = Entities.escape(text, doc.outputSettings())
                    XCTAssertEqual(try p.html(), expected, "mode=\(mode), text=\(text)")
                    XCTAssertEqual(try p.htmlUTF8WithoutSourceReuse(), Array(expected.utf8))
                }
            }
        }
    }

    func testSourceBackedAndMutatedDocumentOutputRemainConsistent() throws {
        let doc = try SwiftSoup.parse("<p>©\u{a0}x</p>")
        doc.outputSettings().prettyPrint(pretty: false)
        let normalized = String(decoding: try doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self)
        XCTAssertTrue(normalized.contains("©&nbsp;x"))
        let p = try XCTUnwrap(doc.select("p").first())
        try p.text("©\u{a0}updated")
        let output = String(decoding: try doc.outerHtmlUTF8(), as: UTF8.self)
        XCTAssertTrue(output.contains("©&nbsp;updated"))
        XCTAssertEqual(try SwiftSoup.parse(output).select("p").text(trimAndNormaliseWhitespace: false), "©\u{a0}updated")
    }
    func testEveryEntityEscapeStorageOverloadChecksAllNBSPPrefixes() {
        for mode in [Entities.EscapeMode.base, .extended, .xhtml] {
            let out = OutputSettings().escapeMode(mode)
            let replacement = mode == .xhtml ? "&#xa0;" : "&nbsp;"
            for text in ["©\u{a0}", "¢£©\u{a0}tail", "©\u{a0}©\u{a0}", "© ordinary"] {
                let bytes = Array(text.utf8)
                let padded = [UInt8(0x23)] + bytes + [0x24]
                let expected = Array(text.replacingOccurrences(of: "\u{a0}", with: replacement).utf8)
                for normalise in [false, true] {
                    for inAttribute in [false, true] {
                        let arrays = StringBuilder()
                        Entities.escape(arrays, bytes, out, inAttribute, normalise, false)
                        XCTAssertEqual(Array(arrays.buffer), expected)
                        let slices = StringBuilder()
                        Entities.escape(slices, padded[1..<(1 + bytes.count)], out, inAttribute, normalise, false)
                        XCTAssertEqual(Array(slices.buffer), expected)
                        let stored = StringBuilder()
                        let slice = ByteSlice(storage: ByteStorage(data: Data(padded)), start: 1, end: 1 + bytes.count)
                        Entities.escape(stored, slice, out, inAttribute, normalise, false)
                        XCTAssertEqual(Array(stored.buffer), expected)
                    }
                }
                let attribute = try! Attribute(key: "title", value: text)
                let output = StringBuilder()
                attribute.html(accum: output, out: out)
                XCTAssertEqual(output.toString(), "title=\"" + String(decoding: expected, as: UTF8.self) + "\"")
            }
        }
    }

}
