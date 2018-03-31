//
//  DocumentTypeTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 06/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class DocumentTypeTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

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

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testConstructorValidationOkWithBlankName", testConstructorValidationOkWithBlankName),
			("testConstructorValidationThrowsExceptionOnNulls", testConstructorValidationThrowsExceptionOnNulls),
			("testConstructorValidationOkWithBlankPublicAndSystemIds", testConstructorValidationOkWithBlankPublicAndSystemIds),
			("testOuterHtmlGeneration", testOuterHtmlGeneration)
		]
	}()
}
