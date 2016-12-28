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
    public static let EOF: UnicodeScalar = "\u{FFFF}"//65535
    private static let maxCacheLen: Int = 12
    private let input: [UnicodeScalar]
    private let length: Int
    private var pos: Int = 0
    private var mark: Int = 0
    private let stringCache: Array<String?> // holds reused strings in this doc, to lessen garbage

    public init(_ input: String) {
        self.input = Array(input.unicodeScalars)
        self.length = self.input.count
        stringCache = Array(repeating:nil, count:512)
    }

    public func getPos() -> Int {
        return self.pos
    }

    public func isEmpty() -> Bool {
        return pos >= length
    }

    public func current() -> UnicodeScalar {
        return (pos >= length) ? CharacterReader.EOF : input[pos]
    }

    @discardableResult
    public func consume() -> UnicodeScalar {
        let val = (pos >= length) ? CharacterReader.EOF : input[pos]
        pos += 1
        return val
    }

    public func unconsume() {
        pos -= 1
    }

    public func advance() {
        pos += 1
    }

    public func markPos() {
        mark = pos
    }

    public func rewindToMark() {
        pos = mark
    }

    public func consumeAsString() -> String {
        let p = pos
        pos+=1
        return String(input[p])
        //return String(input, pos+=1, 1)
    }

    /**
     * Returns the number of characters between the current position and the next instance of the input char
     * @param c scan target
     * @return offset between current position and next instance of target. -1 if not found.
     */
    public func nextIndexOf(_ c: UnicodeScalar) -> Int {
        // doesn't handle scanning for surrogates
        for i in pos..<length {
            if (c == input[i]) {
                return i - pos
            }
        }
        return -1
    }

    /**
     * Returns the number of characters between the current position and the next instance of the input sequence
     *
     * @param seq scan target
     * @return offset between current position and next instance of target. -1 if not found.
     */
    public func nextIndexOf(_ seq: String) -> Int {
        // doesn't handle scanning for surrogates
		if(seq.isEmpty) {return -1}
        let startChar: UnicodeScalar = seq.unicodeScalar(0)
        for var offset in pos..<length {
            // scan to first instance of startchar:
            if (startChar != input[offset]) {
                offset+=1
                while(offset < length && startChar != input[offset]) { offset+=1 }
            }
            var i = offset + 1
            let last = i + seq.unicodeScalars.count-1
            if (offset < length && last <= length) {
                var j = 1
                while i < last && seq.unicodeScalar(j) == input[i] {
                    j+=1
                    i+=1
                }
                // found full sequence
                if (i == last) {
                    return offset - pos
                }
            }
        }
        return -1
    }

    public func consumeTo(_ c: UnicodeScalar) -> String {
        let offset = nextIndexOf(c)
        if (offset != -1) {
            let consumed = cacheString(pos, offset)
            pos += offset
            return consumed
        } else {
            return consumeToEnd()
        }
    }

    public func consumeTo(_ seq: String) -> String {
        let offset = nextIndexOf(seq)
        if (offset != -1) {
            let consumed = cacheString(pos, offset)
            pos += offset
            return consumed
        } else {
            return consumeToEnd()
        }
    }

    public func consumeToAny(_ chars: UnicodeScalar...) -> String {
        return consumeToAny(chars)
    }
    public func consumeToAny(_ chars: [UnicodeScalar]) -> String {
        let start: Int = pos
        let remaining: Int = length
        let val = input
		if(start == 2528) {
			let d = 1
			print(d)
		}
        OUTER: while (pos < remaining) {
			if(pos == 41708) {
				let d = 1
				print(d)
			}
			if chars.contains(val[pos]) {
				break OUTER
			}
//            for c in chars {
//                if (val[pos] == c){
//                    break OUTER
//                }
//            }
            pos += 1
        }

        return pos > start ? cacheString(start, pos-start) : ""
    }

    public func consumeToAnySorted(_ chars: UnicodeScalar...) -> String {
        return consumeToAnySorted(chars)
    }
    public func consumeToAnySorted(_ chars: [UnicodeScalar]) -> String {
        let start = pos
        let remaining = length
        let val = input

        while (pos < remaining) {
            if (chars.binarySearch(chars, val[pos]) >= 0) {
                break
            }
            pos += 1
        }

        return pos > start ? cacheString(start, pos-start) : ""
    }

    public func consumeData() -> String {
        // &, <, null
        let start = pos
        let remaining = length
        let val = input

        while (pos < remaining) {
            let c: UnicodeScalar = val[pos]
            if (c == "&" || c ==  "<" || c ==  TokeniserStateVars.nullScalr) {
                break
            }
            pos += 1
        }

        return pos > start ? cacheString(start, pos-start) : ""
    }

    public func consumeTagName() -> String {
        // '\t', '\n', '\r', '\f', ' ', '/', '>', nullChar
        let start = pos
        let remaining = length
        let val = input

        while (pos < remaining) {
            let c: UnicodeScalar = val[pos]
            if (c == "\t" || c ==  "\n" || c ==  "\r" || c ==  UnicodeScalar.BackslashF || c ==  " " || c ==  "/" || c ==  ">" || c ==  TokeniserStateVars.nullScalr) {
                break
            }
            pos += 1
        }
        return pos > start ? cacheString(start, pos-start) : ""
    }

    public func consumeToEnd() -> String {
        let data = cacheString(pos, length-pos)
        pos = length
        return data
    }

    public func consumeLetterSequence() -> String {
        let start = pos
        while (pos < length) {
            let c: UnicodeScalar = input[pos]
            if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(CharacterSet.letters)) {
                pos += 1
            } else {
                break
            }
        }
        return cacheString(start, pos - start)
    }

    public func consumeLetterThenDigitSequence() -> String {
        let start = pos
        while (pos < length) {
            let c = input[pos]
            if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(CharacterSet.letters)) {
                pos += 1
            } else {
                break
            }
        }
        while (!isEmpty()) {
            let c = input[pos]
            if (c >= "0" && c <= "9") {
                pos += 1
            } else {
                break
            }
        }

        return cacheString(start, pos - start)
    }

    public func consumeHexSequence() -> String {
        let start = pos
        while (pos < length) {
            let c = input[pos]
            if ((c >= "0" && c <= "9") || (c >= "A" && c <= "F") || (c >= "a" && c <= "f")) {
                pos+=1
            } else {
                break
            }
        }
        return cacheString(start, pos - start)
    }

    public func consumeDigitSequence() -> String {
        let start = pos
        while (pos < length) {
            let c = input[pos]
            if (c >= "0" && c <= "9") {
                pos+=1
            } else {
                break
            }
        }
        return cacheString(start, pos - start)
    }

    public func matches(_ c: UnicodeScalar) -> Bool {
        return !isEmpty() && input[pos] == c

    }

    public func matches(_ seq: String) -> Bool {
        let scanLength = seq.unicodeScalars.count
        if (scanLength > length - pos) {
            return false
        }

        for offset in 0..<scanLength {
            if (seq.unicodeScalar(offset) != input[pos+offset]) {
                return false
            }
        }
        return true
    }

    public func matchesIgnoreCase(_ seq: String ) -> Bool {

        let scanLength = seq.unicodeScalars.count
		if(scanLength == 0) {
			return false
		}
        if (scanLength > length - pos) {
            return false
        }

        for offset in 0..<scanLength {
            let upScan: UnicodeScalar = seq.unicodeScalar(offset).uppercase
            let upTarget: UnicodeScalar = input[pos+offset].uppercase
            if (upScan != upTarget) {
                return false
            }
        }
        return true
    }

    public func matchesAny(_ seq: UnicodeScalar...) -> Bool {
        if (isEmpty()) {
            return false
        }

        let c: UnicodeScalar = input[pos]
        for seek in seq {
            if (seek == c) {
                return true
            }
        }
        return false
    }

    public func matchesAnySorted(_ seq: [UnicodeScalar]) -> Bool {
        return !isEmpty() && seq.binarySearch(seq, input[pos]) >= 0
    }

    public func matchesLetter() -> Bool {
        if (isEmpty()) {
            return false
        }
        let c  = input[pos]
        return (c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(CharacterSet.letters)
    }

    public func matchesDigit() -> Bool {
        if (isEmpty()) {
            return false
        }
        let c  = input[pos]
        return (c >= "0" && c <= "9")
    }

    @discardableResult
    public func matchConsume(_ seq: String) -> Bool {
        if (matches(seq)) {
            pos += seq.unicodeScalars.count
            return true
        } else {
            return false
        }
    }

    @discardableResult
    public func matchConsumeIgnoreCase(_ seq: String) -> Bool {
        if (matchesIgnoreCase(seq)) {
            pos += seq.unicodeScalars.count
            return true
        } else {
            return false
        }
    }

    public func containsIgnoreCase(_ seq: String ) -> Bool {
        // used to check presence of </title>, </style>. only finds consistent case.
        let loScan = seq.lowercased(with: Locale(identifier: "en"))
        let hiScan = seq.uppercased(with: Locale(identifier: "eng"))
        return (nextIndexOf(loScan) > -1) || (nextIndexOf(hiScan) > -1)
    }

    public func toString() -> String {
		return String.unicodescalars(Array(input[pos..<length]))
        //return  input.string(pos, length - pos)
    }

    /**
     * Caches short strings, as a flywheel pattern, to reduce GC load. Just for this doc, to prevent leaks.
     * <p />
     * Simplistic, and on hash collisions just falls back to creating a new string, vs a full HashMap with Entry list.
     * That saves both having to create objects as hash keys, and running through the entry list, at the expense of
     * some more duplicates.
     */
    private func cacheString(_ start: Int, _ count: Int) -> String {
        let val = input
        var cache: [String?] = stringCache

        // limit (no cache):
        if (count > CharacterReader.maxCacheLen) {
            return String.unicodescalars(Array(val[start..<start+count]))
        }

        // calculate hash:
        var hash: Int = 0
        var offset = start
        for _ in 0..<count {
            let ch = val[offset].value
            hash = Int.addWithOverflow(Int.multiplyWithOverflow(31, hash).0, Int(ch)).0
            offset+=1
        }

        // get from cache
		hash = abs(hash)
		let i = hash % cache.count
        let index: Int = abs(i) //Int(hash & Int(cache.count) - 1)
        var cached = cache[index]

        if (cached == nil) { // miss, add
			cached = String.unicodescalars(Array(val[start..<start+count]))
            //cached = val.string(start, count)
            cache[Int(index)] = cached
        } else { // hashcode hit, check equality
            if (rangeEquals(start, count, cached!)) { // hit
                return cached!
            } else { // hashcode conflict
				cached = String.unicodescalars(Array(val[start..<start+count]))
                //cached = val.string(start, count)
                cache[index] = cached // update the cache, as recently used strings are more likely to show up again
            }
        }
        return cached!
    }

    /**
     * Check if the value of the provided range equals the string.
     */
    public func rangeEquals(_ start: Int, _ count: Int, _ cached: String) -> Bool {
        if (count == cached.unicodeScalars.count) {
            var count = count
            let one = input
            var i = start
            var j = 0
            while (count != 0) {
                count -= 1
                if (one[i] != cached.unicodeScalar(j) ) {
                    return false
                }
                j += 1
                i += 1
            }
            return true
        }
        return false
    }
}
