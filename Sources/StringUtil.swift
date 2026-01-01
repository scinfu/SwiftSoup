//
//  StringUtil.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 20/04/16.
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Foundation

/**
 * A minimal String utility class. Designed for internal SwiftSoup use only.
 */
open class StringUtil {
    @inline(__always)
    static func isAscii(_ bytes: [UInt8]) -> Bool {
        for b in bytes where b >= 128 {
            return false
        }
        return true
    }

    @inline(__always)
    static func isAscii(_ bytes: ArraySlice<UInt8>) -> Bool {
        for b in bytes where b >= 128 {
            return false
        }
        return true
    }

    @inline(__always)
    static func hasPrefixIgnoreCaseAscii(_ bytes: [UInt8], _ prefix: [UInt8]) -> Bool {
        if prefix.count > bytes.count { return false }
        var i = 0
        while i < prefix.count {
            if Attributes.asciiLowercase(bytes[i]) != Attributes.asciiLowercase(prefix[i]) {
                return false
            }
            i &+= 1
        }
        return true
    }

    @inline(__always)
    static func hasPrefixLowercaseAscii(_ bytes: [UInt8], _ lowerPrefix: [UInt8]) -> Bool {
        if lowerPrefix.count > bytes.count { return false }
        var i = 0
        while i < lowerPrefix.count {
            if Attributes.asciiLowercase(bytes[i]) != lowerPrefix[i] {
                return false
            }
            i &+= 1
        }
        return true
    }

    @inline(__always)
    static func hasSuffixIgnoreCaseAscii(_ bytes: [UInt8], _ suffix: [UInt8]) -> Bool {
        if suffix.count > bytes.count { return false }
        let offset = bytes.count - suffix.count
        var i = 0
        while i < suffix.count {
            if Attributes.asciiLowercase(bytes[offset + i]) != Attributes.asciiLowercase(suffix[i]) {
                return false
            }
            i &+= 1
        }
        return true
    }

    @inline(__always)
    static func hasSuffixLowercaseAscii(_ bytes: [UInt8], _ lowerSuffix: [UInt8]) -> Bool {
        if lowerSuffix.count > bytes.count { return false }
        let offset = bytes.count - lowerSuffix.count
        var i = 0
        while i < lowerSuffix.count {
            if Attributes.asciiLowercase(bytes[offset + i]) != lowerSuffix[i] {
                return false
            }
            i &+= 1
        }
        return true
    }

    @inline(__always)
    static func containsIgnoreCaseAscii(_ bytes: [UInt8], _ needle: [UInt8]) -> Bool {
        let hayCount = bytes.count
        let needleCount = needle.count
        if needleCount == 0 { return true }
        if needleCount > hayCount { return false }
        let limit = hayCount - needleCount
        var i = 0
        while i <= limit {
            var j = 0
            while j < needleCount {
                if Attributes.asciiLowercase(bytes[i + j]) != Attributes.asciiLowercase(needle[j]) {
                    break
                }
                j &+= 1
            }
            if j == needleCount {
                return true
            }
            i &+= 1
        }
        return false
    }

    @inline(__always)
    static func containsLowercaseAscii(_ bytes: [UInt8], _ lowerNeedle: [UInt8]) -> Bool {
        let hayCount = bytes.count
        let needleCount = lowerNeedle.count
        if needleCount == 0 { return true }
        if needleCount > hayCount { return false }
        let limit = hayCount - needleCount
        var i = 0
        while i <= limit {
            var j = 0
            while j < needleCount {
                if Attributes.asciiLowercase(bytes[i + j]) != lowerNeedle[j] {
                    break
                }
                j &+= 1
            }
            if j == needleCount {
                return true
            }
            i &+= 1
        }
        return false
    }
    enum StringError: Error {
        case empty
        case short
        case error(String)
    }

    // memoised padding up to 10
    fileprivate static let padding: [String] = ["", " ", "  ", "   ", "    ", "     ", "      ", "       ", "        ", "         ", "          "]
    private static let empty = ""
    private static let space = " "

