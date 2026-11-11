import XCTest
import SwiftSoup

final class RemovalOrderCompatibilityTest: XCTestCase {
    func testBatchPreservesTokenAfterDetachingAPreviouslyStandaloneParent() throws {
        let original = try SwiftSoup.parse("<p><i>one</i><b>two</b></p>")
        let originalParent = try XCTUnwrap(original.select("p").first())
        for reversed in [false, true] {
            for duplicate in [false, true] {
                for batched in [false, true] {
                    let parent = try XCTUnwrap(originalParent.copy() as? Element)
                    let root = Element(try Tag.valueOf("main"), "")
                    try root.appendChild(parent)
                    try withExtendedLifetime(root) {
                        var children = parent.children().array()
                        if reversed { children.reverse() }
                        let previousToken = parent.textMutationVersionToken()
                        XCTAssertFalse(try parent.text().isEmpty)
                        let selection = [parent, children[0]] + (duplicate ? [children[0]] : []) + [children[1]]
                        if batched {
                            try Elements(selection).remove()
                        } else {
                            for node in selection { try node.remove() }
                        }
                        XCTAssertNil(parent.parent())
                        XCTAssertEqual(try parent.text(), "")
                        XCTAssertNotEqual(parent.textMutationVersionToken(), previousToken,
                                          "reversed=\(reversed), duplicate=\(duplicate), batched=\(batched)")
                    }
                }
            }
        }
    }

    func testInterleavedAncestorRemovalInvalidatesRetainedSubtreeTextToken() throws {
        let original = try SwiftSoup.parse("<main><p id=p><i id=a>one</i><b id=b>two</b><em id=c>three</em><u id=d>four</u></p></main>")
        for reversed in [false, true] {
            for split in 1...3 {
                for batched in [false, true] {
                    let document = try XCTUnwrap(original.copy() as? Document)
                    try withExtendedLifetime(document) {
                        let parent = try XCTUnwrap(document.getElementById("p"))
                        var children = try ["a", "b", "c", "d"].map {
                            try XCTUnwrap(document.getElementById($0))
                        }
                        if reversed { children.reverse() }
                        let previousToken = parent.textMutationVersionToken()
                        XCTAssertFalse(try parent.text().isEmpty)
                        let selection = Array(children[..<split]) + [parent] + Array(children[split...])
                        if batched {
                            try Elements(selection).remove()
                        } else {
                            for node in selection { try node.remove() }
                        }
                        XCTAssertNil(parent.parent())
                        XCTAssertTrue(children.allSatisfy { $0.parent() == nil })
                        XCTAssertEqual(try parent.text(), "")
                        XCTAssertNotEqual(parent.textMutationVersionToken(), previousToken,
                                          "reversed=\(reversed), split=\(split), batched=\(batched)")
                    }
                }
            }
        }
    }
}
