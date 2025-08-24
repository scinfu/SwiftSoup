//
//  String.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 21/04/16.
//

import Foundation

extension UInt8 {
    /// Checks if the byte represents a whitespace character:
    /// Space (0x20), Tab (0x09), Newline (0x0A), Carriage Return (0x0D),
    /// Form Feed (0x0C), or Vertical Tab (0x0B).
    @usableFromInline
    @inline(__always)
    var isWhitespace: Bool {
        switch self {
        case 0x20, // Space
            0x09, // Tab (\t)
            0x0A, // Newline (\n)
            0x0D, // Carriage Return (\r)
            0x0C, // Form Feed (\f)
            0x0B: // Vertical Tab (\v)
            return true
        default:
            return false
        }
    }
}

extension ArraySlice where Element == UInt8 {
    @inline(__always)
    public func lowercased() -> ArraySlice<UInt8> {
        // Check if any element needs lowercasing
        guard self.contains(where: { $0 >= 65 && $0 <= 90 }) else { return self }
        // Only allocate a new array if necessary
        var result = self
        for i in result.indices {
            let b = result[i]
            if b >= 65 && b <= 90 {
                result[i] = b + 32
            }
        }
        return result
    }
    
    public func trim() -> ArraySlice<UInt8> {
        // Helper function to check if a byte is whitespace
        func isWhitespace(_ byte: UInt8) -> Bool {
            return byte == 0x20 || (byte >= 0x09 && byte <= 0x0D)
        }
        
        var start = startIndex
        var end = endIndex
        var trimmed = false
        
        while start < end, isWhitespace(self[start]) {
            formIndex(after: &start)
            trimmed = true
        }
        
        while start < end, isWhitespace(self[index(before: end)]) {
            formIndex(before: &end)
            trimmed = true
        }
        
        return trimmed ? self[start..<end] : self
    }
}

#if hasAttribute(retroactive)
extension Array: @retroactive Comparable where Element == UInt8 {}
#else
extension Array: Comparable where Element == UInt8 {}
#endif
extension Array where Element == UInt8 {
    @inline(__always)
    public func lowercased() -> [UInt8] {
        // Check if any element needs lowercasing
        guard self.contains(where: { $0 >= 65 && $0 <= 90 }) else { return self }
        // Only allocate a new array if necessary
        var result = self
        for i in result.indices {
            let b = result[i]
            if b >= 65 && b <= 90 {
                result[i] = b + 32
            }
        }
        return result
    }
    
    @inline(__always)
    func uppercased() -> [UInt8] {
        map { $0 >= 97 && $0 <= 122 ? $0 - 32 : $0 }
    }
     
    @inline(__always)
    func unicodeScalars() -> [UnicodeScalar] {
        var scalars: [UnicodeScalar] = []
        var decoder = UTF8()
        var iterator = makeIterator()
        
        while true {
            switch decoder.decode(&iterator) {
            case .scalarValue(let scalar):
                scalars.append(scalar)
            case .emptyInput:
                return scalars
            case .error:
                // Skip invalid byte
                _ = iterator.next()
            }
        }
    }
    
    @inline(__always)
    public func hasPrefix(_ prefix: [UInt8]) -> Bool {
        guard self.count >= prefix.count else { return false }
        return zip(self, prefix).allSatisfy { $0 == $1 }
    }
    
    public static func < (lhs: [UInt8], rhs: [UInt8]) -> Bool {
        for (byte1, byte2) in zip(lhs, rhs) {
            if byte1 < byte2 {
                return true
            } else if byte1 > byte2 {
                return false
            }
        }
        return lhs.count < rhs.count
    }
    
    @inline(__always)
    func equals(_ string: String) -> Bool {
        return self == string.utf8Array
    }
    
    @inline(__always)
    func equals(_ string: [UInt8]) -> Bool {
        return self == string
    }
    
    @inline(__always)
    public func trim() -> [UInt8] {
        // Helper function to check if a byte is whitespace
        func isWhitespace(_ byte: UInt8) -> Bool {
            return byte == 0x20 || (byte >= 0x09 && byte <= 0x0D)
        }
        
        var start = startIndex
        var end = endIndex
        var trimmed = false
        
        while start < end, isWhitespace(self[start]) {
            formIndex(after: &start)
            trimmed = true
        }
        
        while start < end, isWhitespace(self[index(before: end)]) {
            formIndex(before: &end)
            trimmed = true
        }
        
        return trimmed ? Array(self[start..<end]) : self
    }
    
    @inline(__always)
    func substring(_ beginPrefix: Int) -> [UInt8] {
        return Array(self.dropFirst(beginPrefix))
    }
    
    @inline(__always)
    func equalsIgnoreCase(string: [UInt8]?) -> Bool {
        guard let string else { return false }
        guard self.count == string.count else { return false }
        
        for (byte1, byte2) in zip(self.lazy, string.lazy) {
            // Convert ASCII uppercase to lowercase by adding 32
            let lowerByte1 = (byte1 >= 65 && byte1 <= 90) ? byte1 + 32 : byte1
            let lowerByte2 = (byte2 >= 65 && byte2 <= 90) ? byte2 + 32 : byte2
            if lowerByte1 != lowerByte2 {
                return false
            }
        }
        return true
    }
    
