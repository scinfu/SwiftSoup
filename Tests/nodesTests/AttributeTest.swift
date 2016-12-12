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
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testHtml()
    {
        let attr = try! Attribute(key: "key", value: "value &");
        XCTAssertEqual("key=\"value &amp;\"", attr.html());
        XCTAssertEqual(attr.html(), attr.toString());
    }
    
    func testWithSupplementaryCharacterInAttributeKeyAndValue() {
        let s =  String("135361".characters);
        let attr = try! Attribute(key: s, value: "A" + s + "B");
        XCTAssertEqual(s + "=\"A" + s + "B\"", attr.html());
        XCTAssertEqual(attr.html(), attr.toString());
    }
	

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