    public static let spaceUTF8: [UInt8] = " ".utf8Array
    public static let backslashTUTF8: [UInt8] = "\t".utf8Array
    public static let backslashNUTF8: [UInt8] = "\n".utf8Array
    public static let backslashFUTF8: [UInt8] = "\u{000C}".utf8Array
    public static let backslashRUTF8: [UInt8] = "\r".utf8Array
    public static let backshashRBackslashNUTF8: [UInt8] = "\r\n".utf8Array
    @usableFromInline
    static let utf8NBSPLead: UInt8 = 0xC2
    @usableFromInline
    static let utf8NBSPTrail: UInt8 = 0xA0
    @usableFromInline
    static let utf8Lead3Min: UInt8 = 0xE0
    @usableFromInline
    static let utf8Lead4Min: UInt8 = 0xF0
    @usableFromInline
    static func isAsciiWhitespaceByte(_ byte: UInt8) -> Bool {
        return byte == TokeniserStateVars.spaceByte ||
            byte == TokeniserStateVars.tabByte ||
            byte == TokeniserStateVars.newLineByte ||
            byte == TokeniserStateVars.formFeedByte ||
            byte == TokeniserStateVars.carriageReturnByte
    }

    
    /**
     * Join a collection of strings by a seperator
     * - parameter strings: collection of string objects
     * - parameter sep: string to place between strings
     * - returns: joined string
     */
    public static func join(_ strings: [String], sep: String) -> String {
        return strings.joined(separator: sep)
    }
    public static func join(_ strings: Set<String>, sep: String) -> String {
        return strings.joined(separator: sep)
    }

    public static func join(_ strings: OrderedSet<String>, sep: String) -> String {
		return strings.joined(separator: sep)
	}

//    /**
//     * Join a collection of strings by a seperator
//     * - parameter strings: iterator of string objects
//     * - parameter sep: string to place between strings
//     * - returns: joined string
//     */
//    public static String join(Iterator strings, String sep) {
//    if (!strings.hasNext())
//    return ""
//    
//    String start = strings.next().toString()
//    if (!strings.hasNext()) // only one, avoid builder
//    return start
//    
//    StringBuilder sb = new StringBuilder(64).append(start)
//    while (strings.hasNext()) {
//    sb.append(sep)
//    sb.append(strings.next())
//    }
//    return sb.toString()
//    }
    /**
     * Returns space padding
     * - parameter width: amount of padding desired
     * - returns: string of spaces * width
     */
    public static func padding(_ width: Int) -> String {

        if width <= 0 {
            return empty
        }

        if width < padding.count {
            return padding[width]
        }
        
        return String.init(repeating: space, count: width)
    }

    /**
     * Tests if a string is blank: emtpy, or only whitespace (" ", \r\n, \t, etc)
     * - parameter string: string to test
     * - returns: if string is blank
     */
    public static func isBlank(_ string: String) -> Bool {
        if (string.isEmpty) {
            return true
        }

        for chr in string {
            if (!StringUtil.isWhitespace(chr)) {
                return false
            }
        }
        return true
    }

    /**
     * Tests if a string is numeric, i.e. contains only digit characters
     * - parameter string: string to test
     * - returns: true if only digit chars, false if empty or contains non-digit chrs
     */
    public static func isNumeric(_ string: String) -> Bool {
        if (string.isEmpty) {
            return false
        }

        for chr in string {
            if !("0"..."9" ~= chr) {
                return false
            }
        }
        return true
    }

    /**
     * Tests if a code point is "whitespace" as defined in the HTML spec.
     * - parameter c: code point to test
     * - returns: true if code point is whitespace, false otherwise
     */
    public static func isWhitespace(_ c: Character) -> Bool {
        //(c == " " || c == UnicodeScalar.BackslashT || c == "\n" || (c == "\f" ) || c == "\r")
        return c.isWhitespace
    }