    @usableFromInline
    @inline(__always)
    func caseInsensitiveCompare<T: Collection>(_ other: T) -> ComparisonResult where T.Element == UInt8 {
//    func caseInsensitiveCompare(_ other: [UInt8]) -> ComparisonResult {
        for (byte1, byte2) in zip(self.lazy, other.lazy) {
            let lower1 = (byte1 >= 65 && byte1 <= 90) ? byte1 + 32 : byte1
            let lower2 = (byte2 >= 65 && byte2 <= 90) ? byte2 + 32 : byte2
            if lower1 < lower2 { return .orderedAscending }
            if lower1 > lower2 { return .orderedDescending }
        }
        return self.count < other.count ? .orderedAscending : (self.count > other.count ? .orderedDescending : .orderedSame)
    }
}

#if hasAttribute(retroactive)
extension ArraySlice: @retroactive Comparable where Element == UInt8 {}
#else
extension ArraySlice: Comparable where Element == UInt8 {}
#endif
extension ArraySlice where Element == UInt8 {
    public static func < (lhs: ArraySlice<UInt8>, rhs: ArraySlice<UInt8>) -> Bool {
//    public static func < (lhs: [UInt8], rhs: [UInt8]) -> Bool {
        for (byte1, byte2) in zip(lhs, rhs) {
            if byte1 < byte2 {
                return true
            } else if byte1 > byte2 {
                return false
            }
        }
        return lhs.count < rhs.count
    }
    
    @inline(__always)
    func equals(_ string: String) -> Bool {
        return self == string.utf8Array[...]
    }
    
    @inline(__always)
    func equals(_ string: ArraySlice<UInt8>) -> Bool {
        return self == string
    }

    @inline(__always)
    func toInt(radix: Int) -> Int? {
        if let string = String(bytes: self, encoding: .utf8) {
            return Int(string, radix: radix)
        }
        return nil
    }
}

extension String {
    @inline(__always)
    public var utf8Array: [UInt8] {
        return Array(self.utf8)
    }
    
    @inline(__always)
    public var utf8ArraySlice: ArraySlice<UInt8> {
        return ArraySlice(self.utf8)
    }

    @inline(__always)
    func equals(_ string: [UInt8]?) -> Bool {
        return self.utf8Array == string
    }
    
    @inline(__always)
	subscript (i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: i)]
    }

    @inline(__always)
	subscript (i: Int) -> String {
        return String(self[i] as Character)
    }

    init<S: Sequence>(_ ucs: S)where S.Iterator.Element == UnicodeScalar {
        var s = ""
        s.unicodeScalars.append(contentsOf: ucs)
        self = s
    }

    @inline(__always)
	func unicodeScalar(_ i: Int) -> UnicodeScalar {
        let ix = unicodeScalars.index(unicodeScalars.startIndex, offsetBy: i)
		return unicodeScalars[ix]
    }

    @inline(__always)
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

    @inline(__always)
    func isEmptyOrWhitespace() -> Bool {
        if(self.isEmpty) {
            return true
        }
        return (self.trimmingCharacters(in: CharacterSet.whitespaces) == "")
    }

    @inline(__always)
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

    @inline(__always)
	func indexOf(_ substring: String) -> Int {
        return self.indexOf(substring, 0)
    }

    @inline(__always)
    public func trim() -> String {
        // trimmingCharacters() in the stdlib is not very efficiently
        // implemented, perhaps because it always creates a new string.
        // Avoid actually calling it if it's not needed.
        guard !isEmpty else { return self }
        let (firstChar, lastChar) = (first!, last!)
        if firstChar.isWhitespace || lastChar.isWhitespace || firstChar == "\n" || lastChar == "\n" {
            return trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return self
    }

    @inline(__always)
    func equalsIgnoreCase(string: String?) -> Bool {
        if let string {
            return caseInsensitiveCompare(string) == .orderedSame
        }
        return false
    }

    @usableFromInline
    @inline(__always)
    static func toHexString(n: Int) -> String {
        return String(format: "%2x", n)
    }

    @inline(__always)
    func insert(string: String, ind: Int) -> String {
        return  String(self.prefix(ind)) + string + String(self.suffix(self.count-ind))
    }

    @inline(__always)
    func charAt(_ i: Int) -> Character {
        return self[i] as Character
    }

    @inline(__always)
    func utf8ByteAt(_ i: Int) -> UInt8 {
      return self.utf8Array[i]
    }

    @inline(__always)
	func substring(_ beginIndex: Int) -> String {
        return String.split(self, beginIndex, self.count-beginIndex)
    }

    @inline(__always)
	func substring(_ beginIndex: Int, _ count: Int) -> String {
        return String.split(self, beginIndex, count)
    }

    func regionMatches(
        ignoreCase: Bool,
        selfOffset: Int,
        other: String,
        otherOffset: Int,
        targetLength: Int
    ) -> Bool {
        if ((otherOffset < 0) || (selfOffset < 0)
            || (selfOffset > self.count - targetLength)
            || (otherOffset > other.count - targetLength)) {
            return false
        }

        for i in 0..<targetLength {
            let charSelf: Character = self[i + selfOffset]
            let charOther: Character = other[i + otherOffset]
            if ignoreCase {
                if charSelf.lowercase != charOther.lowercase {
                    return false
                }
            } else if charSelf != charOther {
                return false
            }
        }
        return true
    }

    @inline(__always)
    func startsWith(_ input: String, _ offset: Int) -> Bool {
        if ((offset < 0) || (offset > count - input.count)) {
            return false
        }
        for i in 0..<input.count {
            let charSelf: Character = self[i + offset]
            let charOther: Character = input[i]
            if charSelf != charOther { return false }
        }
        return true
    }

    @inline(__always)
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

    @inline(__always)
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
