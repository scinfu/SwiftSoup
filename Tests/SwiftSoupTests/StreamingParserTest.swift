import XCTest
import SwiftSoup

final class StreamingParserTest: XCTestCase {
    private final class Collector: HtmlTokenReceiver {
        var events: [String] = []

        func startTag(name: ArraySlice<UInt8>, attributes: Attributes?, selfClosing: Bool) {
            events.append("start:\(String(decoding: name, as: UTF8.self))")
        }

        func endTag(name: ArraySlice<UInt8>) {
            events.append("end:\(String(decoding: name, as: UTF8.self))")
        }

        func text(_ data: ArraySlice<UInt8>) {
            events.append("text:\(String(decoding: data, as: UTF8.self))")
        }

        func comment(_ data: ArraySlice<UInt8>) {
            events.append("comment:\(String(decoding: data, as: UTF8.self))")
        }

        func doctype(name: ArraySlice<UInt8>?, publicId: ArraySlice<UInt8>?, systemId: ArraySlice<UInt8>?, forceQuirks: Bool) {
            if let name {
                events.append("doctype:\(String(decoding: name, as: UTF8.self))")
            } else {
                events.append("doctype:")
            }
        }

        func eof() {
            events.append("eof")
        }
    }

    func testStreamingParserEmitsTokens() throws {
        let html = "<!doctype html><p>One <b>Two</b><!--c--></p>"
        let collector = Collector()
        let parser = StreamingHtmlParser()
        try parser.parse(html.utf8Array, collector)

        XCTAssertEqual([
            "doctype:html",
            "start:p",
            "text:One ",
            "start:b",
            "text:Two",
            "end:b",
            "comment:c",
            "end:p",
            "eof"
        ], collector.events)
    }
}
