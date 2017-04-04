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
    public static let Ampersand : UnicodeScalar = "&"
    public static let LessThan : UnicodeScalar = "<"
    public static let GreaterThan : UnicodeScalar = ">"
    
    public static let Space: UnicodeScalar = " "
	public static let BackslashF: UnicodeScalar = UnicodeScalar(12)
    public static let BackslashT: UnicodeScalar = UnicodeScalar.BackslashT
    public static let BackslashN: UnicodeScalar = "\n"
    public static let BackslashR: UnicodeScalar = "\r"
    public static let Slash: UnicodeScalar = "/"
    
    public static let FormFeed: UnicodeScalar = "\u{000B}"// Form Feed
    public static let VerticalTab: UnicodeScalar = "\u{000C}"// vertical tab

	func isMemberOfCharacterSet(_ set: CharacterSet) -> Bool {
		return set.contains(self)
	}

	/// True for any space character, and the control characters \t, \n, \r, \f, \v.
	var isWhitespace: Bool {

		switch self {

		case UnicodeScalar.Space, UnicodeScalar.BackslashT, UnicodeScalar.BackslashN, UnicodeScalar.BackslashR, UnicodeScalar.BackslashF: return true

		case UnicodeScalar.FormFeed, UnicodeScalar.VerticalTab: return true // Form Feed, vertical tab

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
