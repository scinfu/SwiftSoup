import Foundation

fileprivate let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

public final class CharacterReader {
    private static let empty = ""
    public static let EOF: UnicodeScalar = "\u{FFFF}" // 65535
    public let input: [UInt8]
    public var pos: [UInt8].Index
    private var mark: [UInt8].Index
    private let start: [UInt8].Index
    public let end: [UInt8].Index
    
    private static let letters = ParsingStrings("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) })
    private static let digits = ParsingStrings(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    
    public init(_ input: [UInt8]) {
        self.input = input
        let start = self.input.startIndex
        self.pos = start
        self.mark = start
        self.start = start
        self.end = self.input.endIndex
    }
    
    public convenience init(_ input: String) {
        self.init(input.utf8Array)
    }

    public func getPos() -> Int {
        return input.distance(from: input.startIndex, to: pos)
    }
    
    public func isEmpty() -> Bool {
        return pos >= end
    }
    
    public func current() -> UnicodeScalar {
        guard pos < end else { return CharacterReader.EOF }
        
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            return scalar
        case .emptyInput, .error:
            return CharacterReader.EOF
        }
    }
    
    @inlinable
    public func currentUTF8() -> ArraySlice<UInt8> {
        guard pos < end else { return TokeniserStateVars.eofUTF8Slice }
        
        let firstByte = input[pos]

        let length: Int
        
        // Determine UTF-8 sequence length based on the first byte
        if firstByte & 0x80 == 0 { // 1-byte ASCII (0xxxxxxx)
            length = 1
        } else if firstByte & 0xE0 == 0xC0 { // 2-byte sequence (110xxxxx)
            length = 2
        } else if firstByte & 0xF0 == 0xE0 { // 3-byte sequence (1110xxxx)
            length = 3
        } else if firstByte & 0xF8 == 0xF0 { // 4-byte sequence (11110xxx)
            length = 4
        } else {
            return [] // Invalid UTF-8 leading byte
        }
        
        // Ensure there are enough bytes remaining in `input`
        if pos + length > end {
            return [] // Incomplete UTF-8 sequence
        }
        
        // Validate continuation bytes (they should all be 10xxxxxx)
        for i in 1..<length {
            if input[pos + i] & 0xC0 != 0x80 {
                return [] // Invalid UTF-8 sequence
            }
        }
        
        // Return the valid UTF-8 byte sequence
        return input[pos..<(pos + length)]
    }

    @discardableResult
    public func consume() -> UnicodeScalar {
        guard pos < end else { return CharacterReader.EOF }
        
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            let scalarLength = UTF8.width(scalar)
            input.formIndex(&pos, offsetBy: scalarLength)
            return scalar
        case .emptyInput, .error:
            return CharacterReader.EOF
        }
    }
    
