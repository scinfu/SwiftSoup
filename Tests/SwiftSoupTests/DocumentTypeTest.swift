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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
	func testConstructorValidationOkWithBlankName() {
		let fail: DocumentType? = DocumentType("","", "", "")
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
	
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
