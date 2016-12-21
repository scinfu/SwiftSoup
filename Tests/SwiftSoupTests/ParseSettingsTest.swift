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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
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
    
}
