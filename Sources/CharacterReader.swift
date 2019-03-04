//
//  CharacterReader.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 10/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 CharacterReader consumes tokens off a string. To replace the old TokenQueue.
 */
public final class CharacterReader {
    private static let empty = ""
    public static let EOF: UnicodeScalar = "\u{FFFF}"//65535
    private let input: String.UnicodeScalarView
    private var pos: String.UnicodeScalarView.Index
    private var mark: String.UnicodeScalarView.Index
    //private let stringCache: Array<String?> // holds reused strings in this doc, to lessen garbage

    public init(_ input: String) {
        self.input = input.unicodeScalars
        self.pos = input.startIndex
        self.mark = input.startIndex
    }

    public func getPos() -> Int {
        return input.distance(from: input.startIndex, to: pos)
    }

    public func isEmpty() -> Bool {
        return pos >= input.endIndex
    }

    public func current() -> UnicodeScalar {
        return (pos >= input.endIndex) ? CharacterReader.EOF : input[pos]
    }

    @discardableResult
    public func consume() -> UnicodeScalar {
        guard pos < input.endIndex else {
            return CharacterReader.EOF
        }
        let val = input[pos]
        pos = input.index(after: pos)
        return val
    }

    public func unconsume() {
        guard pos > input.startIndex else { return }
        pos = input.index(before: pos)
    }

    public func advance() {
        guard pos < input.endIndex else { return }
        pos = input.index(after: pos)
    }

    public func markPos() {
        mark = pos
    }

    public func rewindToMark() {
        pos = mark
    }

    public func consumeAsString() -> String {
        guard pos < input.endIndex else { return "" }
        let str = String(input[pos])
        pos = input.index(after: pos)
        return str
    }

    /**
     * Locate the next occurrence of a Unicode scalar
     *
     * - Parameter c: scan target
     * - Returns: offset between current position and next instance of target. -1 if not found.
     */
    public func nextIndexOf(_ c: UnicodeScalar) -> String.UnicodeScalarView.Index? {
        // doesn't handle scanning for surrogates
        return input[pos...].firstIndex(of: c)
    }

    /**
     * Locate the next occurence of a target string
     *
     * - Parameter seq: scan target
     * - Returns: index of next instance of target. nil if not found.
     */
    public func nextIndexOf(_ seq: String) -> String.UnicodeScalarView.Index? {
        // doesn't handle scanning for surrogates
        var start = pos
        let targetScalars = seq.unicodeScalars
        guard let firstChar = targetScalars.first else { return pos } // search for "" -> current place
        MATCH: while true {
            // Match on first scalar
            guard let firstCharIx = input[start...].firstIndex(of: firstChar) else { return nil }
            var current = firstCharIx
            // Then manually match subsequent scalars
            for scalar in targetScalars.dropFirst() {
                current = input.index(after: current)
                guard current < input.endIndex else { return nil }
                if input[current] != scalar {
                    start = input.index(after: firstCharIx)
                    continue MATCH
                }
            }
            // full match; current is at position of last matching character
            return firstCharIx
        }
    }
    
    public func consumeTo(_ c: UnicodeScalar) -> String {
        guard let targetIx = nextIndexOf(c) else {
            return consumeToEnd()
        }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }

    public func consumeTo(_ seq: String) -> String {
        guard let targetIx = nextIndexOf(seq) else {
            return consumeToEnd()
        }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }

    public func consumeToAny(_ chars: UnicodeScalar...) -> String {
        return consumeToAny(chars)
    }
    
    public func consumeToAny(_ chars: [UnicodeScalar]) -> String {
        let start = pos
        while pos < input.endIndex {
            if chars.contains(input[pos]) {
                break
            }
            pos = input.index(after: pos)
        }
        return cacheString(start, pos)
    }

    public func consumeToAnySorted(_ chars: UnicodeScalar...) -> String {
        return consumeToAny(chars)
    }
    
    public func consumeToAnySorted(_ chars: [UnicodeScalar]) -> String {
        return consumeToAny(chars)
    }

