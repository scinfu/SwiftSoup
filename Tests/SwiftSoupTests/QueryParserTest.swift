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

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

	func testOrGetsCorrectPrecedence()throws {
		// tests that a selector "a b, c d, e f" evals to (a AND b) OR (c AND d) OR (e AND f)"
		// top level or, three child ands
		let eval: Evaluator = try QueryParser.parse("a b, c d, e f")
        guard let orEvaluator = eval as? CombiningEvaluator.Or else {
            XCTAssertTrue(false)
            return
        }
		XCTAssertEqual(3, orEvaluator.evaluators.count)
		for innerEval: Evaluator in orEvaluator.evaluators {
            guard let and: CombiningEvaluator.And = innerEval as? CombiningEvaluator.And else {
                XCTAssertTrue(false)
                return
            }
			XCTAssertEqual(2, and.evaluators.count)
			XCTAssertTrue((and.evaluators[0] as? Evaluator.Tag) != nil)
			XCTAssertTrue((and.evaluators[1] as? StructuralEvaluator.Parent) != nil)
		}
	}

	func testParsesMultiCorrectly()throws {
		let eval: Evaluator = try QueryParser.parse(".foo > ol, ol > li + li")
        guard let orEvaluator: CombiningEvaluator.Or = eval as? CombiningEvaluator.Or else {
            XCTAssertTrue(false)
            return
        }
		XCTAssertEqual(2, orEvaluator.evaluators.count)
        guard let andLeft: CombiningEvaluator.And = orEvaluator.evaluators[0] as? CombiningEvaluator.And else {
            XCTAssertTrue(false)
            return
        }
        guard let andRight: CombiningEvaluator.And = orEvaluator.evaluators[1] as? CombiningEvaluator.And else {
            XCTAssertTrue(false)
            return
        }

		XCTAssertEqual("ol :ImmediateParent.foo", andLeft.toString())
		XCTAssertEqual(2, andLeft.evaluators.count)
		XCTAssertEqual("li :prevli :ImmediateParentol", andRight.toString())
		XCTAssertEqual(2, andRight.evaluators.count)
	}

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testOrGetsCorrectPrecedence", testOrGetsCorrectPrecedence),
			("testParsesMultiCorrectly", testParsesMultiCorrectly)
		]
	}()

}
