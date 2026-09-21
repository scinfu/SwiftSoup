import Foundation
import XCTest
@testable import SwiftSoup

final class WhitespaceRunTest: XCTestCase {
    private struct Observation: Equatable {
        var bytes: [UInt8]
        var last: Bool
        var saw: Bool
        var callbacks: [[UInt8]]
    }

    private final class ObservingBuilder: StringBuilder {
        var callbacks: [[UInt8]] = []
        override func append(_ value: UInt8) -> StringBuilder {
            callbacks.append(Array(buffer) + [value])
            return super.append(value)
        }
    }

    // Model only the historical slow path, forced by the leading tab in these
    // inputs. Deliberately retains permissive byte stepping and drops a truncated
    // final sequence; this performance patch must not change malformed input.
    private func reference(_ input: [UInt8], strip: Bool, last: Bool, saw: Bool) -> Observation {
        var result = Observation(bytes: [90], last: last, saw: saw, callbacks: [])
        var reached = false
        var i = 0
        while i < input.count {
            let b = input[i]
            let nbsp = b == 194 && i + 1 < input.count && input[i + 1] == 160
            let whitespace = [UInt8(9), 10, 12, 13, 32].contains(b) || nbsp
            if whitespace {
                if !(strip && !reached) && !result.last {
                    result.callbacks.append(result.bytes + [32])
                    result.bytes.append(32)
                    result.last = true
                    result.saw = true
                }
                i += nbsp ? 2 : 1
            } else {
                let width = b < 128 ? 1 : b < 224 ? 2 : b < 240 ? 3 : 4
                guard width <= input.count - i else { break }
                result.bytes.append(contentsOf: input[i..<(i + width)])
                result.last = false
                reached = true
                i += width
            }
        }
        return result
    }

    private func observe(_ slice: ByteSlice, strip: Bool, last: Bool, saw: Bool) -> Observation {
        let builder = ObservingBuilder(string: "Z")
        var last = last
        var saw = saw
        StringUtil.appendNormalisedWhitespace(builder, string: slice, stripLeading: strip,
                                              lastWasWhite: &last, sawWhitespace: &saw)
        return Observation(bytes: Array(builder.buffer), last: last, saw: saw, callbacks: builder.callbacks)
    }

    private func check(_ input: [UInt8], allStorage: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(input.first, 9, "Force the slow path", file: file, line: line)
        let padded = [UInt8(77), 78, 79] + input + [80, 81]
        let array = ByteSlice(storage: ByteStorage(array: padded), start: 3, end: 3 + input.count)
        var data = Data(padded)
        data.removeFirst(2) // Retain a nonzero Data.startIndex.
        XCTAssertEqual(data.startIndex, 2)
        let dataSlice = ByteSlice(storage: ByteStorage(data: data), start: 1, end: 1 + input.count)
        for strip in [false, true] {
            for last in [false, true] {
                for saw in [false, true] {
                    let expected = reference(input, strip: strip, last: last, saw: saw)
                    XCTAssertEqual(observe(array, strip: strip, last: last, saw: saw), expected, file: file, line: line)
                    if allStorage {
                        XCTAssertEqual(observe(dataSlice, strip: strip, last: last, saw: saw), expected, file: file, line: line)
                        padded.withUnsafeBufferPointer { buffer in
                            let storage = ByteStorage(buffer: buffer.baseAddress!, count: buffer.count, owner: nil)
                            let slice = ByteSlice(storage: storage, start: 3, end: 3 + input.count)
                            XCTAssertEqual(observe(slice, strip: strip, last: last, saw: saw), expected, file: file, line: line)
                        }
                    }
                }
            }
        }
    }

    func testUnicodeWhitespaceAndCallbackOrderAcrossStorage() {
        for text in ["", "日本語", "日本語日本語\t文章です\n終わり", "😀🧑🏽‍💻🇯🇵e\u{301}",
                     "日本\u{a0}語\u{a0}\u{a0}\r\n次", "\u{3000}\u{2003}\u{200b}\u{b}甲乙", "a日b本c語d"] {
            check([9] + Array(text.utf8), allStorage: true)
        }
    }

