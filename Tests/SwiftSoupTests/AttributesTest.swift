//
//  AttributesTest.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 29/10/16.
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

    func testRemoveAllKeys() {
        let a = Attributes()
        do {
            try a.put("One", "1")
            try a.put("Two", "2")
            try a.put("data-x", "3")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        a.removeAll(keys: [ "Two".utf8Array, "data-x".utf8Array ])

        XCTAssertEqual(1, a.size())
        XCTAssertTrue(a.hasKey(key: "One"))
        XCTAssertFalse(a.hasKey(key: "Two"))
        XCTAssertFalse(a.hasKey(key: "data-x"))
    }

    func testCompactAndMutate() {
        let a = Attributes()
        do {
            try a.put("One", "1")
            try a.put("Two", "2")
            try a.put("class", "alpha")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        a.compactAndMutate { attr in
            switch attr.getKey() {
            case "Two":
                return AttributeMutation(keep: false)
            case "One":
                return AttributeMutation(keep: true, newValue: "10".utf8Array)
            default:
                return AttributeMutation(keep: true)
            }
        }

        XCTAssertEqual(2, a.size())
        XCTAssertTrue(a.hasKey(key: "One"))
        XCTAssertFalse(a.hasKey(key: "Two"))
        XCTAssertTrue(a.hasKey(key: "class"))
        XCTAssertEqual("10", a.get(key: "One"))
        XCTAssertEqual("alpha", a.get(key: "class"))
    }

    func testKeyIndexLargeSetLookupAndRemove() {
        let a = Attributes()
        do {
            for i in 0..<20 {
                try a.put("key\(i)", "val\(i)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual("val12", a.get(key: "key12"))
        do {
            try a.remove(key: "key12")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual("", a.get(key: "key12"))
        XCTAssertEqual(19, a.size())
    }

    func testKeyIndexInvalidatedAfterCompactAndMutate() {
        let a = Attributes()
        do {
            for i in 0..<16 {
                try a.put("k\(i)", "v\(i)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        a.compactAndMutate { attr in
            if attr.getKey() == "k3" {
                return AttributeMutation(keep: false)
            }
            if attr.getKey() == "k7" {
                return AttributeMutation(keep: true, newValue: "v7x".utf8Array)
            }
            return AttributeMutation(keep: true)
        }
        XCTAssertEqual("", a.get(key: "k3"))
        XCTAssertEqual("v7x", a.get(key: "k7"))
        XCTAssertEqual(15, a.size())
    }

    func testLowercaseAllKeysNoOpWithoutUppercase() {
        let a = Attributes()
        do {
            try a.put("data-x", "1")
            try a.put("aria-label", "2")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        a.lowercaseAllKeys()
        XCTAssertTrue(a.hasKey(key: "data-x"))
        XCTAssertTrue(a.hasKey(key: "aria-label"))
    }

}
