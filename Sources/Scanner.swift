//
//  SwiftScanner.swift
//  SwiftSoup
//
//  Created by Nabil on 03/07/17.
//  Copyright © 2017 Nabil Chatbi. All rights reserved.
//

import Foundation

struct Scanner<Element> {
    typealias Element = UInt8
    var pointer: UnsafePointer<Element>
    let endAddress: UnsafePointer<Element>
    var elements: UnsafeBufferPointer<Element>
    // assuming you don't mutate no copy _should_ occur
    let elementsCopy: [Element]
}

extension Scanner {
    init(_ data: [Element]) {
        self.elementsCopy = data
        self.elements = elementsCopy.withUnsafeBufferPointer { $0 }
        self.pointer = elements.baseAddress!
        self.endAddress = elements.endAddress
    }
}

extension Scanner {
    func peek(aheadBy n: Int = 0) -> Element? {
        guard pointer.advanced(by: n) < endAddress else { return nil }
        return pointer.advanced(by: n).pointee
    }
    
    /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
    @discardableResult
    mutating func pop() -> Element {
        assert(pointer != endAddress)
        defer { pointer = pointer.advanced(by: 1) }
        return pointer.pointee
    }
    
    /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
    @discardableResult
    mutating func attemptPop() throws -> Element {
        guard pointer < endAddress else { throw ScannerError.Reason.endOfStream }
        defer { pointer = pointer.advanced(by: 1) }
        return pointer.pointee
    }
    
    /// - Precondition: index != bytes.endIndex. It is assumed before calling pop that you have
    mutating func pop(_ n: Int) {
        assert(pointer.advanced(by: n) <= endAddress)
        pointer = pointer.advanced(by: n)
    }
}

extension Scanner {
    var isEmpty: Bool {
        return pointer == endAddress
    }
}

struct ScannerError: Swift.Error {
    let position: UInt
    let reason: Reason
    
    enum Reason: Swift.Error {
        case endOfStream
    }
}

extension UnsafeBufferPointer {
    fileprivate var endAddress: UnsafePointer<Element> {
        return baseAddress!.advanced(by: endIndex)
    }
}


