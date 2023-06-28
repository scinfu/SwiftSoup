import XCTest
@testable import SwiftSoup

class NodeTraversorTest: XCTestCase {
    func testTraverseOrder() {
        class TestVisitor: NodeVisitor {
            var heads: [Node] = []
            var tails: [Node] = []

            func head(_ node: Node, _ depth: Int) throws {
                heads.append(node)
            }

            func tail(_ node: Node, _ depth: Int) throws {
                tails.append(node)
            }
        }

        let html = "<p id=1><b id=2>3</b>4</p><p id=5>6</p>"
        let doc = try! SwiftSoup.parse(html)

        let tv = TestVisitor()
        try! doc.body()!.traverse(tv)

        assertNodeDescsMatch(
            [.e(""), .e("1"), .e("2"), .t("3"), .t("4"), .e("5"), .t("6")],
            tv.heads,
            "head() order"
        )
        assertNodeDescsMatch(
            [.t("3"), .e("2"), .t("4"), .e("1"), .t("6"), .e("5"), .e("")],
            tv.tails,
            "tail() order"
        )
    }

    private func assertNodeDescsMatch(_ descs: [NodeDesc], _ nodes: [Node], _ label: String) {
        XCTAssertEqual(nodes.count, descs.count, "\(label): nodes.count == descs.count")
        for i in 0..<nodes.count {
            let node = nodes[i]
            switch descs[i] {
            case .element(let id):
                XCTAssert(node is Element, "\(label): nodes[i] is Element")
                let elt = node as! Element
                XCTAssertEqual(id, elt.id(), "\(label): nodes[i].id()")
            case .text(let text):
                XCTAssert(node is TextNode, "\(label): nodes[i] is TextNode")
                let tnode = node as! TextNode
                XCTAssertEqual(text, tnode.text(), "\(label): nodes[i].text()")
            }
        }
    }
}

private enum NodeDesc {
    case element(_ id: String)
    case text(_ text: String)

    static let e = NodeDesc.element
    static let t = NodeDesc.text
}
