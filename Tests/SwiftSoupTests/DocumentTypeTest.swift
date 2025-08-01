//
//  DocumentTypeTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 06/11/16.
//

import XCTest
import SwiftSoup

class DocumentTypeTest: XCTestCase {

	func testConstructorValidationOkWithBlankName() {
		let fail: DocumentType? = DocumentType("", "", "", "")
		XCTAssertTrue(fail != nil)
	}

	func testConstructorValidationThrowsExceptionOnNulls() {
		let fail: DocumentType? = DocumentType("html", "", "", "")
		XCTAssertTrue(fail != nil)
	}

	func testConstructorValidationOkWithBlankPublicAndSystemIds() {
		let fail: DocumentType? = DocumentType("html", "", "", "")
		XCTAssertTrue(fail != nil)
	}

	func testOuterHtmlGeneration() {
		let html5 = DocumentType("html", "", "", "")
		XCTAssertEqual("<!doctype html>", try! html5.outerHtml())

		let publicDocType = DocumentType("html", "-//IETF//DTD HTML//", "", "")
		XCTAssertEqual("<!DOCTYPE html PUBLIC \"-//IETF//DTD HTML//\">", try! publicDocType.outerHtml())

		let systemDocType = DocumentType("html", "", "http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd", "")
		XCTAssertEqual("<!DOCTYPE html \"http://www.ibm.com/data/dtd/v11/ibmxhtml1-transitional.dtd\">", try! systemDocType.outerHtml())

		let combo = DocumentType("notHtml", "--public", "--system", "")
		XCTAssertEqual("<!DOCTYPE notHtml PUBLIC \"--public\" \"--system\">", try! combo.outerHtml())
	}
}
