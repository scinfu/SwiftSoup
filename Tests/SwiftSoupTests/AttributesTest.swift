//
//  AttributesTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 29/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import XCTest
import SwiftSoup

class AttributesTest: XCTestCase {

    func testHtml() {
		let a: Attributes = Attributes()
		do {
			try a.put("Tot", "a&p")
			try a.put("Hello", "There")
			try a.put("data-name", "Jsoup")
		} catch {}

		XCTAssertEqual(3, a.size())
		XCTAssertTrue(a.hasKey(key: "Tot"))
		XCTAssertTrue(a.hasKey(key: "Hello"))
		XCTAssertTrue(a.hasKey(key: "data-name"))
		XCTAssertFalse(a.hasKey(key: "tot"))
		XCTAssertTrue(a.hasKeyIgnoreCase(key: "tot"))
		XCTAssertEqual("There", try  a.getIgnoreCase(key: "hEllo"))

		XCTAssertEqual(1, a.dataset().count)
		XCTAssertEqual("Jsoup", a.dataset()["name"])
		XCTAssertEqual("", a.get(key: "tot"))
		XCTAssertEqual("a&p", a.get(key: "Tot"))
		XCTAssertEqual("a&p", try a.getIgnoreCase(key: "tot"))

		XCTAssertEqual(" Tot=\"a&amp;p\" Hello=\"There\" data-name=\"Jsoup\"", try a.html())
		XCTAssertEqual(try a.html(), try a.toString())
    }
//todo: se serve
//	func testIteratorRemovable() {
//		let a = Attributes()
//		do{
//			try a.put("Tot", "a&p")
//			try a.put("Hello", "There")
//			try a.put("data-name", "Jsoup")
//		}catch{}
//		
//		var iterator = a.iterator()
//		
//		iterator.next()
//		iterator.dropFirst()
//		XCTAssertEqual(2, a.size())
//	}

	func testIterator() {
		let a: Attributes = Attributes()
		let datas: [[String]] = [["Tot", "raul"], ["Hello", "pismuth"], ["data-name", "Jsoup"]]

		for atts in datas {
			try! a.put(atts[0], atts[1])
		}

		let iterator = a.makeIterator()
		XCTAssertTrue(iterator.next() != nil)
		var i = 0
		for attribute in a {
			XCTAssertEqual(datas[i][0], attribute.getKey())
			XCTAssertEqual(datas[i][1], attribute.getValue())
			i += 1
		}
		XCTAssertEqual(datas.count, i)
	}

	func testIteratorEmpty() {
		let a = Attributes()

		let iterator = a.makeIterator()
		XCTAssertNil(iterator.next())
	}

	static var allTests = {
		return [
			("testHtml", testHtml),
			("testIterator", testIterator),
			("testIteratorEmpty", testIteratorEmpty)
		]
	}()
}
