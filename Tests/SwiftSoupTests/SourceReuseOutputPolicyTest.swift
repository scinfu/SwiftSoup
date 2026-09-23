import Foundation
import XCTest
@testable import SwiftSoup

final class SourceReuseOutputPolicyTest: XCTestCase {
    func testCharsetAndEscapeModesApplyToCleanNodesAndSparseEdits() throws {
        let source = "<html><head><title title='日本'>日本 © &nbsp;</title></head><body><p title='日本'>日本 © &nbsp;</p><b>Before</b></body></html>"
        for charset in [String.Encoding.ascii, .utf8] {
            for mode in [Entities.EscapeMode.base, .extended, .xhtml] {
                if charset == .utf8 && mode == .base { continue }
                let doc = try SwiftSoup.parse(source)
                doc.outputSettings().prettyPrint(pretty: false).charset(charset).escapeMode(mode)
                for mutate in [false, true] {
                    if mutate { try doc.select("b").first()?.text("変更") }
                    let expected = try doc.outerHtmlUTF8WithoutSourceReuse()
                    XCTAssertEqual(try doc.outerHtmlUTF8(), expected)
                    XCTAssertEqual(try doc.outerHtml(), String(decoding: expected, as: UTF8.self))
                    XCTAssertEqual(try doc.outerHtmlUTF8ReusingSourceOutsideBody(), expected)
                    for selector in ["title", "p"] {
                        let node = try XCTUnwrap(doc.select(selector).first())
                        XCTAssertEqual(try node.outerHtmlUTF8Internal(),
                                       try node.outerHtmlUTF8Internal(doc.outputSettings(), allowRawSource: false))
                    }
                    if charset == .ascii { XCTAssertTrue(expected.allSatisfy { $0 < 128 }) }
                }
            }
        }
    }

    func testSyntaxChangesApplyInBothDirectionsAndAfterSparseEdits() throws {
        for xml in [false, true] {
            let source = xml
                ? "<html><head/><body><br/><input disabled=\"disabled\"/><p>Before</p></body></html>"
                : "<html><head></head><body><br><input disabled><p>Before</p></body></html>"
            let doc = try (xml ? Parser.xmlParser() : Parser.htmlParser()).parseInput(source, "")
            doc.outputSettings().prettyPrint(pretty: false).syntax(syntax: xml ? .html : .xml)
            for mutate in [false, true] {
                if mutate { try doc.select("p").first()?.text("After") }
                let expected = try doc.outerHtmlUTF8WithoutSourceReuse()
                XCTAssertEqual(try doc.outerHtmlUTF8(), expected)
                XCTAssertEqual(try doc.outerHtmlUTF8ReusingSourceOutsideBody(), expected)
                let node = try XCTUnwrap(doc.select("br").first())
                XCTAssertEqual(try node.outerHtmlUTF8Internal(),
                               try node.outerHtmlUTF8Internal(doc.outputSettings(), allowRawSource: false))
            }
        }
    }

    func testAdoptedNodesUseTheirOriginalParsingSyntax() throws {
        for xmlDonor in [false, true] {
            let donor = try (xmlDonor ? Parser.xmlParser() : Parser.htmlParser())
                .parseInput("<box><input disabled=\"disabled\"/></box>", "")
            let target = try (xmlDonor ? Parser.htmlParser() : Parser.xmlParser())
                .parseInput("<root></root>", "")
            target.outputSettings().prettyPrint(pretty: false)
            let box = try XCTUnwrap(donor.select("box").first())
            let root = try XCTUnwrap(target.select("root").first())
            try root.appendChild(box)
            XCTAssertEqual(try box.outerHtmlUTF8Internal(),
                           try box.outerHtmlUTF8Internal(target.outputSettings(), allowRawSource: false))
        }
    }

    func testRestoringDefaultPolicyRestoresExactSourceReuse() throws {
        let source = "<html><head></head><body><p title='source'>&copy; 日本</p></body></html>"
        let doc = try SwiftSoup.parse(source)
        doc.outputSettings().prettyPrint(pretty: false)
        XCTAssertEqual(try doc.outerHtmlUTF8(), Array(source.utf8))
        doc.outputSettings().charset(.ascii).escapeMode(.xhtml)
        XCTAssertEqual(try doc.outerHtmlUTF8(), try doc.outerHtmlUTF8WithoutSourceReuse())
        doc.outputSettings().charset(.utf8).escapeMode(.base)
        XCTAssertEqual(try doc.outerHtmlUTF8(), Array(source.utf8))
    }
}
