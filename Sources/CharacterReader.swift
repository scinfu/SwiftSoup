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
    private let input: Bytes
    private let length: Int
    private var pos: Int = 0
    private var mark: Int = 0
    //private let stringCache: Array<String?> // holds reused strings in this doc, to lessen garbage
    //let bytes: Bytes
    //var scanner: Scanner<Bytes>

    public init(_ input: String) {
        self.input = input.makeBytes()
        self.length = self.input.count
        //bytes = input.makeBytes()
        //scanner = Scanner(bytes)
        //stringCache = Array(repeating:nil, count:512)
        
    
    }

    public func getPos() -> Int {
        return self.pos
    }

    public func isEmpty() -> Bool {
        return pos >= length
    }

    public func current() -> Byte {
        return (pos >= length) ? Byte.EOF : input[pos]
    }

    @discardableResult
    public func consume() -> Byte {
        let val = (pos >= length) ? Byte.EOF : input[pos]
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

 
    /**
     * Returns the number of characters between the current position and the next instance of the input char
     * @param c scan target
     * @return offset between current position and next instance of target. -1 if not found.
     */
    public func nextIndexOf(_ c: Byte) -> Int {
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
        let seq = seq.makeBytes()
        // doesn't handle scanning for surrogates
		if(seq.isEmpty) {return -1}
        let startChar = seq[0]
        for var offset in pos..<length {
            // scan to first instance of startchar:
            if (startChar != input[offset]) {
                offset+=1
                while(offset < length && startChar != input[offset]) { offset+=1 }
            }
            var i = offset + 1
            let last = i + seq.count-1
            if (offset < length && last <= length) {
                var j = 1
                while i < last && seq[j] == input[i] {
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

    public func consumeTo(_ c: Byte) -> String {
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

    public func consumeToAny(_ chars: Byte...) -> String {
        return consumeToAny(chars)
    }
    public func consumeToAny(_ chars: [Byte]) -> String {
        let start: Int = pos
        let remaining: Int = length
        let val = input
        OUTER: while (pos < remaining) {
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

        return pos > start ? cacheString(start, pos-start) : CharacterReader.empty
    }

    public func consumeToAnySorted(_ chars: Byte...) -> String {
        return consumeToAnySorted(chars)
    }
    public func consumeToAnySorted(_ chars: [Byte]) -> String {
        let start = pos
        let remaining = length
        let val = input

        while (pos < remaining) {
            
            if chars.contains(val[pos]) {
                break
            }
            pos += 1
        }

        return pos > start ? cacheString(start, pos-start) : CharacterReader.empty
    }

    public func consumeData() -> String {
        // &, <, null
        let start = pos
        let remaining = length
        let val = input

        while (pos < remaining) {
            let c = val[pos]
            if (c == Byte.ampersand || c ==  Byte.lessThan || c ==  Byte.null) {
                break
            }
            pos += 1
        }

        return pos > start ? cacheString(start, pos-start) : CharacterReader.empty
    }

    public func consumeTagName() -> String {
        // '\t', '\n', '\r', '\f', ' ', '/', '>', nullChar
        let start = pos
        let remaining = length
        let val = input

        while (pos < remaining) {
            let c = val[pos]
            if (c == Byte.horizontalTab || c ==  Byte.newLine || c ==  Byte.carriageReturn || c ==  Byte.formfeed || c ==  Byte.space || c ==  Byte.forwardSlash || c ==  Byte.greaterThan || c ==  Byte.null) {
                break
            }
            pos += 1
        }
        return pos > start ? cacheString(start, pos-start) : CharacterReader.empty
    }

    public func consumeToEnd() -> String {
        let data = cacheString(pos, length-pos)
        pos = length
        return data
    }

    public func consumeLetterSequence() -> String {
        let start = pos
        while (pos < length) {
            let c = input[pos]
            if ((c >= Byte.A && c <= Byte.Z) || (c >= Byte.a && c <= Byte.z) || c.isLetter) {
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
            if ((c >= Byte.A && c <= Byte.Z) || (c >= Byte.a && c <= Byte.z) || c.isLetter) {
                pos += 1
            } else {
                break
            }
        }
        while (!isEmpty()) {
            let c = input[pos]
            if (c >= Byte.zero && c <= Byte.nine) {
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
            if ((c >= Byte.zero && c <= Byte.nine) || (c >= Byte.A && c <= Byte.F) || (c >= Byte.a && c <= Byte.f)) {
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
            if (c >= Byte.zero && c <= Byte.nine) {
                pos+=1
            } else {
                break
            }
        }
        return cacheString(start, pos - start)
    }

    public func matches(_ c: Byte) -> Bool {
        return !isEmpty() && input[pos] == c

    }

    public func matches(_ seq: Bytes) -> Bool {
        let scanLength = seq.count
        if (scanLength > length - pos) {
            return false
        }

        for offset in 0..<scanLength {
            if (seq[offset] != input[pos+offset]) {
                return false
            }
        }
        return true
    }

    public func matchesIgnoreCase(_ seq: String ) -> Bool {
        let seq = seq.makeBytes()
        let scanLength = seq.count
		if(scanLength == 0) {
			return false
		}
        if (scanLength > length - pos) {
            return false
        }

        for offset in 0..<scanLength {
            let upScan = seq[offset].uppercase
            let upTarget = input[pos+offset].uppercase
            if (upScan != upTarget) {
                return false
            }
        }
        return true
    }

    public func matchesAny(_ seq: Byte...) -> Bool {
        if (isEmpty()) {
            return false
        }

        let c = input[pos]
        for seek in seq {
            if (seek == c) {
                return true
            }
        }
        return false
    }

    public func matchesAnySorted(_ seq: [Byte]) -> Bool {
        return !isEmpty() && seq.contains(input[pos])
    }

    public func matchesLetter() -> Bool {
        if (isEmpty()) {
            return false
        }
        let c  = input[pos]
        return (c >= Byte.A && c <= Byte.Z) || (c >= Byte.a && c <= Byte.z) || c.isLetter
    }

    public func matchesDigit() -> Bool {
        if (isEmpty()) {
            return false
        }
        let c  = input[pos]
        return (c >= Byte.zero && c <= Byte.nine)
    }

    @discardableResult
    public func matchConsume(_ seq: Bytes) -> Bool {
        if (matches(seq)) {
            pos += seq.count
            return true
        } else {
            return false
        }
    }
    
    @discardableResult
    public func matchConsume(_ seq: Byte) -> Bool {
        if (matches(seq)) {
            pos += 1
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
    
    @discardableResult
    public func matchConsumeIgnoreCase(_ seq: Byte) -> Bool {
        if (containsIgnoreCase(seq)) {
            pos += 1
            return true
        } else {
            return false
        }
    }

    ///TODO: provare  RIMUOVERE
    public func containsIgnoreCase(_ seq: String ) -> Bool {
        // used to check presence of </title>, </style>. only finds consistent case.
        let loScan = seq.lowercased(with: Locale(identifier: "en"))
        let hiScan = seq.uppercased(with: Locale(identifier: "eng"))
        return (nextIndexOf(loScan) > -1) || (nextIndexOf(hiScan) > -1)
    }
    
    public func containsIgnoreCase(_ seq: Byte ) -> Bool {
        // used to check presence of </title>, </style>. only finds consistent case.
        return (nextIndexOf(seq.uppercase) > -1) || (nextIndexOf(seq.lowercase) > -1)
    }

    public func toString() -> String {
        return input[pos..<length].makeString()
    }

    /**
     * Caches short strings, as a flywheel pattern, to reduce GC load. Just for this doc, to prevent leaks.
     * <p />
     * Simplistic, and on hash collisions just falls back to creating a new string, vs a full HashMap with Entry list.
     * That saves both having to create objects as hash keys, and running through the entry list, at the expense of
     * some more duplicates.
     */
    private func cacheString(_ start: Int, _ count: Int) -> String {
        let ar = input[start..<start+count]
        return ar.makeString()
        //return String(input[start..<start+count].flatMap { Character($0) })
// Too Slow
//        var cache: [String?] = stringCache
//
//        // limit (no cache):
//        if (count > CharacterReader.maxCacheLen) {
//            return String(val[start..<start+count].flatMap { Character($0) })
//        }
//
//        // calculate hash:
//        var hash: Int = 0
//        var offset = start
//        for _ in 0..<count {
//            let ch = val[offset].value
//            hash = Int.addWithOverflow(Int.multiplyWithOverflow(31, hash).0, Int(ch)).0
//            offset+=1
//        }
//
//        // get from cache
//		hash = abs(hash)
//		let i = hash % cache.count
//        let index: Int = abs(i) //Int(hash & Int(cache.count) - 1)
//        var cached = cache[index]
//
//        if (cached == nil) { // miss, add
//			cached = String(val[start..<start+count].flatMap { Character($0) })
//            //cached = val.string(start, count)
//            cache[Int(index)] = cached
//        } else { // hashcode hit, check equality
//            if (rangeEquals(start, count, cached!)) { // hit
//                return cached!
//            } else { // hashcode conflict
//				cached = String(val[start..<start+count].flatMap { Character($0) })
//                //cached = val.string(start, count)
//                cache[index] = cached // update the cache, as recently used strings are more likely to show up again
//            }
//        }
//        return cached!
    }

//    /**
//     * Check if the value of the provided range equals the string.
//     */
//    public func rangeEquals(_ start: Int, _ count: Int, _ cached: String) -> Bool {
//        if (count == cached.unicodeScalars.count) {
//            var count = count
//            let one = input
//            var i = start
//            var j = 0
//            while (count != 0) {
//                count -= 1
//                if (one[i] != cached.unicodeScalar(j) ) {
//                    return false
//                }
//                j += 1
//                i += 1
//            }
//            return true
//        }
//        return false
//    }
}