    func testEveryLeadByteAndTruncationBoundary() {
        for lead in UInt8.min...UInt8.max {
            for width in 0...4 {
                check([9] + Array("日本語".utf8) + Array(([lead] + [128, 160, 32]).prefix(width)), allStorage: true)
            }
        }
    }

    func testSeededMalformedByteCorpus() {
        var state: UInt64 = 0x5748495445535043
        for index in 0..<2048 {
            var input: [UInt8] = [9]
            for _ in 0..<(index % 129) {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                input.append(UInt8(truncatingIfNeeded: state >> 32))
            }
            check(input, allStorage: index.isMultiple(of: 16))
        }
    }

    func testTrackingOverloadsAndFastPathState() {
        let chunks = ["\t日本語\u{a0}", "\t\n続きです", "\t😀e\u{301}\r終", "\t ", ""]
        for strip in [false, true] {
            for initial in [false, true] {
                let expected = StringBuilder()
                let actual = StringBuilder()
                var expectedLast = initial
                var actualLast = initial
                for text in chunks {
                    let bytes = Array(text.utf8)
                    StringUtil.appendNormalisedWhitespace(expected, string: bytes[...], stripLeading: strip, lastWasWhite: &expectedLast)
                    StringUtil.appendNormalisedWhitespace(actual, string: ByteSlice.fromArray(bytes), stripLeading: strip, lastWasWhite: &actualLast)
                    XCTAssertEqual(Array(actual.buffer), Array(expected.buffer))
                    XCTAssertEqual(actualLast, expectedLast)
                }
            }
        }
        // Non-whitespace output clears a previous whitespace flag, including on the fast path.
        let plain = observe(ByteSlice.fromArray(Array("日本語".utf8)), strip: false, last: true, saw: false)
        XCTAssertEqual(plain.last, false)
        XCTAssertEqual(plain.saw, false)
        XCTAssertEqual(plain.bytes, Array("Z日本語".utf8))
        let empty = observe(.empty, strip: true, last: true, saw: true)
        XCTAssertEqual(empty, Observation(bytes: [90], last: true, saw: true, callbacks: []))
    }

    func testAliasedBuilderStorageAndRetainedSnapshots() {
        let text = "\t日本語日本語\n続き😀\u{a0}終"
        let builder = StringBuilder(string: text)
        let snapshot = builder.asByteSlice()
        let expected = reference(Array(text.utf8), strip: true, last: false, saw: false)
        builder.clear()
        builder.append("Z")
        var last = false
        var saw = false
        StringUtil.appendNormalisedWhitespace(builder, string: snapshot, stripLeading: true, lastWasWhite: &last, sawWhitespace: &saw)
        XCTAssertEqual(Array(builder.buffer), expected.bytes)
        XCTAssertEqual(snapshot.toArray(), Array(text.utf8))
        let retained = builder.buffer
        builder.clear()
        builder.append(String(repeating: "変更", count: 1024))
        XCTAssertEqual(Array(retained), expected.bytes)
        XCTAssertEqual(snapshot.toArray(), Array(text.utf8))
    }

    func testPublicTextAPIsMutationAndPreservedWhitespace() throws {
        let doc = try SwiftSoup.parse("<main><p>\t日本語日本語\n次の文</p><p>😀\u{a0}終わり</p><pre>甲\t乙\n丙</pre></main>")
        let p = try XCTUnwrap(doc.select("p").first())
        for _ in 0..<3 {
            XCTAssertEqual(try p.text(), "日本語日本語 次の文")
            XCTAssertEqual(try p.textUTF8(), Array("日本語日本語 次の文".utf8))
            XCTAssertEqual(p.ownText(), "日本語日本語 次の文")
            XCTAssertEqual(try p.text(trimAndNormaliseWhitespace: false), "\t日本語日本語\n次の文")
        }
        try p.text("\t変更しました\u{a0}\n新しい文")
        XCTAssertEqual(try p.text(), "変更しました 新しい文")
        let pre = try XCTUnwrap(doc.select("pre").first())
        XCTAssertEqual(try pre.text(), "甲\t乙\n丙")
        XCTAssertEqual(try doc.text(), "変更しました 新しい文 😀 終わり 甲\t乙\n丙")
    }
}
