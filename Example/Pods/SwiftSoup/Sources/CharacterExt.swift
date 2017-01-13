//
//  CharacterExt.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 08/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

private let uppercaseSet = CharacterSet.uppercaseLetters
private let lowercaseSet = CharacterSet.lowercaseLetters
private let alphaSet = CharacterSet.letters
private let alphaNumericSet = CharacterSet.alphanumerics
private let symbolSet = CharacterSet.symbols
private let digitSet = CharacterSet.decimalDigits

extension Character {

    public static let BackslashF: Character = Character(UnicodeScalar(12))

    //http://www.unicode.org/glossary/#supplementary_code_point
    public static let MIN_SUPPLEMENTARY_CODE_POINT: UInt32 = 0x010000

    /// The first `UnicodeScalar` of `self`.
    var unicodeScalar: UnicodeScalar {
        let unicodes = String(self).unicodeScalars
        return unicodes[unicodes.startIndex]
    }

    /// True for any space character, and the control characters \t, \n, \r, \f, \v.
    var isWhitespace: Bool {

        switch self {

        case " ", "\t", "\n", "\r", "\r\n", Character.BackslashF: return true

        case "\u{000B}", "\u{000C}": return true // Form Feed, vertical tab

        default: return false

        }

    }

    /// True for any Unicode space character, and the control characters \t, \n, \r, \f, \v.
    var isUnicodeSpace: Bool {

        switch self {

        case " ", "\t", "\n", "\r", "\r\n", Character.BackslashF: return true

        case "\u{000C}", "\u{000B}", "\u{0085}": return true // Form Feed, vertical tab, next line (nel)

        case "\u{00A0}", "\u{1680}", "\u{180E}": return true // No-break space, ogham space mark, mongolian vowel

        case "\u{2000}"..."\u{200D}": return true // En quad, em quad, en space, em space, three-per-em space, four-per-em space, six-per-em space, figure space, ponctuation space, thin space, hair space, zero width space, zero width non-joiner, zero width joiner.
        case "\u{2028}", "\u{2029}": return true // Line separator, paragraph separator.

        case "\u{202F}", "\u{205F}", "\u{2060}", "\u{3000}", "\u{FEFF}": return true // Narrow no-break space, medium mathematical space, word joiner, ideographic space, zero width no-break space.

        default: return false

        }

    }

    /// `true` if `self` normalized contains a single code unit that is in the categories of Uppercase and Titlecase Letters.
    var isUppercase: Bool {

        return isMemberOfCharacterSet(uppercaseSet)

    }

    /// `true` if `self` normalized contains a single code unit that is in the category of Lowercase Letters.
    var isLowercase: Bool {

        return isMemberOfCharacterSet(lowercaseSet)

    }

    /// `true` if `self` normalized contains a single code unit that is in the categories of Letters and Marks.
    var isAlpha: Bool {

        return isMemberOfCharacterSet(alphaSet)

    }

    /// `true` if `self` normalized contains a single code unit that is in th categories of Letters, Marks, and Numbers.
    var isAlphaNumeric: Bool {

        return isMemberOfCharacterSet(alphaNumericSet)

    }

    /// `true` if `self` normalized contains a single code unit that is in the category of Symbols. These characters include, for example, the dollar sign ($) and the plus (+) sign.
    var isSymbol: Bool {

        return isMemberOfCharacterSet(symbolSet)

    }

    /// `true` if `self` normalized contains a single code unit that is in the category of Decimal Numbers.
    var isDigit: Bool {

        return isMemberOfCharacterSet(digitSet)

    }

    /// `true` if `self` is an ASCII decimal digit, i.e. between "0" and "9".
    var isDecimalDigit: Bool {

        return "0123456789".characters.contains(self)

    }

    /// `true` if `self` is an ASCII hexadecimal digit, i.e. "0"..."9", "a"..."f", "A"..."F".
    var isHexadecimalDigit: Bool {

        return "01234567890abcdefABCDEF".characters.contains(self)

    }

    /// `true` if `self` is an ASCII octal digit, i.e. between '0' and '7'.
    var isOctalDigit: Bool {

        return "01234567".characters.contains(self)

    }

    /// Lowercase `self`.
    var lowercase: Character {

        let str = String(self).lowercased()
        return str[str.startIndex]

    }

	func isChar(inSet set: CharacterSet) -> Bool {
		var found = true
		for ch in String(self).utf16 {
			if !set.contains(UnicodeScalar(ch)!) { found = false }
		}
		return found
	}

    /// Uppercase `self`.
    var uppercase: Character {

        let str = String(self).uppercased()
        return str[str.startIndex]

    }

    /// Return `true` if `self` normalized contains a single code unit that is a member of the supplied character set.
    ///
    /// - parameter set: The `NSCharacterSet` used to test for membership.
    /// - returns: `true` if `self` normalized contains a single code unit that is a member of the supplied character set.
    func isMemberOfCharacterSet(_ set: CharacterSet) -> Bool {

        let normalized = String(self).precomposedStringWithCanonicalMapping
        let unicodes = normalized.unicodeScalars

        guard unicodes.count == 1 else { return false }
        return set.contains(UnicodeScalar(unicodes.first!.value)!)

    }

	static func convertFromIntegerLiteral(value: IntegerLiteralType) -> Character {
        return Character(UnicodeScalar(value)!)
    }

    func unicodeScalarCodePoint() -> UInt32 {
        return unicodeScalar.value
    }

    static func charCount(codePoint: UInt32) -> Int {
        return codePoint >= MIN_SUPPLEMENTARY_CODE_POINT ? 2 : 1
    }

    static func isLetter(_ char: Character) -> Bool {
        return char.isLetter()
    }
    func isLetter() -> Bool {
        return self.isMemberOfCharacterSet(CharacterSet.letters)
    }

    static func isLetterOrDigit(_ char: Character) -> Bool {
        return char.isLetterOrDigit()
    }
    func isLetterOrDigit() -> Bool {
        if(self.isLetter()) {return true}
        return self.isDigit
    }
}