    /**
     * Tests if a code point is "whitespace" as defined in the HTML spec.
     * - parameter bytes: code point to test
     * - returns: true if code point is whitespace, false otherwise
     */
    @inlinable
    public static func isWhitespace(_ bytes: [UInt8]) -> Bool {
        return bytes == Self.spaceUTF8 ||
        bytes == Self.backslashTUTF8 ||
        bytes == Self.backslashNUTF8 ||
        bytes == Self.backslashFUTF8 ||
        bytes == Self.backslashRUTF8 ||
        bytes == Self.backshashRBackslashNUTF8
    }
    
    /**
     * Normalise the whitespace within this string; multiple spaces collapse to a single, and all whitespace characters
     * (e.g. newline, tab) convert to a simple space
     * - parameter string: content to normalise
     * - returns: normalised string
     */
    public static func normaliseWhitespace(_ string: String) -> String {
        let sb: StringBuilder  = StringBuilder.init()
        appendNormalisedWhitespace(sb, string: string, stripLeading: false)
        return sb.toString()
    }
    
    /**
     * Normalise the whitespace within this string; multiple spaces collapse to a single, and all whitespace characters
     * (e.g. newline, tab) convert to a simple space
     * - parameter string: content to normalise
     * - returns: normalised string
     */
    public static func normaliseWhitespace(_ string: [UInt8]) -> String {
        if !needsWhitespaceNormalization(string) {
            return String(decoding: string, as: UTF8.self)
        }
        let sb: StringBuilder = StringBuilder(string.count)
        appendNormalisedWhitespace(sb, string: string, stripLeading: false)
        return sb.toString()
    }

    public static func normaliseWhitespace(_ string: ArraySlice<UInt8>) -> String {
        if !needsWhitespaceNormalization(string) {
            return String(decoding: string, as: UTF8.self)
        }
        let sb: StringBuilder = StringBuilder(string.count)
        appendNormalisedWhitespace(sb, string: string, stripLeading: false)
        return sb.toString()
    }

    /**
     * After normalizing the whitespace within a string, appends it to a string builder.
     * - parameter accum: builder to append to
     * - parameter string: string to normalize whitespace within
     * - parameter stripLeading: set to true if you wish to remove any leading whitespace
     */
    public static func appendNormalisedWhitespace(_ accum: StringBuilder, string: String, stripLeading: Bool) {
        var lastWasWhite: Bool = false
        var reachedNonWhite: Bool  = false

        for c in string {
            if (isWhitespace(c)) {
                if ((stripLeading && !reachedNonWhite) || lastWasWhite) {
                    continue
                }
                accum.append(TokeniserStateVars.spaceByte)
                lastWasWhite = true
            } else {
                accum.append(c)
                lastWasWhite = false
                reachedNonWhite = true
            }
        }
    }

