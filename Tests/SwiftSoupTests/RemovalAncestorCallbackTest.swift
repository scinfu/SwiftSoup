import XCTest
@testable import SwiftSoup

final class RemovalAncestorCallbackTest: XCTestCase {
    private final class CustomAncestor: Element {
        var onOwnerDocument: (() -> Void)?

        override func ownerDocument() -> Document? {
            onOwnerDocument?()
            return super.ownerDocument()
        }
    }

    func testOwnerDocumentCallbackCanMoveALaterSelectedSibling() throws {
        for directParent in [false, true] {
            let document = try SwiftSoup.parse("<main></main><aside></aside>")
            let main = try XCTUnwrap(document.select("main").first())
            let destination = try XCTUnwrap(document.select("aside").first())
            let custom = CustomAncestor(try Tag.valueOf("section"), "")
            try main.appendChild(custom)
            let parent: Element
            if directParent {
                parent = custom
            } else {
                parent = Element(try Tag.valueOf("div"), "")
                try custom.appendChild(parent)
            }
            let first = Element(try Tag.valueOf("a"), "")
            let last = Element(try Tag.valueOf("b"), "")
            try parent.appendChild(first).appendChild(last)
            var callbackFired = false
            custom.onOwnerDocument = { [weak custom] in
                custom?.onOwnerDocument = nil
                callbackFired = true
                do { try destination.appendChild(last) }
                catch { XCTFail("\(error)") }
            }
            defer { custom.onOwnerDocument = nil }
            try Elements([first, last]).remove()
            XCTAssertTrue(callbackFired, "directParent=\(directParent)")
            XCTAssertNil(first.parent())
            XCTAssertNil(last.parent(), "directParent=\(directParent)")
            XCTAssertTrue(destination.getChildNodes().isEmpty, "directParent=\(directParent)")
            XCTAssertTrue(parent.getChildNodes().isEmpty)
        }
    }

    func testCustomAncestorFallbackPrecedesEveryParentGroupMutation() throws {
        let document = try SwiftSoup.parse("<main><div><a></a><b></b></div></main>")
        let main = try XCTUnwrap(document.select("main").first())
        let ordinary = try XCTUnwrap(document.select("div").first())
        let first = try XCTUnwrap(document.select("a").first())
        let last = try XCTUnwrap(document.select("b").first())
        let custom = CustomAncestor(try Tag.valueOf("section"), "")
        let customFirst = Element(try Tag.valueOf("i"), "")
        let customLast = Element(try Tag.valueOf("u"), "")
        try main.appendChild(custom)
        try custom.appendChild(customFirst).appendChild(customLast)
        var callbackFired = false
        custom.onOwnerDocument = { [weak custom] in
            custom?.onOwnerDocument = nil
            callbackFired = true
            XCTAssertNil(first.parent())
            XCTAssertTrue(last.parent() === ordinary)
            XCTAssertNil(customFirst.parent())
            XCTAssertTrue(customLast.parent() === custom)
        }
        defer { custom.onOwnerDocument = nil }
        try Elements([first, customFirst, last, customLast]).remove()
        XCTAssertTrue(callbackFired)
        XCTAssertTrue(ordinary.getChildNodes().isEmpty)
        XCTAssertTrue(custom.getChildNodes().isEmpty)
    }
}
