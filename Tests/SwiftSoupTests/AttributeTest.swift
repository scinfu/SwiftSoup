//
//  AttributeTest.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 07/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
@testable import SwiftSoup
class AttributeTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

    func testHtml()throws {
        let attr = try Attribute(key: "key", value: "value &")
        XCTAssertEqual("key=\"value &amp;\"", attr.html())
        XCTAssertEqual(attr.html(), attr.toString())
    }

    func testWithSupplementaryCharacterInAttributeKeyAndValue()throws {
        let string =  "135361"
        let attr = try Attribute(key: string, value: "A" + string + "B")
        XCTAssertEqual(string + "=\"A" + string + "B\"", attr.html())
        XCTAssertEqual(attr.html(), attr.toString())
    }

    func testRemoveCaseSensitive()throws {
        let atteibute: Attributes = Attributes()
        try atteibute.put("Tot", "a&p")
        try atteibute.put("tot", "one")
        try atteibute.put("Hello", "There")
        try atteibute.put("hello", "There")
        try atteibute.put("data-name", "Jsoup")

        XCTAssertEqual(5, atteibute.size())
        try atteibute.remove(key: "Tot")
        try atteibute.remove(key: "Hello")
        XCTAssertEqual(3, atteibute.size())
        XCTAssertTrue(atteibute.hasKey(key: "tot"))
        XCTAssertFalse(atteibute.hasKey(key: "Tot"))
    }

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
			("testHtml", testHtml),
			("testWithSupplementaryCharacterInAttributeKeyAndValue", testWithSupplementaryCharacterInAttributeKeyAndValue),
			("testRemoveCaseSensitive", testRemoveCaseSensitive)
		]
	}()

}
