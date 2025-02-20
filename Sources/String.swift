//
//  String.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 21/04/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

extension String {

	subscript (i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: i)]
    }

	subscript (i: Int) -> String {
        return String(self[i] as Character)
    }

    init<S: Sequence>(_ ucs: S)where S.Iterator.Element == UnicodeScalar {
        var s = ""
        s.unicodeScalars.append(contentsOf: ucs)
        self = s
    }

	func unicodeScalar(_ i: Int) -> UnicodeScalar {
        let ix = unicodeScalars.index(unicodeScalars.startIndex, offsetBy: i)
		return unicodeScalars[ix]
    }

	func string(_ offset: Int, _ count: Int) -> String {
		let truncStart = self.unicodeScalars.count-offset
		return String(self.unicodeScalars.suffix(truncStart).prefix(count))
	}

    static func split(_ value: String, _ offset: Int, _ count: Int) -> String {
        let start = value.index(value.startIndex, offsetBy: offset)
        let end = value.index(value.startIndex, offsetBy: count+offset)
        #if swift(>=4)
        return String(value[start..<end])
        #else
        let range = start..<end
        return value.substring(with: range)
        #endif
    }

	func isEmptyOrWhitespace() -> Bool {

        if(self.isEmpty) {
            return true
        }
        return (self.trimmingCharacters(in: CharacterSet.whitespaces) == "")
    }

	func startsWith(_ string: String) -> Bool {
        return self.hasPrefix(string)
    }
    
	func indexOf(_ substring: String, _ offset: Int ) -> Int {
        if(offset > count) {return -1}

        let maxIndex = self.count - substring.count
        if(maxIndex >= 0) {
            for index in offset...maxIndex {
                let rangeSubstring = self.index(self.startIndex, offsetBy: index)..<self.index(self.startIndex, offsetBy: index + substring.count)
                #if swift(>=4)
                let selfSubstring = self[rangeSubstring]
                #else
                let selfSubstring = self.substring(with: rangeSubstring)
                #endif
                if selfSubstring == substring {
                    return index
                }
            }
        }
        return -1
    }

	func indexOf(_ substring: String) -> Int {
        return self.indexOf(substring, 0)
    }

    func trim() -> String {
        // trimmingCharacters() in the stdlib is not very efficiently
        // implemented, perhaps because it always creates a new string.
        // Avoid actually calling it if it's not needed.
        guard count > 0 else { return self }
        let (firstChar, lastChar) = (first!, last!)
        if firstChar.isWhitespace || lastChar.isWhitespace || firstChar == "\n" || lastChar == "\n" {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return self
    }

    func equalsIgnoreCase(string: String?) -> Bool {
        if let string = string {
            return caseInsensitiveCompare(string) == .orderedSame
        }
        return false
    }

    static func toHexString(n: Int) -> String {
        return String(format: "%2x", n)
    }

    func insert(string: String, ind: Int) -> String {
        return  String(self.prefix(ind)) + string + String(self.suffix(self.count-ind))
    }

    func charAt(_ i: Int) -> Character {
        return self[i] as Character
    }

	func substring(_ beginIndex: Int) -> String {
        return String.split(self, beginIndex, self.count-beginIndex)
    }

	func substring(_ beginIndex: Int, _ count: Int) -> String {
        return String.split(self, beginIndex, count)
    }

    func regionMatches(ignoreCase: Bool, selfOffset: Int,
                       other: String, otherOffset: Int, targetLength: Int ) -> Bool {
        if ((otherOffset < 0) || (selfOffset < 0)
            || (selfOffset > self.count - targetLength)
            || (otherOffset > other.count - targetLength)) {
            return false
        }

        for i in 0..<targetLength {
            let charSelf: Character = self[i+selfOffset]
            let charOther: Character = other[i+otherOffset]
            if(ignoreCase) {
                if(charSelf.lowercase != charOther.lowercase) {
                    return false
                }
            } else {
                if(charSelf != charOther) {
                    return false
                }
            }
        }
        return true
    }

    func startsWith(_ input: String, _ offset: Int) -> Bool {
        if ((offset < 0) || (offset > count - input.count)) {
            return false
        }
        for i in 0..<input.count {
            let charSelf: Character = self[i+offset]
            let charOther: Character = input[i]
            if(charSelf != charOther) {return false}
        }
        return true
    }

    func replaceFirst(of pattern: String, with replacement: String) -> String {
        if let range = self.range(of: pattern) {
            return self.replacingCharacters(in: range, with: replacement)
        } else {
            return self
        }
    }

    func replaceAll(of pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(0..<self.utf16.count)
            return regex.stringByReplacingMatches(in: self, options: [],
                                                  range: range, withTemplate: replacement)
        } catch {
            return self
        }
    }

    func equals(_ s: String?) -> Bool {
		if(s == nil) {return false}
        return self == s!
    }
}

