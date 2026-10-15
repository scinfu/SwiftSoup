import XCTest
@testable import SwiftSoup

final class XmlParseSettingsTest: XCTestCase {
    private final class PrefixedTagSettings: ParseSettings, @unchecked Sendable {
        override func normalizeTag(_ name: [UInt8]) -> [UInt8] {
            return Array("prefix-".utf8) + super.normalizeTag(name)
        }
    }

    func testDeclarationNameIsNormalizedOnlyOnce() throws {
        for tracked in [false, true] {
            let parser = Parser.xmlParser().settings(PrefixedTagSettings(true, true, tracked))
            let doc = try parser.parseInput("<?Target?><Target />", "")
            let declaration = try XCTUnwrap(doc.childNode(0) as? XmlDeclaration)
            XCTAssertEqual(declaration.name(), "prefix-Target")
            XCTAssertEqual(declaration.name(), doc.children().first()?.tagName())
        }
    }

    func testDeclarationNamesAndAttributesFollowIndependentCaseSettings() throws {
        for tracked in [false, true] {
            for preserveTag in [false, true] {
                for preserveAttribute in [false, true] {
                    let parser = Parser.xmlParser().settings(ParseSettings(preserveTag, preserveAttribute, tracked))
                    let doc = try parser.parseInput("<?Target MixedCase='&#128;&amp;'?><Root />", "")
                    let declaration = try XCTUnwrap(doc.childNode(0) as? XmlDeclaration)
                    XCTAssertEqual(declaration.name(), preserveTag ? "Target" : "target")
                    let key = preserveAttribute ? "MixedCase" : "mixedcase"
                    XCTAssertEqual(declaration.getAttributes()?.asList().map { $0.getKey() }, [key])
                    XCTAssertEqual(try declaration.attr(key), "\u{80}&")
                }
            }
        }
    }

    func testDeclarationsRespectDisabledAttributeTracking() throws {
        for tracked in [false, true] {
            let parser = Parser.xmlParser().settings(ParseSettings(true, true, tracked, false))
            let doc = try parser.parseInput("<?Target MixedCase='value'?><Root MixedCase='value' />", "")
            let declaration = try XCTUnwrap(doc.childNode(0) as? XmlDeclaration)
            XCTAssertEqual(declaration.name(), "Target")
            XCTAssertEqual(declaration.getAttributes()?.size() ?? 0, 0)
            XCTAssertEqual(doc.children().first()?.getAttributes()?.size() ?? 0, 0)
            doc.outputSettings().prettyPrint(pretty: false)
            XCTAssertEqual(String(decoding: try doc.outerHtmlUTF8WithoutSourceReuse(), as: UTF8.self),
                           "<?Target?><Root />")
        }
    }

    func testDeclarationSettingsApplyToBorrowedInputAndFragments() throws {
        let bytes = Array("<?Target MixedCase='value'?><Root />".utf8)
        for tracked in [false, true] {
            for attributes in [false, true] {
                let settings = ParseSettings(false, false, tracked, attributes)
                try bytes.withUnsafeBufferPointer { buffer in
                    let doc = try XmlTreeBuilder().parse(buffer, owner: nil, [], .noTracking(), settings)
                    let fragments = try XmlTreeBuilder().parseFragment(bytes, [], .noTracking(), settings)
                    for node in [doc.childNode(0), fragments[0]] {
                        let declaration = try XCTUnwrap(node as? XmlDeclaration)
                        XCTAssertEqual(declaration.name(), "target")
                        XCTAssertEqual(declaration.getAttributes()?.asList().map { $0.getKey() },
                                       attributes ? ["mixedcase"] : [])
                    }
                }
            }
        }
    }
}
