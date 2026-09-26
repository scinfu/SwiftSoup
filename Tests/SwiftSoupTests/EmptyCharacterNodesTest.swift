import XCTest
@testable import SwiftSoup

final class EmptyCharacterNodesTest: XCTestCase {
    func testClearingTextRestoresEmptySelectorAcrossCacheAndTrackingModes() throws {
        for trackSource in [false, true] {
            let doc = try Parser.htmlParser().settings(ParseSettings(false, false, trackSource))
                .parseInput("<p id='target'>original</p>", "")
            let target = try XCTUnwrap(doc.getElementById("target"))
            for value in ["payload", "", " ", "\t", "\n", "\u{00A0}", ""] {
                try target.text(value)
                for _ in 0..<3 {
                    XCTAssertEqual(try doc.select("p:empty").size(), value.isEmpty ? 1 : 0, value.debugDescription)
                    XCTAssertEqual(try Evaluator.IsEmpty().matches(doc, target), value.isEmpty)
                }
            }
        }
    }

    func testEmptyDataNodesAndCommentsDoNotPreventEmptyMatching() throws {
        let doc = try SwiftSoup.parse("<script id='target'></script>")
        let target = try XCTUnwrap(doc.getElementById("target"))
        let data = DataNode([], [])
        try target.appendChild(data)
        try target.appendChild(Comment(Array("comment".utf8), []))
        try target.appendChild(TextNode("", ""))
        for value in ["", "x", " ", ""] {
            data.setWholeData(value)
            XCTAssertEqual(try doc.select("script:empty").size(), value.isEmpty ? 1 : 0)
        }
        try target.appendElement("child")
        XCTAssertEqual(try doc.select("script:empty").size(), 0)
    }

    func testEmptyMatchingHonorsCharacterNodeGetterOverrides() throws {
        final class ReportedText: TextNode {
            override func getWholeTextUTF8() -> [UInt8] { [] }
        }
        final class ReportedData: DataNode {
            override func getWholeDataUTF8() -> [UInt8] { [] }
        }
        let target = try Element(Tag.valueOf("div"), "")
        try target.appendChild(ReportedText("stored", ""))
        try target.appendChild(ReportedData(Array("stored".utf8), []))
        XCTAssertTrue(try Evaluator.IsEmpty().matches(target, target))
    }
}
