//
//  CharacterExt.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 08/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

extension Character {

    public static let space: Character = " "
    public static let BackslashT: Character = "\t"
    public static let BackslashN: Character = "\n"
    public static let BackslashF: Character = Character(UnicodeScalar(12))
    public static let BackslashR: Character = "\r"
    public static let BackshashRBackslashN: Character = "\r\n"

    //http://www.unicode.org/glossary/#supplementary_code_point
    public static let MIN_SUPPLEMENTARY_CODE_POINT: UInt32 = 0x010000

    /// True for any space character, and the control characters \t, \n, \r, \f, \v.

    var isWhitespace: Bool {
        switch self {
        case Character.space, Character.BackslashT, Character.BackslashN, Character.BackslashF, Character.BackslashR: return true
        case Character.BackshashRBackslashN: return true
        default: return false

        }
    }

    /// `true` if `self` normalized contains a single code unit that is in the category of Decimal Numbers.
    var isDigit: Bool {

        return isMemberOfCharacterSet(CharacterSet.decimalDigits)

    }

    /// Lowercase `self`.
    var lowercase: Character {

        let str = String(self).lowercased()
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
