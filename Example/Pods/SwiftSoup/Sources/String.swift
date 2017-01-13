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
        return self[self.characters.index(self.startIndex, offsetBy: i)]
    }

	subscript (i: Int) -> String {
        return String(self[i] as Character)
    }

	func unicodeScalar(_ i: Int) -> UnicodeScalar {
		return self.unicodeScalars.prefix(i+1).last!
	}

	func string(_ offset: Int, _ count: Int) -> String {
		let truncStart = self.unicodeScalars.count-offset
		return String(self.unicodeScalars.suffix(truncStart).prefix(count))
	}

    static func split(_ value: String, _ offset: Int, _ count: Int) -> String {
        let start = value.index(value.startIndex, offsetBy: offset)
        let end = value.index(value.startIndex, offsetBy: count+offset)
        let range = start..<end
        return value.substring(with: range)
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
        if(offset > characters.count) {return -1}

        let maxIndex = self.characters.count - substring.characters.count
        if(maxIndex >= 0) {
            for index in offset...maxIndex {
                let rangeSubstring = self.characters.index(self.startIndex, offsetBy: index)..<self.characters.index(self.startIndex, offsetBy: index + substring.characters.count)
                if self.substring(with: rangeSubstring) == substring {
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
        return trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
    }

    func equalsIgnoreCase(string: String?) -> Bool {
		if(string == nil) {return false}
        return caseInsensitiveCompare(string!) == ComparisonResult.orderedSame
    }

    static func toHexString(n: Int) -> String {
        return String(format:"%2x", n)
    }

    func toCharArray() -> [Int] {
        return characters.flatMap {Int($0.unicodeScalar.value)}
    }

    func insert(string: String, ind: Int) -> String {
        return  String(self.characters.prefix(ind)) + string + String(self.characters.suffix(self.characters.count-ind))
    }

    func charAt(_ i: Int) -> Character {
        return self[i] as Character
    }

	func substring(_ beginIndex: Int) -> String {
        return String.split(self, beginIndex, self.characters.count-beginIndex)
    }

	func substring(_ beginIndex: Int, _ count: Int) -> String {
        return String.split(self, beginIndex, count)
    }

    func regionMatches(_ ignoreCase: Bool, _ selfOffset: Int, _ other: String, _ otherOffset: Int, _ length: Int ) -> Bool {
        if ((otherOffset < 0) || (selfOffset < 0)
            || (selfOffset > self.characters.count - length)
            || (otherOffset > other.characters.count - length)) {
            return false
        }

        for i in 0..<length {
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
        if ((offset < 0) || (offset > characters.count - input.characters.count)) {
            return false
        }
        for i in 0..<input.characters.count {
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

    func replaceAll(of pattern: String, with replacement: String, options: NCRegularExpression.Options = []) -> String {
        do {
            let regex = try NCRegularExpression(pattern: pattern, options: [])
            let range = NSRange(0..<self.utf16.count)
            return regex.stringByReplacingMatches(in: self, options: [],
                                                  range: range, withTemplate: replacement)
        } catch {
            NSLog("replaceAll error: \(error)")
            return self
        }
    }

    func equals(_ s: String?) -> Bool {
		if(s == nil) {return false}
        return self == s!
    }

	static func unicodescalars ( _ scalars: [UnicodeScalar]) -> String {
		return String(scalars.flatMap { Character($0) })
	}

}

extension String.Encoding {
	func canEncode(_ string: String) -> Bool {
		return  string.cString(using: self) != nil
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
}
