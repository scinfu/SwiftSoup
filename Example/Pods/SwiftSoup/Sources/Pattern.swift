//
//  Regex.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 08/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

#if !os(Linux)
	extension NSTextCheckingResult {
		func range(at idx: Int) -> NSRange {
			return rangeAt(idx)
		}
	}
#endif

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
         _ = try NCRegularExpression(pattern: self.pattern, options:[])
    }

    func matcher(in text: String) -> Matcher {
        do {
            let regex = try NCRegularExpression(pattern: self.pattern, options:[])
            let nsString = NSString(string: text)
            let results = regex.matches(in: text, options:[], range: NSRange(location: 0, length: nsString.length))

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
    let matches: [NCTextCheckingResult]
    let string: String
    var index: Int = -1

    public var count: Int { return matches.count}

    init(_ m: [NCTextCheckingResult], _ s: String) {
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
		let c = b.range(at:i)
        if(c.location == NSNotFound) {return nil}
		let result = string.substring(c.location, c.length)
        return result
    }
    public func group() -> String? {
        return group(0)
    }
}
