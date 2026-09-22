//
//  Regex.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 08/10/16.
//

import Foundation

public struct Pattern: Sendable {
    public static let CASE_INSENSITIVE: Int = 0x02
    let pattern: String
    private let compiled: Result<NSRegularExpression, Error>

    init(_ pattern: String, options: NSRegularExpression.Options = []) {
        self.pattern = pattern
        compiled = Result { try NSRegularExpression(pattern: pattern, options: options) }
    }

    static public func compile(_ s: String) -> Pattern {
        return Pattern(s)
    }
    static public func compile(_ s: String, _ op: Int) -> Pattern {
        let options: NSRegularExpression.Options = (op & CASE_INSENSITIVE) != 0 ? [.caseInsensitive] : []
        return Pattern(s, options: options)
    }

    public func validate() throws {
        _ = try compiled.get()
    }

    public func matcher(in text: String) -> Matcher {
        do {
            let regex = try compiled.get()
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
        // Stay exhausted after the last match instead of advancing indefinitely.
        guard index < matches.count else { return false }
        index += 1
        return index < matches.count
    }

    /// Returns capture `i` from the current match (zero is the entire match).
    /// Returns nil before a successful `find()`, after exhaustion, for an invalid
    /// group index, or for an optional group that did not participate. A present
    /// zero-length capture returns an empty string.
    public func group(_ i: Int) -> String? {
        guard matches.indices.contains(index) else { return nil }
        let b = matches[index]
        guard i >= 0 && i < b.numberOfRanges else { return nil }
        #if !os(Linux) && !swift(>=4)
            let c = b.rangeAt(i)
        #else
            let c = b.range(at: i)
        #endif

        if(c.location == NSNotFound) {return nil}
        // Foundation ranges are UTF-16 offsets, not Swift Character offsets.
        // NSString also preserves scalar captures inside a composed grapheme.
        return (string as NSString).substring(with: c)
    }
    public func group() -> String? {
        return group(0)
    }
}
