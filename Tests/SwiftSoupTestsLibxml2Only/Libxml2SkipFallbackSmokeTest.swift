import XCTest
@testable import SwiftSoup

final class Libxml2SkipFallbackSmokeTest: SwiftSoupTestCase {
    override class var allowLibxml2Only: Bool { true }

#if canImport(CLibxml2) || canImport(libxml2)
    func testBasicHtmlParse() throws {
        let doc = try SwiftSoup.parse("<div id=one><p>Hello</p></div>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        if ProcessInfo.processInfo.environment["SWIFTSOUP_DEBUG_LIBXML2_ONLY"] == "1" {
            let body = doc.body()
            let bodyPtr = body?.libxml2NodePtr
            let docPtr = doc.libxml2DocPtr
            let childPtr = bodyPtr?.pointee.children
            print("libxml2Only debug: docPtr=\(docPtr != nil) bodyPtr=\(bodyPtr != nil) childPtr=\(childPtr != nil)")
            if let docPtr, let bodyPtr {
                let pretty = Libxml2Serialization.htmlDumpChildrenFormat(node: bodyPtr, doc: docPtr, prettyPrint: true) ?? []
                let compact = Libxml2Serialization.htmlDumpChildren(node: bodyPtr, doc: docPtr) ?? []
                let outer = Libxml2Serialization.htmlDumpFormat(node: bodyPtr, doc: docPtr, prettyPrint: true) ?? []
                print("libxml2Only debug: children pretty='\(String(decoding: pretty, as: UTF8.self))'")
                print("libxml2Only debug: children compact='\(String(decoding: compact, as: UTF8.self))'")
                print("libxml2Only debug: outer pretty='\(String(decoding: outer, as: UTF8.self))'")
            }
            let bodyHtml = (try body?.html()) ?? ""
            print("libxml2Only debug: body.html()='\(bodyHtml)'")
        }
        let divs = try doc.getElementsByTag("div")
        XCTAssertEqual(1, divs.size())
        XCTAssertEqual("one", divs.first()?.id())
        XCTAssertEqual("Hello", try divs.first()?.text())
    }

    func testMutationRoundTrip() throws {
        let doc = try SwiftSoup.parse("<div><p>Hello</p></div>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        let div = try doc.getElementsByTag("div").first()
        XCTAssertNotNil(div)
        try div?.attr("data-test", "1")
        try div?.append("<span>World</span>")
        let spans = try doc.getElementsByTag("span")
        XCTAssertEqual(1, spans.size())
        XCTAssertEqual("World", try spans.first()?.text())
        XCTAssertEqual("1", try div?.attr("data-test"))
    }

    func testBackendFlagsSet() throws {
        let doc = try SwiftSoup.parse("<div></div>", backend: .libxml2(swiftSoupParityMode: .libxml2Only))
        XCTAssertTrue(doc.isLibxml2Backend)
        XCTAssertTrue(doc.libxml2Only)
    }
#endif
}