    static let dataTerminators: [UnicodeScalar] = [.Ampersand, .LessThan, TokeniserStateVars.nullScalr]
    // read to &, <, or null
    public func consumeData() -> String {
        return consumeToAny(CharacterReader.dataTerminators)
    }

    static let tagNameTerminators: [UnicodeScalar] = [.BackslashT, .BackslashN, .BackslashR, .BackslashF, .Space, .Slash, .GreaterThan, TokeniserStateVars.nullScalr]
    // read to '\t', '\n', '\r', '\f', ' ', '/', '>', or nullChar
    public func consumeTagName() -> String {
        return consumeToAny(CharacterReader.tagNameTerminators)
    }

    public func consumeToEnd() -> String {
        let consumed = cacheString(pos, input.endIndex)
        pos = input.endIndex
        return consumed
    }

    public func consumeLetterSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let c = input[pos]
            if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(CharacterSet.letters)) {
                pos = input.index(after: pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }

    public func consumeLetterThenDigitSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let c = input[pos]
            if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(CharacterSet.letters)) {
                pos = input.index(after: pos)
            } else {
                break
            }
        }
        while pos < input.endIndex {
            let c = input[pos]
            if (c >= "0" && c <= "9") {
                pos = input.index(after: pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }

    public func consumeHexSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let c = input[pos]
            if ((c >= "0" && c <= "9") || (c >= "A" && c <= "F") || (c >= "a" && c <= "f")) {
                pos = input.index(after: pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }

    public func consumeDigitSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let c = input[pos]
            if (c >= "0" && c <= "9") {
                pos = input.index(after: pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }

    public func matches(_ c: UnicodeScalar) -> Bool {
        return !isEmpty() && input[pos] == c

    }

    public func matches(_ seq: String, ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        var current = pos
        let scalars = seq.unicodeScalars
        for scalar in scalars {
            guard current < input.endIndex else { return false }
            if ignoreCase {
                guard input[current].uppercase == scalar.uppercase else { return false }
            } else {
                guard input[current] == scalar else { return false }
            }
            current = input.index(after: current)
        }
        if consume {
            pos = current
        }
        return true
    }

    public func matchesIgnoreCase(_ seq: String ) -> Bool {
        return matches(seq, ignoreCase: true)
    }

    public func matchesAny(_ seq: UnicodeScalar...) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesAny(_ seq: [UnicodeScalar]) -> Bool {
        guard pos < input.endIndex else { return false }
        return seq.contains(input[pos])
    }

    public func matchesAnySorted(_ seq: [UnicodeScalar]) -> Bool {
        return matchesAny(seq)
    }

    public func matchesLetter() -> Bool {
        guard pos < input.endIndex else { return false }
        let c = input[pos]
        return (c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(CharacterSet.letters)
    }

    public func matchesDigit() -> Bool {
        guard pos < input.endIndex else { return false }
        let c = input[pos]
        return c >= "0" && c <= "9"
    }

    @discardableResult
    public func matchConsume(_ seq: String) -> Bool {
        return matches(seq, consume: true)
    }

    @discardableResult
    public func matchConsumeIgnoreCase(_ seq: String) -> Bool {
        return matches(seq, ignoreCase: true, consume: true)
    }

    public func containsIgnoreCase(_ seq: String ) -> Bool {
        // used to check presence of </title>, </style>. only finds consistent case.
        let loScan = seq.lowercased(with: Locale(identifier: "en"))
        let hiScan = seq.uppercased(with: Locale(identifier: "eng"))
        return nextIndexOf(loScan) != nil || nextIndexOf(hiScan) != nil
    }

    public func toString() -> String {
        return String(input[pos...])
    }

    /**
     * Originally intended as a caching mechanism for strings, but caching doesn't
     * seem to improve performance. Now just a stub.
     */
    private func cacheString(_ start: String.UnicodeScalarView.Index, _ end: String.UnicodeScalarView.Index) -> String {
        return String(input[start..<end])
    }
}

extension CharacterReader: CustomDebugStringConvertible {
    public var debugDescription: String {
        return  toString()
    }
}