extension String.Encoding {
    func canEncode(_ c: UnicodeScalar) -> Bool {
        switch self {
        case .ascii:
            return c.value < 0x80
        case .utf8:
            return c.value <= 0x10FFFF
            //return true // real is:!(Character.isLowSurrogate(c) || Character.isHighSurrogate(c)) - but already check above (?)
        case .utf16:
            return c.value <= 0x10FFFF
        default:
            return String(Character(c)).cString(using: self) != nil
        }
	}

    public func displayName() -> String {
        switch self {
            case String.Encoding.ascii: return "US-ASCII"
            case String.Encoding.nextstep: return "nextstep"
            case String.Encoding.japaneseEUC: return "EUC-JP"
            case String.Encoding.utf8: return "UTF-8"
            case String.Encoding.isoLatin1: return "csISOLatin1"
            case String.Encoding.symbol: return "MacSymbol"
            case String.Encoding.nonLossyASCII: return "nonLossyASCII"
            case String.Encoding.shiftJIS: return "shiftJIS"
            case String.Encoding.isoLatin2: return "csISOLatin2"
            case String.Encoding.unicode: return "unicode"
            case String.Encoding.windowsCP1251: return "windows-1251"
            case String.Encoding.windowsCP1252: return "windows-1252"
            case String.Encoding.windowsCP1253: return "windows-1253"
            case String.Encoding.windowsCP1254: return "windows-1254"
            case String.Encoding.windowsCP1250: return "windows-1250"
            case String.Encoding.iso2022JP: return "iso2022jp"
            case String.Encoding.macOSRoman: return "macOSRoman"
            case String.Encoding.utf16: return "UTF-16"
            case String.Encoding.utf16BigEndian: return "UTF-16BE"
            case String.Encoding.utf16LittleEndian: return "UTF-16LE"
            case String.Encoding.utf32: return "UTF-32"
            case String.Encoding.utf32BigEndian: return "UTF-32BE"
            case String.Encoding.utf32LittleEndian: return "UTF-32LE"
        default:
            return self.description
        }
    }

    /// Errors that are thrown when a ``String.Encoding`` fails to be represented as a MIME type.
    public enum EncodingMIMETypeError: Error, LocalizedError {
        /// There is no IANA equivalent of the provided string encoding.
        case noIANAEquivalent(String.Encoding)

        /// Returns a human-readable representation of this error.
        public var errorDescription: String? {
            switch self {
            case .noIANAEquivalent(let encoding):
                return String("There is no IANA equivalent for \(encoding)")
            }
        }
    }

    /// Returns the encoding as an equivalent IANA MIME name.
    ///
    /// - SeeAlso: https://www.iana.org/assignments/character-sets/character-sets.xhtml
    /// - Throws: EncodingMIMETypeError if there is no IANA-compatible MIME name.
    public func mimeName() throws -> String {
        switch self {
            case .ascii: return "US-ASCII"
            case .nextstep: throw EncodingMIMETypeError.noIANAEquivalent(self)
            case .japaneseEUC: return "EUC-JP"
            case .utf8: return "UTF-8"
            case .isoLatin1: return "csISOLatin1"
            case .symbol: throw EncodingMIMETypeError.noIANAEquivalent(self)
            case .nonLossyASCII: return "US-ASCII"
            case .shiftJIS: return "Shift_JIS"
            case .isoLatin2: return "csISOLatin2"
            case .windowsCP1251: return "windows-1251"
            case .windowsCP1252: return "windows-1252"
            case .windowsCP1253: return "windows-1253"
            case .windowsCP1254: return "windows-1254"
            case .windowsCP1250: return "windows-1250"
            case .iso2022JP: return "csISO2022JP"
            case .macOSRoman: throw EncodingMIMETypeError.noIANAEquivalent(self)
            case .utf16: return "UTF-16"
            case .utf16BigEndian: return "UTF-16BE"
            case .utf16LittleEndian: return "UTF-16LE"
            case .utf32: return "UTF-32"
            case .utf32BigEndian: return "UTF-32BE"
            case .utf32LittleEndian: return "UTF-32LE"
            default: throw EncodingMIMETypeError.noIANAEquivalent(self)
        }
    }
}
