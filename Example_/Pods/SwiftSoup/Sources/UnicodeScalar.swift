//
//  UnicodeScalar.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/11/16.
//  Copyright © 2016 Nabil Chatbi. All rights reserved.
//

import Foundation

private let uppercaseSet = CharacterSet.uppercaseLetters
private let lowercaseSet = CharacterSet.lowercaseLetters
private let alphaSet = CharacterSet.letters
private let alphaNumericSet = CharacterSet.alphanumerics
private let symbolSet = CharacterSet.symbols
private let digitSet = CharacterSet.decimalDigits

extension UnicodeScalar {
	public static let BackslashF: UnicodeScalar = UnicodeScalar(12)

	func isMemberOfCharacterSet(_ set: CharacterSet) -> Bool {
		return set.contains(self)
	}

	/// True for any space character, and the control characters \t, \n, \r, \f, \v.
	var isWhitespace: Bool {

		switch self {

		case " ", "\t", "\n", "\r", UnicodeScalar.BackslashF: return true

		case "\u{000B}", "\u{000C}": return true // Form Feed, vertical tab

		default: return false

		}

	}

	/// True for any Unicode space character, and the control characters \t, \n, \r, \f, \v.
	var isUnicodeSpace: Bool {

		switch self {

		case " ", "\t", "\n", "\r", UnicodeScalar.BackslashF: return true

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

		return "0123456789".unicodeScalars.contains(self)

	}

	/// `true` if `self` is an ASCII hexadecimal digit, i.e. "0"..."9", "a"..."f", "A"..."F".
	var isHexadecimalDigit: Bool {

		return "01234567890abcdefABCDEF".unicodeScalars.contains(self)

	}

	/// `true` if `self` is an ASCII octal digit, i.e. between '0' and '7'.
	var isOctalDigit: Bool {

		return "01234567".unicodeScalars.contains(self)

	}

	var uppercase: UnicodeScalar {
		let str = String(self).uppercased()
		return str.unicodeScalar(0)
	}
}