    /**
     * After normalizing the whitespace within a string, appends it to a string builder.
     * - parameter accum: builder to append to
     * - parameter string: string to normalize whitespace within
     * - parameter stripLeading: set to true if you wish to remove any leading whitespace
     */
    public static func appendNormalisedWhitespace(_ accum: StringBuilder, string: [UInt8], stripLeading: Bool) {
        var lastWasWhite = false
        var reachedNonWhite = false
        var i = 0
        while i < string.count {
            let firstByte = string[i]
            if firstByte < TokeniserStateVars.asciiUpperLimitByte {
                if isAsciiWhitespaceByte(firstByte) {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i += 1
                        continue
                    }
                    accum.append(TokeniserStateVars.spaceByte)
                    lastWasWhite = true
                } else {
                    accum.append(firstByte)
                    lastWasWhite = false
                    reachedNonWhite = true
                }
                i += 1
                continue
            }
            if firstByte == utf8NBSPLead, i + 1 < string.count, string[i + 1] == utf8NBSPTrail {
                if (stripLeading && !reachedNonWhite) || lastWasWhite {
                    i += 2
                    continue
                }
                accum.append(TokeniserStateVars.spaceByte)
                lastWasWhite = true
                i += 2
                continue
            }
            // Non-ASCII scalar, append as-is.
            let scalarByteCount: Int
            if firstByte < utf8Lead3Min {
                scalarByteCount = 2
            } else if firstByte < utf8Lead4Min {
                scalarByteCount = 3
            } else {
                scalarByteCount = 4
            }
            let end = i + scalarByteCount
            guard end <= string.count else { break }
            accum.append(string[i..<end])
            lastWasWhite = false
            reachedNonWhite = true
            i = end
        }
    }

    @inline(__always)
    private static func needsWhitespaceNormalization(_ string: [UInt8]) -> Bool {
        var lastWasWhitespace = false
        var i = 0
        while i < string.count {
            let byte = string[i]
            if byte == TokeniserStateVars.spaceByte ||
                byte == TokeniserStateVars.tabByte ||
                byte == TokeniserStateVars.newLineByte ||
                byte == TokeniserStateVars.formFeedByte ||
                byte == TokeniserStateVars.carriageReturnByte {
                if byte != TokeniserStateVars.spaceByte || lastWasWhitespace {
                    return true
                }
                lastWasWhitespace = true
            } else {
                lastWasWhitespace = false
            }
            i &+= 1
        }
        return false
    }

    @inline(__always)
    private static func needsWhitespaceNormalization(_ string: ArraySlice<UInt8>) -> Bool {
        var lastWasWhitespace = false
        var i = string.startIndex
        let end = string.endIndex
        while i < end {
            let byte = string[i]
            if byte == TokeniserStateVars.spaceByte ||
                byte == TokeniserStateVars.tabByte ||
                byte == TokeniserStateVars.newLineByte ||
                byte == TokeniserStateVars.formFeedByte ||
                byte == TokeniserStateVars.carriageReturnByte {
                if byte != TokeniserStateVars.spaceByte || lastWasWhitespace {
                    return true
                }
                lastWasWhitespace = true
            } else {
                lastWasWhitespace = false
            }
            i = string.index(after: i)
        }
        return false
    }

    

    @inlinable
    public static func appendNormalisedWhitespace(_ accum: StringBuilder, string: ArraySlice<UInt8>, stripLeading: Bool) {
        if !string.isEmpty {
            var skipProbe = false
            let count = string.count
            if count <= 64 {
                var hasWhitespace = false
                var asciiOnly = true
                for b in string {
                    if b >= TokeniserStateVars.asciiUpperLimitByte {
                        asciiOnly = false
                        break
                    }
                    if isAsciiWhitespaceByte(b) {
                        hasWhitespace = true
                        break
                    }
                }
                if asciiOnly && !hasWhitespace {
                    accum.append(string)
                    return
                }
                if asciiOnly && hasWhitespace {
                    skipProbe = true
                }
            }
            #if canImport(Darwin) || canImport(Glibc)
            if !skipProbe {
                let hasWhitespace = string.withUnsafeBytes { buf -> Bool in
                    guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                        return false
                    }
                    return memchr(basePtr, Int32(TokeniserStateVars.spaceByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.tabByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.newLineByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.formFeedByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.carriageReturnByte), count) != nil ||
                        memchr(basePtr, Int32(utf8NBSPTrail), count) != nil ||
                        memchr(basePtr, Int32(utf8NBSPLead), count) != nil
                }
                if !hasWhitespace {
                    accum.append(string)
                    return
                }
            }
            #else
            var hasWhitespace = false
            for b in string {
                if b == TokeniserStateVars.spaceByte ||
                    (b >= TokeniserStateVars.tabByte && b <= TokeniserStateVars.carriageReturnByte) {
                    hasWhitespace = true
                    break
                }
            }
            if !hasWhitespace {
                accum.append(string)
                return
            }
            #endif
        }
        var lastWasWhite = false
        if OptimizationFlags.usePointerWhitespaceNormalize {
            var reachedNonWhite = false
            string.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else { return }
                let count = buf.count
                var i = 0
                while i < count {
                    let firstByte = basePtr[i]
                    if firstByte < TokeniserStateVars.asciiUpperLimitByte {
                        if isAsciiWhitespaceByte(firstByte) {
                            if (stripLeading && !reachedNonWhite) || lastWasWhite {
                                i &+= 1
                                continue
                            }
                            accum.append(TokeniserStateVars.spaceByte)
                            lastWasWhite = true
                            i &+= 1
                            continue
                        }
                        var j = i &+ 1
                        while j < count {
                            let b = basePtr[j]
                            if b >= TokeniserStateVars.asciiUpperLimitByte || isAsciiWhitespaceByte(b) {
                                break
                            }
                            j &+= 1
                        }
                        accum.write(contentsOf: basePtr.advanced(by: i), count: j - i)
                        lastWasWhite = false
                        reachedNonWhite = true
                        i = j
                        continue
                    }
                    if firstByte == utf8NBSPLead {
                        let next = i &+ 1
                        if next < count, basePtr[next] == utf8NBSPTrail {
                            if (stripLeading && !reachedNonWhite) || lastWasWhite {
                                i = next &+ 1
                                continue
                            }
                            accum.append(TokeniserStateVars.spaceByte)
                            lastWasWhite = true
                            i = next &+ 1
                            continue
                        }
                    }
                    let scalarByteCount: Int
                    if firstByte < utf8Lead3Min {
                        scalarByteCount = 2
                    } else if firstByte < utf8Lead4Min {
                        scalarByteCount = 3
                    } else {
                        scalarByteCount = 4
                    }
                    let next = i &+ scalarByteCount
                    if next > count { return }
                    accum.write(contentsOf: basePtr.advanced(by: i), count: scalarByteCount)
                    lastWasWhite = false
                    reachedNonWhite = true
                    i = next
                }
            }
        } else {
            var reachedNonWhite = false
            var i = string.startIndex
            let end = string.endIndex
            while i < end {
                let firstByte = string[i]
                if firstByte < TokeniserStateVars.asciiUpperLimitByte {
                    if isAsciiWhitespaceByte(firstByte) {
                        if (stripLeading && !reachedNonWhite) || lastWasWhite {
                            i = string.index(after: i)
                            continue
                        }
                        accum.append(TokeniserStateVars.spaceByte)
                        lastWasWhite = true
                    } else {
                        var j = i
                        while j < end {
                            let b = string[j]
                            if b >= TokeniserStateVars.asciiUpperLimitByte || isAsciiWhitespaceByte(b) {
                                break
                            }
                            j = string.index(after: j)
                        }
                        accum.append(string[i..<j])
                        lastWasWhite = false
                        reachedNonWhite = true
                        i = j
                        continue
                    }
                    i = string.index(after: i)
                    continue
                }
                if firstByte == utf8NBSPLead {
                    let next = string.index(after: i)
                    if next < end, string[next] == utf8NBSPTrail {
                        if (stripLeading && !reachedNonWhite) || lastWasWhite {
                            i = string.index(after: next)
                            continue
                        }
                        accum.append(TokeniserStateVars.spaceByte)
                        lastWasWhite = true
                        i = string.index(after: next)
                        continue
                    }
                }
                let scalarByteCount: Int
                if firstByte < utf8Lead3Min {
                    scalarByteCount = 2
                } else if firstByte < utf8Lead4Min {
                    scalarByteCount = 3
                } else {
                    scalarByteCount = 4
                }
                var next = i
                for _ in 0..<scalarByteCount {
                    if next == end { return }
                    next = string.index(after: next)
                }
                accum.append(string[i..<next])
                lastWasWhite = false
                reachedNonWhite = true
                i = next
            }
        }
    }

    @inlinable
    public static func appendNormalisedWhitespace(_ accum: StringBuilder,
                                                  string: ArraySlice<UInt8>,
                                                  stripLeading: Bool,
                                                  lastWasWhite: inout Bool) {
        if !string.isEmpty {
            // Fast path for ASCII slices that only contain single spaces (no tabs/newlines/NBSP, no doubles).
            var previousWasSpace = false
            var asciiOnlySingleSpace = true
            var i = string.startIndex
            let end = string.endIndex
            while i < end {
                let b = string[i]
                if b >= TokeniserStateVars.asciiUpperLimitByte {
                    asciiOnlySingleSpace = false
                    break
                }
                if b == TokeniserStateVars.spaceByte {
                    if previousWasSpace {
                        asciiOnlySingleSpace = false
                        break
                    }
                    previousWasSpace = true
                } else if b == TokeniserStateVars.tabByte ||
                            b == TokeniserStateVars.newLineByte ||
                            b == TokeniserStateVars.formFeedByte ||
                            b == TokeniserStateVars.carriageReturnByte {
                    asciiOnlySingleSpace = false
                    break
                } else {
                    previousWasSpace = false
                }
                i = string.index(after: i)
            }
            if asciiOnlySingleSpace {
                var start = string.startIndex
                if (stripLeading || lastWasWhite) && string[start] == TokeniserStateVars.spaceByte {
                    start = string.index(after: start)
                    if start == end {
                        return
                    }
                }
                accum.append(string[start..<end])
                if let last = string.last {
                    lastWasWhite = (last == TokeniserStateVars.spaceByte)
                }
                return
            }
        }
        if !string.isEmpty {
            var skipProbe = false
            let count = string.count
            if count <= 64 {
                var hasWhitespace = false
                var asciiOnly = true
                for b in string {
                    if b >= TokeniserStateVars.asciiUpperLimitByte {
                        asciiOnly = false
                        break
                    }
                    if isAsciiWhitespaceByte(b) {
                        hasWhitespace = true
                        break
                    }
                }
                if asciiOnly && !hasWhitespace {
                    accum.append(string)
                    if let last = string.last {
                        lastWasWhite = (last == TokeniserStateVars.spaceByte)
                    }
                    return
                }
                if asciiOnly && hasWhitespace {
                    skipProbe = true
                }
            }
            #if canImport(Darwin) || canImport(Glibc)
            if !skipProbe {
                let hasWhitespace = string.withUnsafeBytes { buf -> Bool in
                    guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                        return false
                    }
                    return memchr(basePtr, Int32(TokeniserStateVars.spaceByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.tabByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.newLineByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.formFeedByte), count) != nil ||
                        memchr(basePtr, Int32(TokeniserStateVars.carriageReturnByte), count) != nil ||
                        memchr(basePtr, Int32(utf8NBSPTrail), count) != nil ||
                        memchr(basePtr, Int32(utf8NBSPLead), count) != nil
                }
                if !hasWhitespace {
                    accum.append(string)
                    if let last = string.last {
                        lastWasWhite = (last == TokeniserStateVars.spaceByte)
                    }
                    return
                }
            }
            #else
            var hasWhitespace = false
            for b in string {
                if b == TokeniserStateVars.spaceByte ||
                    (b >= TokeniserStateVars.tabByte && b <= TokeniserStateVars.carriageReturnByte) {
                    hasWhitespace = true
                    break
                }
            }
            if !hasWhitespace {
                accum.append(string)
                if let last = string.last {
                    lastWasWhite = (last == TokeniserStateVars.spaceByte)
                }
                return
            }
            #endif
        }
        var reachedNonWhite = false
        var i = string.startIndex
        let end = string.endIndex
        while i < end {
            let firstByte = string[i]
            if firstByte < TokeniserStateVars.asciiUpperLimitByte {
                if isAsciiWhitespaceByte(firstByte) {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i = string.index(after: i)
                        continue
                    }
                    accum.append(TokeniserStateVars.spaceByte)
                    lastWasWhite = true
                } else {
                    var j = i
                    while j < end {
                        let b = string[j]
                        if b >= TokeniserStateVars.asciiUpperLimitByte || isAsciiWhitespaceByte(b) {
                            break
                        }
                        j = string.index(after: j)
                    }
                    accum.append(string[i..<j])
                    lastWasWhite = false
                    reachedNonWhite = true
                    i = j
                    continue
                }
                i = string.index(after: i)
                continue
            }
            if firstByte == utf8NBSPLead {
                let next = string.index(after: i)
                if next < end, string[next] == utf8NBSPTrail {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i = string.index(after: next)
                        continue
                    }
                    accum.append(TokeniserStateVars.spaceByte)
                    lastWasWhite = true
                    i = string.index(after: next)
                    continue
                }
            }
            let scalarByteCount: Int
            if firstByte < utf8Lead3Min {
                scalarByteCount = 2
            } else if firstByte < utf8Lead4Min {
                scalarByteCount = 3
            } else {
                scalarByteCount = 4
            }
            var next = i
            for _ in 0..<scalarByteCount {
                if next == end { return }
                next = string.index(after: next)
            }
            accum.append(string[i..<next])
            lastWasWhite = false
            reachedNonWhite = true
            i = next
        }
    }


