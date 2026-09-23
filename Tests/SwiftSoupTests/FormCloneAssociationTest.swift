import XCTest
@testable import SwiftSoup

final class FormCloneAssociationTest: XCTestCase {
    private func form(_ root: Element, _ query: String = "form") throws -> FormElement {
        try XCTUnwrap(root.select(query).first() as? FormElement)
    }

    func testDocumentCloneUsesClonedControlsAndPreservesIndependentMutations() throws {
        let original = try SwiftSoup.parse("<form id=f><input name=a value=original><div><textarea name=b>text</textarea></div></form>")
        let clone = original.copy() as! Document
        let oldForm = try form(original)
        let newForm = try form(clone)
        let oldControls = oldForm.elements().array()
        let newControls = newForm.elements().array()
        XCTAssertEqual(newControls.count, 2)
        XCTAssertEqual(newControls.map(ObjectIdentifier.init), try newForm.select("input,textarea").array().map(ObjectIdentifier.init))
        for (old, new) in zip(oldControls, newControls) {
            XCTAssertFalse(old === new)
            XCTAssertTrue(new.ownerDocument() === clone)
        }
        try XCTUnwrap(newControls.first).val("changed")
        XCTAssertEqual(try newForm.select("input").val(), "changed")
        XCTAssertEqual(try oldForm.select("input").val(), "original")
        try XCTUnwrap(oldControls.first).val("old changed")
        XCTAssertEqual(try newForm.select("input").val(), "changed")
    }

    func testStandaloneFormCloneKeepsItsControlList() throws {
        let doc = try SwiftSoup.parse("<form><input name=a><button name=b>Submit</button></form>")
        let original = try form(doc)
        for clone in [original.copy() as! FormElement, original.copy(with: nil) as! FormElement] {
            XCTAssertNil(clone.parent())
            XCTAssertEqual(clone.elements().size(), 2)
            XCTAssertEqual(clone.elements().array().map(ObjectIdentifier.init), try clone.select("input,button").array().map(ObjectIdentifier.init))
            XCTAssertFalse(clone.elements().first() === original.elements().first())
        }
    }

    func testLeafFormsAndAssociationsOutsideTheFormSubtreeAreReboundInDocumentCopies() throws {
        let doc = try SwiftSoup.parse("<input id=before><form id=a></form><form id=b></form><input id=after>")
        let a = try form(doc, "#a")
        let b = try form(doc, "#b")
        let before = try XCTUnwrap(doc.getElementById("before"))
        let after = try XCTUnwrap(doc.getElementById("after"))
        a.addElement(after).addElement(before).addElement(after)
        b.addElement(before)
        let clone = doc.copy() as! Document
        let clonedBefore = try XCTUnwrap(clone.getElementById("before"))
        let clonedAfter = try XCTUnwrap(clone.getElementById("after"))
        XCTAssertEqual(try form(clone, "#a").elements().array().map(ObjectIdentifier.init), [clonedAfter, clonedBefore, clonedAfter].map(ObjectIdentifier.init))
        XCTAssertTrue(try form(clone, "#b").elements().first() === clonedBefore)
        XCTAssertFalse(clonedBefore === before)
        XCTAssertFalse(clonedAfter === after)
    }

    func testExternalAssociationsRetainTheirIdentityWhenNotPartOfTheCopiedTree() throws {
        let doc = try SwiftSoup.parse("<form id=f><input id=inside></form><input id=outside>")
        let original = try form(doc)
        let outside = try XCTUnwrap(doc.getElementById("outside"))
        original.addElement(outside)
        let clone = original.copy() as! FormElement
        XCTAssertEqual(clone.elements().size(), 2)
        XCTAssertTrue(clone.elements().first() === (try clone.getElementById("inside")))
        XCTAssertTrue(clone.elements().last() === outside)
        let shallow = original.copy(parent: nil) as! FormElement
        XCTAssertEqual(shallow.elements().array().map(ObjectIdentifier.init), original.elements().array().map(ObjectIdentifier.init))
    }

    func testCopiesPreserveManualMembershipAndEmptyAssociations() throws {
        let doc = try SwiftSoup.parse("<section><form id=f></form><div id=manual></div></section>")
        let original = try form(doc)
        original.addElement(try XCTUnwrap(doc.getElementById("manual")))
        // Membership comes from the form's association list, not a tag-name scan.
        try original.tagName("section")
        let clone = doc.copy() as! Document
        let clonedForm = try form(clone, "#f")
        XCTAssertTrue(clonedForm.elements().first() === (try clone.getElementById("manual")))
        let empty = FormElement(try Tag.valueOf("form"), [])
        XCTAssertTrue((empty.copy() as! FormElement).elements().isEmpty())
    }
}
