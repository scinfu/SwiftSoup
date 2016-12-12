//
//  QueryParserTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import XCTest
import SwiftSoup

class QueryParserTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
	
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
	
	func testOrGetsCorrectPrecedence()throws {
		// tests that a selector "a b, c d, e f" evals to (a AND b) OR (c AND d) OR (e AND f)"
		// top level or, three child ands
		let eval: Evaluator = try QueryParser.parse("a b, c d, e f");
		XCTAssertTrue((eval as? CombiningEvaluator.Or) != nil);
		let or: CombiningEvaluator.Or = eval as! CombiningEvaluator.Or
		XCTAssertEqual(3, or.evaluators.count);
		for innerEval:Evaluator in or.evaluators {
			XCTAssertTrue((innerEval as? CombiningEvaluator.And) != nil);
			let and: CombiningEvaluator.And = innerEval as! CombiningEvaluator.And
			XCTAssertEqual(2, and.evaluators.count);
			XCTAssertTrue((and.evaluators[0] as? Evaluator.Tag) != nil);
			XCTAssertTrue((and.evaluators[1] as? StructuralEvaluator.Parent) != nil);
		}
	}
	
	func testParsesMultiCorrectly()throws {
		let eval: Evaluator = try QueryParser.parse(".foo > ol, ol > li + li");
		XCTAssertTrue((eval as? CombiningEvaluator.Or) != nil);
		let or: CombiningEvaluator.Or = eval as! CombiningEvaluator.Or
		XCTAssertEqual(2, or.evaluators.count);
		
		let andLeft: CombiningEvaluator.And = or.evaluators[0] as! CombiningEvaluator.And
		let andRight: CombiningEvaluator.And = or.evaluators[1] as! CombiningEvaluator.And
		
		XCTAssertEqual("ol :ImmediateParent.foo", andLeft.toString());
		XCTAssertEqual(2, andLeft.evaluators.count);
		XCTAssertEqual("li :prevli :ImmediateParentol", andRight.toString());
		XCTAssertEqual(2, andRight.evaluators.count);
	}
	
}