//    open static func inSorted(_ needle: String, haystack: [String]) -> Bool {
//        return binarySearch(haystack, searchItem: needle) >= 0
//    }
//
//    open static func binarySearch<T: Comparable>(_ inputArr: Array<T>, searchItem: T) -> Int {
//        var lowerIndex = 0
//        var upperIndex = inputArr.count - 1
//
//        while (true) {
//            let currentIndex = (lowerIndex + upperIndex)/2
//            if(inputArr[currentIndex] == searchItem) {
//                return currentIndex
//            } else if (lowerIndex > upperIndex) {
//                return -1
//            } else {
//                if (inputArr[currentIndex] > searchItem) {
//                    upperIndex = currentIndex - 1
//                } else {
//                    lowerIndex = currentIndex + 1
//                }
//            }
//        }
//    }

    /**
     * Create a new absolute URL, from a provided existing absolute URL and a relative URL component.
     * - parameter base: the existing absolulte base URL
     * - parameter relUrl: the relative URL to resolve. (If it's already absolute, it will be returned)
     * - returns: the resolved absolute URL
     */
    //NOTE: Not sure it work
    public static func resolve(_ base: URL, relUrl: String) -> URL? {
        var base = base
        if (base.pathComponents.isEmpty && base.absoluteString.last != "/" && !base.isFileURL) {
            base = base.appendingPathComponent("/", isDirectory: false)
        }
        let u =  URL(string: relUrl, relativeTo: base)
        return u
    }

    /**
     * Create a new absolute URL, from a provided existing absolute URL and a relative URL component.
     * - parameter baseUrl: the existing absolute base URL
     * - parameter relUrl: the relative URL to resolve. (If it's already absolute, it will be returned)
     * - returns: an absolute URL if one was able to be generated, or the empty string if not
     */
    public static func resolve(_ baseUrl: String, relUrl: String ) -> String {
        let base = URL(string: baseUrl)
        
        if base == nil || base?.scheme == nil {
            let abs = urlFromString(relUrl)
            return abs != nil && abs?.scheme != nil ? abs!.absoluteURL.absoluteString : empty
        } else {
            if let url = resolve(base!, relUrl: relUrl) {
                return url.absoluteURL.absoluteString
            }
            
            if base?.scheme != nil {
                return base!.absoluteString
            }
            
            return empty
        }
    }
    
    
    private static func urlFromString(_ input: String) -> URL? {
        // Works around escaping issues in Apple's URL string parsing. As soon as there's one invalid character
        // in a query, _all_ characters get escaped. This results in `abc%20def[` to get encoded as `abc%2520def%5B`,
        // thus double-escaping the space `%20`.
        //
        // For details see https://github.com/scinfu/SwiftSoup/issues/268
        
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        // On Apple platforms, simply go with CFURL's parsing which doesn't do the double-escaping (it still escapes
        // the `[` and `]` in queries, though).
        return CFURLCreateWithString(nil, input as CFString, nil) as URL?
#else
        // On non-Apple platforms use a more manual approach using URL components.
        guard let queryIndex = input.firstIndex(of: "?") else {
            return URL(string: input)
        }
        
        guard var components = URLComponents(string: String(input.prefix(upTo: queryIndex))) else {
            return nil
        }
        
        // The `.query` property escapes/unescapes. So we first need to manually un-escape.
        let rawQuery = String(input.suffix(from: input.index(after: queryIndex)))
        let unescapedQuery = rawQuery.removingPercentEncoding
        components.query = unescapedQuery ?? rawQuery
        return components.url
#endif
    }

}
