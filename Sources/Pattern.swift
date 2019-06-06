//
//  Regex.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 08/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

public struct Pattern {
    public static let CASE_INSENSITIVE: Int = 0x02
    let pattern: String

    init(_ pattern: String) {
        self.pattern = pattern
    }

    static public func compile(_ s: String) -> Pattern {
        return Pattern(s)
    }
    static public func compile(_ s: String, _ op: Int) -> Pattern {
        return Pattern(s)
    }

    func validate()throws {
         _ = try NSRegularExpression(pattern: self.pattern, options: [])
    }

    public func matcher(in text: String) -> Matcher {
        do {
            let regex = try NSRegularExpression(pattern: self.pattern, options: [])
            let nsString = NSString(string: text)
            let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

            return Matcher(results, text)
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return Matcher([], text)
        }
    }

    public func toString() -> String {
        return pattern
    }
}

public class  Matcher {
    let matches: [NSTextCheckingResult]
    let string: String
    var index: Int = -1

    public var count: Int { return matches.count}

    init(_ m: [NSTextCheckingResult], _ s: String) {
        matches = m
        string = s
    }

    @discardableResult
    public func find() -> Bool {
        index += 1
        if(index < matches.count) {
            return true
        }
        return false
    }

    public func group(_ i: Int) -> String? {
        let b = matches[index]
        #if !os(Linux) && !swift(>=4)
            let c = b.rangeAt(i)
        #else
            let c = b.range(at: i)
        #endif

        if(c.location == NSNotFound) {return nil}
        let result = string.substring(c.location, c.length)
        return result
    }
    public func group() -> String? {
        return group(0)
    }
}
