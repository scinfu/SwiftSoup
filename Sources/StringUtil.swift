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
        let sb: StringBuilder  = StringBuilder.init()
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
                accum.append(UTF8Arrays.whitespace)
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
            if firstByte < 0x80 {
                if firstByte == 0x20 || firstByte == 0x09 || firstByte == 0x0A || firstByte == 0x0C || firstByte == 0x0D {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i += 1
                        continue
                    }
                    accum.append(UTF8Arrays.whitespace)
                    lastWasWhite = true
                } else {
                    accum.append(firstByte)
                    lastWasWhite = false
                    reachedNonWhite = true
                }
                i += 1
                continue
            }
            // Non-ASCII scalar, append as-is.
            let scalarByteCount: Int
            if firstByte < 0xE0 {
                scalarByteCount = 2
            } else if firstByte < 0xF0 {
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

    @inlinable
    public static func appendNormalisedWhitespace(_ accum: StringBuilder, string: ArraySlice<UInt8>, stripLeading: Bool) {
        if !string.isEmpty {
            #if canImport(Darwin) || canImport(Glibc)
            let count = string.count
            let hasWhitespace = string.withUnsafeBytes { buf -> Bool in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return false
                }
                return memchr(basePtr, 0x20, count) != nil ||
                    memchr(basePtr, 0x09, count) != nil ||
                    memchr(basePtr, 0x0A, count) != nil ||
                    memchr(basePtr, 0x0C, count) != nil ||
                    memchr(basePtr, 0x0D, count) != nil
            }
            if !hasWhitespace {
                accum.append(string)
                return
            }
            #else
            var hasWhitespace = false
            for b in string {
                if b == 0x20 || (b >= 0x09 && b <= 0x0D) {
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
        var reachedNonWhite = false
        var i = string.startIndex
        let end = string.endIndex
        while i < end {
            let firstByte = string[i]
            if firstByte < 0x80 {
                if firstByte == 0x20 || firstByte == 0x09 || firstByte == 0x0A || firstByte == 0x0C || firstByte == 0x0D {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i = string.index(after: i)
                        continue
                    }
                    accum.append(UTF8Arrays.whitespace)
                    lastWasWhite = true
                } else {
                    accum.append(firstByte)
                    lastWasWhite = false
                    reachedNonWhite = true
                }
                i = string.index(after: i)
                continue
            }
            let scalarByteCount: Int
            if firstByte < 0xE0 {
                scalarByteCount = 2
            } else if firstByte < 0xF0 {
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