    public func unconsume() {
        guard pos > start else { return }
        
        var utf8Decoder = UTF8()
        var index = pos
        var scalarLength = 1
        
        // Decode previous scalar from current position
        while index > start {
            input.formIndex(before: &index)
            var iterator = input[index..<pos].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar):
                scalarLength = UTF8.width(scalar)
                pos = input.index(pos, offsetBy: -scalarLength)
                return
            case .emptyInput, .error:
                break // Continue moving back until a valid scalar is found
            }
        }
    }
    
    public func advance() {
        guard pos < end else { return }
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            let scalarLength = UTF8.width(scalar)
            input.formIndex(&pos, offsetBy: scalarLength)
        case .emptyInput, .error:
            break
        }
    }
    
    public func markPos() {
        mark = pos
    }
    
    public func rewindToMark() {
        pos = mark
    }
    
    public func consumeAsString() -> String {
        guard pos < end else { return "" }
        
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            let scalarLength = UTF8.width(scalar)
            input.formIndex(&pos, offsetBy: scalarLength)
            return String(scalar)
        case .emptyInput, .error:
            return ""
        }
    }
    
    @inline(__always)
    public func consumeToAny(_ chars: ParsingStrings) -> String {
        return String(decoding: consumeToAny(chars), as: UTF8.self)
    }
    
    @inline(__always)
    public func consumeToAny(_ chars: ParsingStrings) -> ArraySlice<UInt8> {
        let start = pos
        
        while pos < end {
            // Skip continuation bytes
            if input[pos] & 0b11000000 == 0b10000000 {
                pos += 1
                continue
            }
            
            let charLen = input[pos] < 0x80 ? 1 : input[pos] < 0xE0 ? 2 : input[pos] < 0xF0 ? 3 : 4
            
            // Check if the current multi-byte sequence matches any character in `chars`
            if chars.contains(input[pos..<min(pos + charLen, end)]) {
                return input[start..<pos]
            }
            
            pos += charLen
        }
        
        return input[start..<pos]
    }
    
    private func unicodeScalar(at index: String.UTF8View.Index, in utf8View: String.UTF8View) -> UnicodeScalar? {
        var iterator = utf8View[index...].makeIterator()
        var utf8Decoder = UTF8()
        var unicodeScalar: UnicodeScalar?
        let decodingState = utf8Decoder.decode(&iterator)
        
        switch decodingState {
        case .scalarValue(let scalar):
            unicodeScalar = scalar
        case .emptyInput, .error:
            break // Handle decoding errors if needed
        }
        
        return unicodeScalar
    }
    
    public func consumeTo(_ c: UnicodeScalar) -> ArraySlice<UInt8> {
        guard let targetIx = nextIndexOf(c) else { return consumeToEndUTF8() }
        
        // Convert `String.UTF8View.Index` (targetIx) to `[UInt8].Index` for `input`
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        let byteOffset = utf8View.distance(from: utf8View.startIndex, to: targetIx)
        let targetByteIndex = input.index(start, offsetBy: byteOffset)
        
        // Use the `cacheString` method with `pos` and `targetByteIndex`
        let consumed = cacheString(pos, targetByteIndex)
        pos = targetByteIndex // Update `pos` to the new position
        return consumed
    }
    
    @inline(__always)
    public func consumeTo(_ seq: String) -> String {
        return String(decoding: consumeTo(seq.utf8Array), as: UTF8.self)
    }
    
    public func consumeTo(_ seq: [UInt8]) -> ArraySlice<UInt8> {
        guard let targetIx = nextIndexOf(seq) else { return consumeToEndUTF8() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    @inline(__always)
    public func consumeToEnd() -> String {
        return String(decoding: consumeToEndUTF8(), as: UTF8.self)
    }
    
    @inline(__always)
    public func consumeToEndUTF8() -> ArraySlice<UInt8> {
        let consumed = cacheString(pos, end)
        pos = end
        return consumed
    }
    
    public func consumeLetterSequence() -> ArraySlice<UInt8> {
        let start = pos
        var utf8Decoder = UTF8()
        
        while pos < end {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.letters.contains(scalar):
                let scalarLength = UTF8.width(scalar)
                input.formIndex(&pos, offsetBy: scalarLength)
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeLetterThenDigitSequence() -> ArraySlice<UInt8> {
        let start = pos
        var utf8Decoder = UTF8()
        
        letterLoop: while pos < end {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.letters.contains(scalar):
                let scalarLength = UTF8.width(scalar)
                input.formIndex(&pos, offsetBy: scalarLength)
            default:
                break letterLoop
            }
        }
        
        digitLoop: while pos < end {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.decimalDigits.contains(scalar):
                let scalarLength = UTF8.width(scalar)
                input.formIndex(&pos, offsetBy: scalarLength)
            default:
                break digitLoop
            }
        }
        
        return cacheString(start, pos)
    }
    
    public func consumeHexSequence() -> ArraySlice<UInt8> {
        let start = pos
        var utf8Decoder = UTF8()
        
        while pos < end {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where hexCharacterSet.contains(scalar):
                let scalarLength = UTF8.width(scalar)
                input.formIndex(&pos, offsetBy: scalarLength)
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeDigitSequence() -> ArraySlice<UInt8> {
        let start = pos
        var utf8Decoder = UTF8()
        
        while pos < end {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.decimalDigits.contains(scalar):
                let scalarLength = UTF8.width(scalar)
                input.formIndex(&pos, offsetBy: scalarLength)
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    @inline(__always)
    public func matches(_ c: UnicodeScalar) -> Bool {
        guard pos < end else { return false }
        
        // Decode the UTF-8 byte sequence at the current position
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            return scalar == c
        case .emptyInput, .error:
            return false // Handle errors or end of input gracefully
        }
    }
    
    @inline(__always)
    public func matches(_ seq: String, ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        return matches(seq.utf8Array, ignoreCase: ignoreCase, consume: consume)
    }

    public func matches(_ seq: [UInt8], ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        var current = pos
        var utf8Decoder = UTF8()
        var seqIterator = seq.makeIterator()
        
        while let expectedByte = seqIterator.next() {
            guard current < end else { return false }
            
            var inputIterator = input[current...].makeIterator()
            switch utf8Decoder.decode(&inputIterator) {
            case .scalarValue(let scalar):
                let expectedScalar = UnicodeScalar(expectedByte)
                if ignoreCase {
                    guard scalar.properties.uppercaseMapping == expectedScalar.properties.uppercaseMapping else { return false }
                } else {
                    guard scalar == expectedScalar else { return false }
                }
                let scalarLength = UTF8.width(scalar)
                input.formIndex(&current, offsetBy: scalarLength)
            case .emptyInput, .error:
                return false
            }
        }
        
        if consume {
            pos = current
        }
        
        return true
    }
    
    @inline(__always)
    public func matchesIgnoreCase(_ seq: [UInt8]) -> Bool {
        return matches(seq, ignoreCase: true)
    }
    
    @inline(__always)
    public func matchesIgnoreCase(_ seq: String) -> Bool {
        return matches(seq.utf8Array, ignoreCase: true)
    }

    public func matchesAny(_ seq: ParsingStrings) -> Bool {
        var buffer = [UInt8](repeating: 0, count: 4) // Max UTF-8 sequence is 4 bytes
        var length = 1
        buffer[0] = input[pos]
        
        // Check if the first byte indicates a multi-byte character
        if buffer[0] & 0b10000000 != 0 {
            if buffer[0] & 0b11100000 == 0b11000000, pos + 1 < end {
                buffer[1] = input[pos + 1]
                length = 2
            } else if buffer[0] & 0b11110000 == 0b11100000, pos + 2 < end {
                buffer[1] = input[pos + 1]
                buffer[2] = input[pos + 2]
                length = 3
            } else if buffer[0] & 0b11111000 == 0b11110000, pos + 3 < end {
                buffer[1] = input[pos + 1]
                buffer[2] = input[pos + 2]
                buffer[3] = input[pos + 3]
                length = 4
            } else {
                return false // Invalid UTF-8 sequence
            }
        }
        let bufferSlice = buffer[..<length]
        
        return seq.contains(bufferSlice)
    }
    
    public func matchesAny(_ seq: UnicodeScalar...) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesAny(_ seq: [UnicodeScalar]) -> Bool {
        return matchesAny(seq.map { Array($0.utf8) })
    }
    
    public func matchesAny(_ seq: [UInt8]...) -> Bool {
        return matchesAny(seq)
    }

    public func matchesAny(_ seq: [[UInt8]]) -> Bool {
        guard pos < end else { return false }
        
        var buffer = [UInt8](repeating: 0, count: 4) // Max UTF-8 sequence is 4 bytes
        var length = 1
        buffer[0] = input[pos]
        
        // Check if the first byte indicates a multi-byte character
        if buffer[0] & 0b10000000 != 0 {
            if buffer[0] & 0b11100000 == 0b11000000, pos + 1 < end {
                buffer[1] = input[pos + 1]
                length = 2
            } else if buffer[0] & 0b11110000 == 0b11100000, pos + 2 < end {
                buffer[1] = input[pos + 1]
                buffer[2] = input[pos + 2]
                length = 3
            } else if buffer[0] & 0b11111000 == 0b11110000, pos + 3 < end {
                buffer[1] = input[pos + 1]
                buffer[2] = input[pos + 2]
                buffer[3] = input[pos + 3]
                length = 4
            } else {
                return false // Invalid UTF-8 sequence
            }
        }
        let bufferSlice = buffer[..<length]
        for utf8Bytes in seq {
            if utf8Bytes.count == length, utf8Bytes.elementsEqual(bufferSlice) {
                return true
            }
        }
        return false
    }
    
    public func matchesLetter() -> Bool {
        guard pos < end else { return false }
        
        let firstByte = input[pos]
        var length = 1
        
        if firstByte & 0b10000000 != 0 {
            if firstByte & 0b11100000 == 0b11000000, pos + 1 < end {
                length = 2
            } else if firstByte & 0b11110000 == 0b11100000, pos + 2 < end {
                length = 3
            } else if firstByte & 0b11111000 == 0b11110000, pos + 3 < end {
                length = 4
            } else {
                return false
            }
        }
        
        return Self.letters.contains(input[pos..<(pos + length)])
    }
    
    public func matchesDigit() -> Bool {
        guard pos < end else { return false }
        
        var buffer = [UInt8](repeating: 0, count: 4)
        var length = 0
        
        buffer[0] = input[pos]
        length = 1
        
        if buffer[0] & 0b10000000 != 0 { // Multibyte sequence
            if buffer[0] & 0b11100000 == 0b11000000, pos + 1 < end {
                buffer[1] = input[pos + 1]
                length = 2
            } else if buffer[0] & 0b11110000 == 0b11100000, pos + 2 < end {
                buffer[1] = input[pos + 1]
                buffer[2] = input[pos + 2]
                length = 3
            } else if buffer[0] & 0b11111000 == 0b11110000, pos + 3 < end {
                buffer[1] = input[pos + 1]
                buffer[2] = input[pos + 2]
                buffer[3] = input[pos + 3]
                length = 4
            } else {
                return false
            }
        }
        
        return Self.digits.contains(buffer[..<length])
    }
    
    @discardableResult
    @inline(__always)
    public func matchConsume(_ seq: [UInt8]) -> Bool {
        return matches(seq, consume: true)
    }
    
    @discardableResult
    @inline(__always)
    public func matchConsumeIgnoreCase(_ seq: [UInt8]) -> Bool {
        return matches(seq, ignoreCase: true, consume: true)
    }
    
    @inline(__always)
    public func containsIgnoreCase(_ seq: [UInt8]) -> Bool {
        let loScan = seq.lowercased()
        let hiScan = seq.uppercased()
        return nextIndexOf(loScan) != nil || nextIndexOf(hiScan) != nil
    }
    
    @inline(__always)
    public func containsIgnoreCase(_ seq: String) -> Bool {
        return containsIgnoreCase(seq.utf8Array)
    }

    @inline(__always)
    public func toString() -> String {
        return String(decoding: input[pos...], as: UTF8.self)
    }
    
//    private func cacheString(_ start: String.UTF8View.Index, _ end: String.UTF8View.Index) -> String {
//        let utf8View = String(decoding: input, as: UTF8.self).utf8
//        guard start <= end && end <= utf8View.endIndex else { return "" }
//        return String(decoding: utf8View[start..<end], as: UTF8.self)
//    }
    
    /**
     * Originally intended as a caching mechanism for strings, but caching doesn't
     * seem to improve performance. Now just a stub.
     */
    @inline(__always)
    private func cacheString(_ start: [UInt8].Index, _ end: [UInt8].Index) -> ArraySlice<UInt8> {
        return input[start..<end]
    }
    
    @inline(__always)
    public func nextIndexOf(_ c: UnicodeScalar) -> String.UTF8View.Index? {
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        let startIndex = utf8View.index(utf8View.startIndex, offsetBy: getPos())
        
        return utf8View[startIndex...].firstIndex { UnicodeScalar($0) == c }
    }
    
    public func nextIndexOf(_ seq: String) -> String.UTF8View.Index? {
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        let startIndex = utf8View.index(utf8View.startIndex, offsetBy: getPos())
        let targetUtf8 = seq.utf8
        
        var current = startIndex
        
        while current <= utf8View.endIndex {
            if utf8View[current...].starts(with: targetUtf8) {
                return current
            }
            
            // Increment the current index by one scalar to avoid breaking UTF-8 sequences
            if let scalar = utf8View[current...].first.map({ UnicodeScalar($0) }) {
                let scalarLength = UTF8.width(scalar)
                utf8View.formIndex(&current, offsetBy: scalarLength)
            } else {
                utf8View.formIndex(after: &current)
            }
        }
        
        return nil
    }

    public func nextIndexOf(_ targetUtf8: [UInt8]) -> [UInt8].Index? {
        var start = pos
        
        while true {
            guard let firstCharIx = input[start...].firstIndex(of: targetUtf8.first!) else { return nil }
            
            var current = firstCharIx
            var matched = true
            for utf8Byte in targetUtf8 {
                guard current < end else { return nil }
                if input[current] != utf8Byte {
                    matched = false
                    break
                }
                input.formIndex(after: &current)
            }
            
            if matched {
                return firstCharIx
            } else {
                start = input.index(after: firstCharIx)
            }
        }
    }

    public static let dataTerminators = ParsingStrings([.Ampersand, .LessThan, TokeniserStateVars.nullScalr])
    
    @inlinable
    public func consumeData() -> ArraySlice<UInt8> {
        return consumeToAny(CharacterReader.dataTerminators)
    }
    
    public static let tagNameTerminators = ParsingStrings([.BackslashT, .BackslashN, .BackslashR, .BackslashF, .Space, .Slash, .GreaterThan, TokeniserStateVars.nullScalr])
    
    @inlinable
    public func consumeTagName() -> ArraySlice<UInt8> {
        return consumeToAny(CharacterReader.tagNameTerminators)
    }
}

extension CharacterReader: CustomDebugStringConvertible {
    public var debugDescription: String {
        return toString()
    }
}
