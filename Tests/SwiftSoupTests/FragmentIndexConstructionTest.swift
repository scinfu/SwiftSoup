import XCTest
@testable import SwiftSoup

final class FragmentIndexConstructionTest: XCTestCase {
    func testManualInsertionAfterFragmentReturnCrossesAnImpliedTbody() throws {
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(Array("<table><tr><td><p>BEFORE</p></td></tr></table>".utf8),
                                      context, [], .noTracking(), .htmlDefault)
        let document = builder.doc
        document.outputSettings().prettyPrint(pretty: false)
        let table = try XCTUnwrap(document.getElementsByTag("table").first())
        let cell = try XCTUnwrap(document.getElementsByTag("td").first())
        XCTAssertFalse(table.sourceRangeDirty)
        XCTAssertTrue(try document.getElementsByTag("tbody").get(0).sourceRangeDirty)
        builder.stack = [cell]
        builder.transition(.InBody)
        try builder.processStartTag("p")
        try builder.process(Token.Char().data(Array("AFTER".utf8)))
        try builder.processEndTag("p")
        XCTAssertTrue(table.sourceRangeDirty)
        let expected = "<table><tbody><tr><td><p>BEFORE</p><p>AFTER</p></td></tr></tbody></table>"
        XCTAssertEqual(try table.outerHtml(), expected)
        XCTAssertEqual(try table.outerHtmlUTF8Internal(), Array(expected.utf8))
    }

    func testPrivateConstructionKeepsEveryQueryIndexDirtyUntilFirstQuery() throws {
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(Array("<p id='one' class='x'>一<b>二</b></p><form><input name='n'></form>".utf8),
                                      context, [], .noTracking(), .htmlDefault)
        var stack: [Node] = [builder.doc]
        while let node = stack.popLast() {
            if let element = node as? Element {
                XCTAssertTrue(element.isTagQueryIndexDirty)
                XCTAssertTrue(element.isClassQueryIndexDirty)
                XCTAssertTrue(element.isIdQueryIndexDirty)
                XCTAssertTrue(element.isAttributeQueryIndexDirty)
                XCTAssertTrue(element.isAttributeValueQueryIndexDirty)
                XCTAssertNil(element.selectorResultCache)
                XCTAssertFalse(element.suppressQueryIndexDirty)
            }
            for (index, child) in node.getChildNodes().enumerated() {
                XCTAssertTrue(child.parent() === node)
                XCTAssertEqual(child.siblingIndex, index)
                stack.append(child)
            }
        }
        XCTAssertEqual(try builder.doc.select("p.x#one").size(), 1)
        XCTAssertEqual(try builder.doc.select("input[name=n]").size(), 1)
    }

    func testManualProcessingAfterFragmentReturnInvalidatesWarmedIndexes() throws {
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(Array("<p>before</p>".utf8), context, [], .noTracking(), .htmlDefault)
        let document = builder.doc
        let root = try XCTUnwrap(document.children().first())
        for _ in 0..<4 {
            XCTAssertEqual(try document.select("span.new").size(), 0)
            XCTAssertEqual(try root.select("span").size(), 0)
        }
        builder.stack = [root]
        builder.transition(.InBody)
        let attributes = Attributes()
        try attributes.put("class", "new")
        try builder.processStartTag("span", attributes)
        XCTAssertEqual(try document.select("span.new").size(), 1)
        XCTAssertEqual(try root.select("span").size(), 1)
        let span = try XCTUnwrap(root.getElementsByTag("span").first())
        XCTAssertTrue(span.parent() === root)
        XCTAssertTrue(span.ownerDocument() === document)
    }

    func testFragmentConstructionDoesNotModifyWarmedContextDocument() throws {
        let document = try SwiftSoup.parse("<form id='f'><div id='context'><p class='before'>original</p></div></form>")
        let context = try XCTUnwrap(document.getElementById("context"))
        for _ in 0..<4 { _ = try document.select(".before"); _ = try context.select("p") }
        let before = try document.outerHtmlUTF8WithoutSourceReuse()
        let version = document.textMutationVersionToken()
        let nodes = try Parser.parseFragment("<p class='after'>new</p><input name='n'>", context, [])
        XCTAssertEqual(try document.outerHtmlUTF8WithoutSourceReuse(), before)
        XCTAssertEqual(document.textMutationVersionToken(), version)
        XCTAssertEqual(try document.select(".before").size(), 1)
        XCTAssertEqual(try document.select(".after").size(), 0)
        try context.insertChildren(0, nodes)
        XCTAssertEqual(try document.select(".after").size(), 1)
        XCTAssertEqual(try context.select("p").size(), 2)
    }

