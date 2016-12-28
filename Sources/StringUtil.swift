//
//  StringUtil.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 20/04/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * A minimal String utility class. Designed for internal jsoup use only.
 */
open class StringUtil {
    enum StringError: Error {
        case empty
        case short
        case error(String)
    }

    // memoised padding up to 10
    fileprivate static var padding: [String] = ["", " ", "  ", "   ", "    ", "     ", "      ", "       ", "        ", "         ", "          "]

    /**
     * Join a collection of strings by a seperator
     * @param strings collection of string objects
     * @param sep string to place between strings
     * @return joined string
     */
    open static func join(_ strings: [String], sep: String) -> String {
        return strings.joined(separator: sep)
    }
    open static func join(_ strings: Set<String>, sep: String) -> String {
        return strings.joined(separator: sep)
    }

	open static func join(_ strings: OrderedSet<String>, sep: String) -> String {
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
    open static func padding(_ width: Int) -> String {

        if(width <= 0) {
            return ""
        }

        if (width < padding.count) {
            return padding[width]
        }

        var out: [Character] = [Character]()

        for _ in 0..<width {
            out.append(" ")
        }
        return String(out)
    }

    /**
     * Tests if a string is blank: null, emtpy, or only whitespace (" ", \r\n, \t, etc)
     * @param string string to test
     * @return if string is blank
     */
    open static func isBlank(_ string: String) -> Bool {
        if (string.characters.count == 0) {
            return true
        }

        for chr in string.characters {
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
    open static func isNumeric(_ string: String) -> Bool {
        if (string.characters.count == 0) {
            return false
        }

        for chr in string.characters {
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
    open static func isWhitespace(_ c: Character) -> Bool {
        //(c == " " || c == "\t" || c == "\n" || (c == "\f" ) || c == "\r")
        return c.isWhitespace
    }

    /**
     * Normalise the whitespace within this string; multiple spaces collapse to a single, and all whitespace characters
     * (e.g. newline, tab) convert to a simple space
     * @param string content to normalise
     * @return normalised string
     */
    open static func normaliseWhitespace(_ string: String) -> String {
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
    open static func appendNormalisedWhitespace(_ accum: StringBuilder, string: String, stripLeading: Bool ) {
        var lastWasWhite: Bool = false
        var reachedNonWhite: Bool  = false

        for c in string.characters {
            if (isWhitespace(c)) {
                if ((stripLeading && !reachedNonWhite) || lastWasWhite) {
                    continue
                }
                accum.append(" ")
                lastWasWhite = true
            } else {
                accum.appendCodePoint(c)
                lastWasWhite = false
                reachedNonWhite = true
            }
        }
    }

    open static func inString(_ needle: String?, haystack: String...) -> Bool {
        return inString(needle, haystack)
    }
    open static func inString(_ needle: String?, _ haystack: [String?]) -> Bool {
        if(needle == nil) {return false}
        for hay in haystack {
            if(hay != nil  && hay!.compare(needle!) == ComparisonResult.orderedSame) {
                return true
            }
        }
        return false
    }

    open static func inSorted(_ needle: String, haystack: [String]) -> Bool {
        return binarySearch(haystack, searchItem: needle) >= 0
    }

    open static func binarySearch<T: Comparable>(_ inputArr: Array<T>, searchItem: T) -> Int {
        var lowerIndex = 0
        var upperIndex = inputArr.count - 1

        while (true) {
            let currentIndex = (lowerIndex + upperIndex)/2
            if(inputArr[currentIndex] == searchItem) {
                return currentIndex
            } else if (lowerIndex > upperIndex) {
                return -1
            } else {
                if (inputArr[currentIndex] > searchItem) {
                    upperIndex = currentIndex - 1
                } else {
                    lowerIndex = currentIndex + 1
                }
            }
        }
    }

    /**
     * Create a new absolute URL, from a provided existing absolute URL and a relative URL component.
     * @param base the existing absolulte base URL
     * @param relUrl the relative URL to resolve. (If it's already absolute, it will be returned)
     * @return the resolved absolute URL
     * @throws MalformedURLException if an error occurred generating the URL
     */
    //NOTE: Not sure it work
    open static func resolve(_ base: URL, relUrl: String ) -> URL? {
        var base = base
        if(base.pathComponents.count == 0 && base.absoluteString.characters.last != "/" && !base.isFileURL) {
            base = base.appendingPathComponent("/", isDirectory: false)
        }
        let u =  URL(string: relUrl, relativeTo : base)
        return u
    }

    /**
     * Create a new absolute URL, from a provided existing absolute URL and a relative URL component.
     * @param baseUrl the existing absolute base URL
     * @param relUrl the relative URL to resolve. (If it's already absolute, it will be returned)
     * @return an absolute URL if one was able to be generated, or the empty string if not
     */
    open static func resolve(_ baseUrl: String, relUrl: String ) -> String {

        let base = URL(string: baseUrl)

        if(base == nil || base?.scheme == nil) {
            let abs = URL(string: relUrl)
			return abs != nil && abs?.scheme != nil ? abs!.absoluteURL.absoluteString : ""
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

            return ""
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
