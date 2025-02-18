//
//  StringUtil.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 20/04/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

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
     * @param strings collection of string objects
     * @param sep string to place between strings
     * @return joined string
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
//     * @param strings iterator of string objects
//     * @param sep string to place between strings
//     * @return joined string
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
     * @param width amount of padding desired
     * @return string of spaces * width
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
     * Tests if a string is blank: null, emtpy, or only whitespace (" ", \r\n, \t, etc)
     * @param string string to test
     * @return if string is blank
     */
    public static func isBlank(_ string: String) -> Bool {
        if (string.count == 0) {
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
     * @param string string to test
     * @return true if only digit chars, false if empty or null or contains non-digit chrs
     */
    public static func isNumeric(_ string: String) -> Bool {
        if (string.count == 0) {
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
     * @param c code point to test
     * @return true if code point is whitespace, false otherwise
     */
    public static func isWhitespace(_ c: Character) -> Bool {
        //(c == " " || c == UnicodeScalar.BackslashT || c == "\n" || (c == "\f" ) || c == "\r")
        return c.isWhitespace
    }

    /**
     * Tests if a code point is "whitespace" as defined in the HTML spec.
     * @param c code point to test
     * @return true if code point is whitespace, false otherwise
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
     * @param string content to normalise
     * @return normalised string
     */
    public static func normaliseWhitespace(_ string: String) -> String {
        let sb: StringBuilder  = StringBuilder.init()
        appendNormalisedWhitespace(sb, string: string, stripLeading: false)
        return sb.toString()
    }
    
    /**
     * Normalise the whitespace within this string; multiple spaces collapse to a single, and all whitespace characters
     * (e.g. newline, tab) convert to a simple space
     * @param string content to normalise
     * @return normalised string
     */
    public static func normaliseWhitespace(_ string: [UInt8]) -> String {
        let sb: StringBuilder  = StringBuilder.init()
        appendNormalisedWhitespace(sb, string: string, stripLeading: false)
        return sb.toString()
    }

    /**
     * After normalizing the whitespace within a string, appends it to a string builder.
     * @param accum builder to append to
     * @param string string to normalize whitespace within
     * @param stripLeading set to true if you wish to remove any leading whitespace
     */
    public static func appendNormalisedWhitespace(_ accum: StringBuilder, string: String, stripLeading: Bool) {
        var lastWasWhite: Bool = false
        var reachedNonWhite: Bool  = false

        for c in string {
            if (isWhitespace(c)) {
                if ((stripLeading && !reachedNonWhite) || lastWasWhite) {
                    continue
                }
                accum.append(" ")
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
     * @param accum builder to append to
     * @param string string to normalize whitespace within
     * @param stripLeading set to true if you wish to remove any leading whitespace
     */
    public static func appendNormalisedWhitespace(_ accum: StringBuilder, string: [UInt8], stripLeading: Bool) {
        var lastWasWhite = false
        var reachedNonWhite = false
        var i = 0
        while i < string.count {
            // Determine the length of the current UTF-8 encoded scalar.
            let firstByte = string[i]
            let scalarByteCount: Int
            if firstByte < 0x80 {
                scalarByteCount = 1
            } else if firstByte < 0xE0 {
                scalarByteCount = 2
            } else if firstByte < 0xF0 {
                scalarByteCount = 3
            } else {
                scalarByteCount = 4
            }
            guard i + scalarByteCount <= string.count else { break }
            let scalarBytes = Array(string[i..<i+scalarByteCount])
            i += scalarByteCount
            
            if isWhitespace(scalarBytes) {
                if (stripLeading && !reachedNonWhite) || lastWasWhite {
                    continue
                }
                accum.append([UInt8](" ".utf8))
                lastWasWhite = true
            } else {
                accum.append(scalarBytes)
                lastWasWhite = false
                reachedNonWhite = true
            }
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
     * @param base the existing absolulte base URL
     * @param relUrl the relative URL to resolve. (If it's already absolute, it will be returned)
     * @return the resolved absolute URL
     * @throws MalformedURLException if an error occurred generating the URL
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
     * @param baseUrl the existing absolute base URL
     * @param relUrl the relative URL to resolve. (If it's already absolute, it will be returned)
     * @return an absolute URL if one was able to be generated, or the empty string if not
     */
    public static func resolve(_ baseUrl: String, relUrl: String ) -> String {

        let base = URL(string: baseUrl)

        if(base == nil || base?.scheme == nil) {
            let abs = URL(string: relUrl)
			return abs != nil && abs?.scheme != nil ? abs!.absoluteURL.absoluteString : empty
        } else {
            let url = resolve(base!, relUrl: relUrl)
            if(url != nil) {
                let ext = url!.absoluteURL.absoluteString
                return ext
            }

            if(base != nil && base?.scheme != nil) {
                let ext = base!.absoluteString
                return ext
            }

            return empty
        }

//        try {
//            try {
//                    base = new URL(baseUrl)
//                } catch (MalformedURLException e) {
//                        // the base is unsuitable, but the attribute/rel may be abs on its own, so try that
//                        URL abs = new URL(relUrl)
//                        return abs.toExternalForm()
//                }
//            return resolve(base, relUrl).toExternalForm()
//        } catch (MalformedURLException e) {
//            return ""
//        }

    }

}
