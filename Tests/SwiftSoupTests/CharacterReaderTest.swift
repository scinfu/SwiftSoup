//
//  CharacterReaderTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 12/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
import SwiftSoup

class CharacterReaderTest: XCTestCase {

    func testLinuxTestSuiteIncludesAllTests() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
            let thisClass = type(of: self)
            let linuxCount = thisClass.allTests.count
            let darwinCount = Int(thisClass.defaultTestSuite.testCaseCount)
            XCTAssertEqual(linuxCount, darwinCount, "\(darwinCount - linuxCount) tests are missing from allTests")
        #endif
    }

    func testConsume() {
        let r = CharacterReader("one")
        XCTAssertEqual(0, r.getPos())
        XCTAssertEqual("o", r.current())
        XCTAssertEqual("o", r.consume())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("n", r.current())
        XCTAssertEqual(1, r.getPos())
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.consume())
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.consume())
    }

    func testUnconsume() {
        let r = CharacterReader("one")
        XCTAssertEqual("o", r.consume())
        XCTAssertEqual("n", r.current())
        r.unconsume()
        XCTAssertEqual("o", r.current())

        XCTAssertEqual("o", r.consume())
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        r.unconsume()
        XCTAssertFalse(r.isEmpty())
        XCTAssertEqual("e", r.current())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())

        XCTAssertEqual(CharacterReader.EOF, r.consume())
        r.unconsume()
        XCTAssertTrue(r.isEmpty())
        XCTAssertEqual(CharacterReader.EOF, r.current())
    }

    func testMark() {
        let r = CharacterReader("one")
        XCTAssertEqual("o", r.consume())
        r.markPos()
        XCTAssertEqual("n", r.consume())
        XCTAssertEqual("e", r.consume())
        XCTAssertTrue(r.isEmpty())
        r.rewindToMark()
        XCTAssertEqual("n", r.consume())
    }

    func testConsumeToEnd() {
        let input = "one two three"
        let r = CharacterReader(input)
        let toEnd = r.consumeToEnd()
        XCTAssertEqual(input, toEnd)
        XCTAssertTrue(r.isEmpty())
    }

    func testNextIndexOfChar() {
        let input = "blah blah"
        let r = CharacterReader(input)

        XCTAssertEqual(-1, r.nextIndexOf("x"))
        XCTAssertEqual(3, r.nextIndexOf("h"))
        let pull = r.consumeTo("h")
        XCTAssertEqual("bla", pull)
        XCTAssertEqual("h", r.consume())
        XCTAssertEqual(2, r.nextIndexOf("l"))
        XCTAssertEqual(" blah", r.consumeToEnd())
        XCTAssertEqual(-1, r.nextIndexOf("x"))
    }

    func testNextIndexOfString() {
        let input = "One Two something Two Three Four"
        let r = CharacterReader(input)

        XCTAssertEqual(-1, r.nextIndexOf("Foo"))
        XCTAssertEqual(4, r.nextIndexOf("Two"))
        XCTAssertEqual("One Two ", r.consumeTo("something"))
        XCTAssertEqual(10, r.nextIndexOf("Two"))
        XCTAssertEqual("something Two Three Four", r.consumeToEnd())
        XCTAssertEqual(-1, r.nextIndexOf("Two"))
    }

    func testNextIndexOfUnmatched() {
        let r = CharacterReader("<[[one]]")
        XCTAssertEqual(-1, r.nextIndexOf("]]>"))
    }

    func testConsumeToChar() {
        let r = CharacterReader("One Two Three")
        XCTAssertEqual("One ", r.consumeTo("T"))
        XCTAssertEqual("", r.consumeTo("T")) // on Two
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo ", r.consumeTo("T"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("hree", r.consumeTo("T")) // consume to end
    }

    func testConsumeToString() {
        let r = CharacterReader("One Two Two Four")
        XCTAssertEqual("One ", r.consumeTo("Two"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo ", r.consumeTo("Two"))
        XCTAssertEqual("T", r.consume())
        XCTAssertEqual("wo Four", r.consumeTo("Qux"))
    }

    func testAdvance() {
        let r = CharacterReader("One Two Three")
        XCTAssertEqual("O", r.consume())
        r.advance()
        XCTAssertEqual("e", r.consume())
    }

    func testConsumeToAny() {
        let r = CharacterReader("One &bar; qux")
        XCTAssertEqual("One ", r.consumeToAny("&", ";"))
        XCTAssertTrue(r.matches("&"))
        XCTAssertTrue(r.matches("&bar;"))
        XCTAssertEqual("&", r.consume())
        XCTAssertEqual("bar", r.consumeToAny("&", ";"))
        XCTAssertEqual(";", r.consume())
        XCTAssertEqual(" qux", r.consumeToAny("&", ";"))
    }

    func testConsumeLetterSequence() {
        let r = CharacterReader("One &bar; qux")
        XCTAssertEqual("One", r.consumeLetterSequence())
        XCTAssertEqual(" &", r.consumeTo("bar;"))
        XCTAssertEqual("bar", r.consumeLetterSequence())
        XCTAssertEqual("; qux", r.consumeToEnd())
    }

    func testConsumeLetterThenDigitSequence() {
        let r = CharacterReader("One12 Two &bar; qux")
        XCTAssertEqual("One12", r.consumeLetterThenDigitSequence())
        XCTAssertEqual(" ", r.consume())
        XCTAssertEqual("Two", r.consumeLetterThenDigitSequence())
        XCTAssertEqual(" &bar; qux", r.consumeToEnd())
    }

    func testMatches() {
        let r = CharacterReader("One Two Three")
        XCTAssertTrue(r.matches("O"))
        XCTAssertTrue(r.matches("One Two Three"))
        XCTAssertTrue(r.matches("One"))
        XCTAssertFalse(r.matches("one"))
        XCTAssertEqual("O", r.consume())
        XCTAssertFalse(r.matches("One"))
        XCTAssertTrue(r.matches("ne Two Three"))
        XCTAssertFalse(r.matches("ne Two Three Four"))
        XCTAssertEqual("ne Two Three", r.consumeToEnd())
        XCTAssertFalse(r.matches("ne"))
    }

    func testMatchesIgnoreCase() {
        let r = CharacterReader("One Two Three")
        XCTAssertTrue(r.matchesIgnoreCase("O"))
        XCTAssertTrue(r.matchesIgnoreCase("o"))
        XCTAssertTrue(r.matches("O"))
        XCTAssertFalse(r.matches("o"))
        XCTAssertTrue(r.matchesIgnoreCase("One Two Three"))
        XCTAssertTrue(r.matchesIgnoreCase("ONE two THREE"))
        XCTAssertTrue(r.matchesIgnoreCase("One"))
        XCTAssertTrue(r.matchesIgnoreCase("one"))
        XCTAssertEqual("O", r.consume())
        XCTAssertFalse(r.matchesIgnoreCase("One"))
        XCTAssertTrue(r.matchesIgnoreCase("NE Two Three"))
        XCTAssertFalse(r.matchesIgnoreCase("ne Two Three Four"))
        XCTAssertEqual("ne Two Three", r.consumeToEnd())
        XCTAssertFalse(r.matchesIgnoreCase("ne"))
    }

    func testContainsIgnoreCase() {
        let r = CharacterReader("One TWO three")
        XCTAssertTrue(r.containsIgnoreCase("two"))
        XCTAssertTrue(r.containsIgnoreCase("three"))
        // weird one: does not find one, because it scans for consistent case only
        XCTAssertFalse(r.containsIgnoreCase("one"))
    }

    func testMatchesAny() {
        //let scan = [" ", "\n", "\t"]
        let r = CharacterReader("One\nTwo\tThree")
        XCTAssertFalse(r.matchesAny(" ", "\n", "\t"))
        XCTAssertEqual("One", r.consumeToAny(" ", "\n", "\t"))
        XCTAssertTrue(r.matchesAny(" ", "\n", "\t"))
        XCTAssertEqual("\n", r.consume())
        XCTAssertFalse(r.matchesAny(" ", "\n", "\t"))
    }

    func testCachesStrings() {
        let r = CharacterReader("Check\tCheck\tCheck\tCHOKE\tA string that is longer than 16 chars")
        let one = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let two = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let three = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let four = r.consumeTo("\t")
        XCTAssertEqual("\t", r.consume())
        let five = r.consumeTo("\t")

        XCTAssertEqual("Check", one)
        XCTAssertEqual("Check", two)
        XCTAssertEqual("Check", three)
        XCTAssertEqual("CHOKE", four)
        XCTAssertTrue(one == two)
        XCTAssertTrue(two == three)
        XCTAssertTrue(three != four)
        XCTAssertTrue(four != five)
        XCTAssertEqual(five, "A string that is longer than 16 chars")
    }

    func testRangeEquals() {
//        let r = CharacterReader("Check\tCheck\tCheck\tCHOKE")
//        XCTAssertTrue(r.rangeEquals(0, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(0, 5, "CHOKE"))
//        XCTAssertFalse(r.rangeEquals(0, 5, "Chec"))
//
//        XCTAssertTrue(r.rangeEquals(6, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(6, 5, "Chuck"))
//
//        XCTAssertTrue(r.rangeEquals(12, 5, "Check"))
//        XCTAssertFalse(r.rangeEquals(12, 5, "Cheeky"))
//
//        XCTAssertTrue(r.rangeEquals(18, 5, "CHOKE"))
//        XCTAssertFalse(r.rangeEquals(18, 5, "CHIKE"))
    }

	static var allTests = {
		return [
            ("testLinuxTestSuiteIncludesAllTests", testLinuxTestSuiteIncludesAllTests),
            ("testConsume", testConsume),
			("testUnconsume", testUnconsume),
			("testMark", testMark),
			("testConsumeToEnd", testConsumeToEnd),
			("testNextIndexOfChar", testNextIndexOfChar),
			("testNextIndexOfString", testNextIndexOfString),
			("testNextIndexOfUnmatched", testNextIndexOfUnmatched),
			("testConsumeToChar", testConsumeToChar),
			("testConsumeToString", testConsumeToString),
			("testAdvance", testAdvance),
			("testConsumeToAny", testConsumeToAny),
			("testConsumeLetterSequence", testConsumeLetterSequence),
			("testConsumeLetterThenDigitSequence", testConsumeLetterThenDigitSequence),
			("testMatches", testMatches),
			("testMatchesIgnoreCase", testMatchesIgnoreCase),
			("testContainsIgnoreCase", testContainsIgnoreCase),
			("testMatchesAny", testMatchesAny),
			("testCachesStrings", testCachesStrings),
			("testRangeEquals", testRangeEquals)
			]
	}()

}
