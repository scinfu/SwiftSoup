//
//  TokenQueueTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 13/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
import SwiftSoup

class TokenQueueTest: XCTestCase {
    
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
    
    func testChompBalanced() {
        let tq = TokenQueue(":contains(one (two) three) four")
        let pre = tq.consumeTo("(")
        let guts = tq.chompBalanced("(", ")")
        let remainder = tq.remainder()
        
        XCTAssertEqual(":contains", pre)
        XCTAssertEqual("one (two) three", guts)
        XCTAssertEqual(" four", remainder)
    }
    
    func testChompEscapedBalanced() {
        let tq = TokenQueue(":contains(one (two) \\( \\) \\) three) four")
        let pre = tq.consumeTo("(")
        let guts = tq.chompBalanced("(", ")")
        let remainder = tq.remainder()
        
        XCTAssertEqual(":contains", pre)
        XCTAssertEqual("one (two) \\( \\) \\) three", guts)
        XCTAssertEqual("one (two) ( ) ) three", TokenQueue.unescape(guts))
        XCTAssertEqual(" four", remainder)
    }
    
    func testChompBalancedMatchesAsMuchAsPossible() {
        let tq = TokenQueue("unbalanced(something(or another")
        tq.consumeTo("(")
        let match = tq.chompBalanced("(", ")")
        XCTAssertEqual("something(or another", match)
    }
    
    func testUnescape() {
        XCTAssertEqual("one ( ) \\", TokenQueue.unescape("one \\( \\) \\\\"))
    }
    
    func testChompToIgnoreCase() {
        let t = "<textarea>one < two </TEXTarea>"
        var tq = TokenQueue(t)
        var data = tq.chompToIgnoreCase("</textarea")
        XCTAssertEqual("<textarea>one < two ", data)
        
        tq = TokenQueue("<textarea> one two < three </oops>")
        data = tq.chompToIgnoreCase("</textarea")
        XCTAssertEqual("<textarea> one two < three </oops>", data)
    }
    
    func testAddFirst() {
        let tq = TokenQueue("One Two")
        tq.consumeWord()
        tq.addFirst("Three")
        XCTAssertEqual("Three Two", tq.remainder())
    }
    
}
