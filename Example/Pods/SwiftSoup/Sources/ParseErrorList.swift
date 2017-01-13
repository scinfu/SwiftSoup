//
//  ParseErrorList.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 19/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

public class ParseErrorList {
    private static let INITIAL_CAPACITY: Int = 16
    private let maxSize: Int
    private let initialCapacity: Int
    private var array: Array<ParseError?> = Array<ParseError>()

    init(_ initialCapacity: Int, _ maxSize: Int) {
        self.maxSize = maxSize
        self.initialCapacity = initialCapacity
        array = Array(repeating: nil, count: maxSize)
    }

    func canAddError() -> Bool {
        return array.count < maxSize
    }

    func getMaxSize() -> Int {
        return maxSize
    }

    static func noTracking() -> ParseErrorList {
        return ParseErrorList(0, 0)
    }

    static func tracking(_ maxSize: Int) -> ParseErrorList {
        return ParseErrorList(INITIAL_CAPACITY, maxSize)
    }

    //    // you need to provide the Equatable functionality
    //    static func ==(leftFoo: Foo, rightFoo: Foo) -> Bool {
    //        return ObjectIdentifier(leftFoo) == ObjectIdentifier(rightFoo)
    //    }

    open func add(_ e: ParseError) {
        array.append(e)
    }

    open func add(_ index: Int, _ element: ParseError) {
        array.insert(element, at: index)
    }

}
