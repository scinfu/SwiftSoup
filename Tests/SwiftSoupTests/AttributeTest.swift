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

    func testHtml() {
        let attr = try! Attribute(key: "key", value: "value &")
        XCTAssertEqual("key=\"value &amp;\"", attr.html())
        XCTAssertEqual(attr.html(), attr.toString())
    }

    func testWithSupplementaryCharacterInAttributeKeyAndValue() {
        let s =  "135361"
        let attr = try! Attribute(key: s, value: "A" + s + "B")
        XCTAssertEqual(s + "=\"A" + s + "B\"", attr.html())
        XCTAssertEqual(attr.html(), attr.toString())
    }

    func testRemoveCaseSensitive()throws {
        let a: Attributes = Attributes()
        try a.put("Tot", "a&p")
        try a.put("tot", "one")
        try a.put("Hello", "There")
        try a.put("hello", "There")
        try a.put("data-name", "Jsoup")

        XCTAssertEqual(5, a.size())
        try a.remove(key: "Tot")
        try a.remove(key: "Hello")
        XCTAssertEqual(3, a.size())
        XCTAssertTrue(a.hasKey(key: "tot"))
        XCTAssertFalse(a.hasKey(key: "Tot"))
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