    func testNestedFormattingFosterParentingAndRepeatedBuilderUse() throws {
        for markup in ["<b><i>一</b>二</i>", "<table>text<tr><td>一</td></tr></table>",
                       "<ruby><rb>漢</rb><rt>かん</rt></ruby>", "<select><option>一<option>二</select>"] {
            let builder = HtmlTreeBuilder()
            for _ in 0..<3 {
                let context = try Element(Tag.valueOf("div"), "")
                let nodes = try builder.parseFragment(Array(markup.utf8), context, [], .noTracking(), .htmlDefault)
                let destination = try SwiftSoup.parse("<main></main>")
                let root = try XCTUnwrap(destination.getElementsByTag("main").first())
                try root.insertChildren(0, nodes)
                let copy = destination.copy() as! Document
                XCTAssertEqual(try destination.outerHtmlUTF8WithoutSourceReuse(), try copy.outerHtmlUTF8WithoutSourceReuse())
                var stack: [Node] = [destination]
                while let node = stack.popLast() {
                    XCTAssertTrue(node.ownerDocument() === destination)
                    for (index, child) in node.getChildNodes().enumerated() {
                        XCTAssertTrue(child.parent() === node)
                        XCTAssertEqual(child.siblingIndex, index)
                        stack.append(child)
                    }
                }
                try root.append("<p class='added'>追加</p>")
                XCTAssertEqual(try destination.select("p.added").size(), 1)
            }
        }
    }
    func testManualProcessingAfterFragmentReturnKeepsForeignOwnerDispatch() throws {
        final class RedirectedElement: Element {
            var redirectedOwner: Document?
            var ownerLookups = 0
            override func ownerDocument() -> Document? {
                ownerLookups += 1
                return redirectedOwner
            }
        }
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(Array("<p>initial</p>".utf8), context, [], .noTracking(), .htmlDefault)
        let privateDocument = builder.doc
        let foreign = try SwiftSoup.parse("<main></main>")
        let node = try RedirectedElement(Tag.valueOf("p"), "")
        node.redirectedOwner = foreign
        let parent = try XCTUnwrap(foreign.body())
        try parent.appendChild(node)
        builder.stack = [parent, node]
        builder.transition(.InBody)
        privateDocument.sourceRangeDirty = true
        privateDocument.dirtySourceRoots = [ObjectIdentifier(privateDocument): Weak(privateDocument)]
        foreign.dirtySourceRoots.removeAll()
        node.sourceRangeDirty = false
        node.ownerLookups = 0
        // Fragment mode survives parseFragment(), but its private construction scope must not.
        try builder.processEndTag("p")
        XCTAssertTrue(node.sourceRangeDirty)
        XCTAssertGreaterThan(node.ownerLookups, 0)
        XCTAssertTrue(foreign.dirtySourceRoots[ObjectIdentifier(node)]?.value === node)
        XCTAssertTrue(privateDocument.dirtySourceRoots[ObjectIdentifier(privateDocument)]?.value === privateDocument)
    }

    func testManualInsertionAfterFragmentReturnKeepsForeignOwnerDispatch() throws {
        final class RedirectedElement: Element {
            var redirectedOwner: Document?
            var ownerLookups = 0
            override func ownerDocument() -> Document? {
                ownerLookups += 1
                return redirectedOwner
            }
        }
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(Array("<p>initial</p>".utf8), context, [], .noTracking(), .htmlDefault)
        let privateDocument = builder.doc
        let foreign = try SwiftSoup.parse("<main></main>")
        let parent = try RedirectedElement(Tag.valueOf("div"), "")
        parent.redirectedOwner = foreign
        try foreign.body()!.appendChild(parent)
        builder.stack = [parent]
        builder.transition(.InBody)
        privateDocument.sourceRangeDirty = true
        privateDocument.dirtySourceRoots = [ObjectIdentifier(privateDocument): Weak(privateDocument)]
        foreign.dirtySourceRoots.removeAll()
        parent.sourceRangeDirty = false
        parent.ownerLookups = 0
        try builder.processStartTag("span")
        XCTAssertGreaterThan(parent.ownerLookups, 0)
        XCTAssertTrue(foreign.dirtySourceRoots[ObjectIdentifier(parent)]?.value === parent)
        XCTAssertTrue(privateDocument.dirtySourceRoots[ObjectIdentifier(privateDocument)]?.value === privateDocument)
        XCTAssertEqual(parent.childNodeSize(), 1)
        XCTAssertTrue(parent.childNode(0).parent() === parent)
        XCTAssertTrue(parent.childNode(0).ownerDocument() === foreign)
    }

    func testManualCharacterInsertionAfterFragmentReturnInvalidatesTextPredicates() throws {
        let builder = HtmlTreeBuilder()
        let context = try Element(Tag.valueOf("div"), "")
        _ = try builder.parseFragment(Array("<section></section>".utf8), context, [], .noTracking(), .htmlDefault)
        let document = builder.doc
        let root = try XCTUnwrap(document.children().first())
        let section = try XCTUnwrap(document.select("section").first())
        for _ in 0..<4 {
            XCTAssertEqual(try section.text(), "")
            XCTAssertEqual(try document.select("section:contains(後)").size(), 0)
            XCTAssertEqual(try document.select("section:empty").size(), 1)
        }
        let version = document.textMutationVersionToken()
        builder.stack = [root, section]
        builder.transition(.InBody)
        XCTAssertTrue(try builder.process(Token.Char().data(Array("後".utf8))))
        XCTAssertNotEqual(document.textMutationVersionToken(), version)
        XCTAssertEqual(try section.text(), "後")
        XCTAssertEqual(try document.select("section:contains(後)").size(), 1)
        XCTAssertEqual(try document.select("section:empty").size(), 0)
    }

}
