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
    public static let Ampersand: UnicodeScalar = "&"
    public static let LessThan: UnicodeScalar = "<"
    public static let GreaterThan: UnicodeScalar = ">"

    public static let Space: UnicodeScalar = " "
	public static let BackslashF: UnicodeScalar = UnicodeScalar(12)
    public static let BackslashT: UnicodeScalar = "\t"
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

	var uppercase: UnicodeScalar {
		let str = String(self).uppercased()
		return str.unicodeScalar(0)
	}
}
