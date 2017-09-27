//
//  ParseSettingsTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
import SwiftSoup

class ParseSettingsTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

    func testCaseSupport() {
        let bothOn = ParseSettings(true, true)
        let bothOff = ParseSettings(false, false)
        let tagOn = ParseSettings(true, false)
        let attrOn = ParseSettings(false, true)

        XCTAssertEqual("FOO", bothOn.normalizeTag("FOO"))
        XCTAssertEqual("FOO", bothOn.normalizeAttribute("FOO"))

        XCTAssertEqual("foo", bothOff.normalizeTag("FOO"))
        XCTAssertEqual("foo", bothOff.normalizeAttribute("FOO"))

        XCTAssertEqual("FOO", tagOn.normalizeTag("FOO"))
        XCTAssertEqual("foo", tagOn.normalizeAttribute("FOO"))

        XCTAssertEqual("foo", attrOn.normalizeTag("FOO"))
        XCTAssertEqual("FOO", attrOn.normalizeAttribute("FOO"))
    }

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testCaseSupport", testCaseSupport)
		]
	}()
}
