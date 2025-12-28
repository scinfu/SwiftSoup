import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

fileprivate let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

public final class CharacterReader {
    private static let empty = ""
    public static let EOF: UnicodeScalar = "\u{FFFF}" // 65535
    public let input: [UInt8]
    public var pos: [UInt8].Index
    private var mark: [UInt8].Index
    private let start: [UInt8].Index
    public let end: [UInt8].Index
    private let useNoNullFastPath: Bool
    
    private static let letters = ParsingStrings("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) })
    private static let digits = ParsingStrings(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    private static let utf8WidthTable: [UInt8] = {
        var table = [UInt8](repeating: 1, count: 256)
        var i = 0xC0
        while i <= 0xDF {
            table[i] = 2
            i += 1
        }
        i = 0xE0
        while i <= 0xEF {
            table[i] = 3
            i += 1
        }
        i = 0xF0
        while i <= 0xF7 {
            table[i] = 4
            i += 1
        }
        return table
    }()
    
    public init(_ input: [UInt8]) {
        self.input = input
        let start = self.input.startIndex
        self.pos = start
        self.mark = start
        self.start = start
        self.end = self.input.endIndex
        let totalCount = self.input.count
        if totalCount == 0 {
            self.useNoNullFastPath = false
        } else if totalCount >= 64 {
            #if canImport(Darwin) || canImport(Glibc)
            let hasNull = self.input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return false
                }
                return memchr(basePtr, Int32(TokeniserStateVars.nullByte), totalCount) != nil
            }
            self.useNoNullFastPath = !hasNull
            #else
            self.useNoNullFastPath = !self.input.contains(0)
            #endif
        } else {
            self.useNoNullFastPath = !self.input.contains(0)
        }
    }
    
    public convenience init(_ input: String) {
        self.init(input.utf8Array)
    }

    @inline(__always)
    internal var canSkipNullCheck: Bool {
        return useNoNullFastPath
    }

    public func getPos() -> Int {
        return input.distance(from: input.startIndex, to: pos)
    }
    
    public func isEmpty() -> Bool {
        return pos >= end
    }
    
    public func current() -> UnicodeScalar {
        guard pos < end else { return CharacterReader.EOF }

        let firstByte = input[pos]
        if firstByte < 0x80 {
            return UnicodeScalar(firstByte)
        }

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

    @inline(__always)
    public func currentByte() -> UInt8? {
        guard pos < end else { return nil }
        return input[pos]
    }

    @inline(__always)
    public func consumeByte() -> UInt8? {
        guard pos < end else { return nil }
        let byte = input[pos]
        pos &+= 1
        return byte
    }

    @inline(__always)
    public func consumeAsciiScalar() -> UnicodeScalar {
        guard pos < end else { return CharacterReader.EOF }
        let byte = input[pos]
        pos &+= 1
        return UnicodeScalar(byte)
    }

    @discardableResult
    public func consume() -> UnicodeScalar {
        guard pos < end else { return CharacterReader.EOF }

        let firstByte = input[pos]
        if firstByte < 0x80 {
            pos += 1
            return UnicodeScalar(firstByte)
        }

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
        let firstByte = input[pos]
        if firstByte < 0x80 {
            pos += 1
            return
        }
        let width = CharacterReader.utf8WidthTable[Int(firstByte)]
        let newPos = pos + Int(width)
        pos = newPos <= end ? newPos : end
    }
    
    @inline(__always)
    public func advanceAscii() {
        guard pos < end else { return }
        pos &+= 1
    }
    
    public func markPos() {
        mark = pos
    }
    
    public func rewindToMark() {
        pos = mark
    }
    
    public func consumeAsString() -> String {
        guard pos < end else { return "" }

        let firstByte = input[pos]
        if firstByte < 0x80 {
            pos += 1
            return String(UnicodeScalar(firstByte))
        }

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
        if chars.isSingleByteOnly {
            while pos < end {
                let byte = input[pos]
                if testBit(chars.singleByteMask, byte) {
                    return input[start..<pos]
                }
                pos &+= 1
            }
            return input[start..<pos]
        }

        while pos < end {
            // Skip continuation bytes
            if input[pos] & 0b11000000 == 0b10000000 {
                pos += 1
                continue
            }

            let firstByte = input[pos]
            if firstByte < 0x80 {
                if chars.contains(firstByte) {
                    return input[start..<pos]
                }
                pos += 1
                continue
            }

            let charLen = firstByte < 0xE0 ? 2 : firstByte < 0xF0 ? 3 : 4

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
        if c.value <= 0x7F {
            let byte = UInt8(c.value)
            return consumeToAnyOfOne(byte)
        }
        var buffer = [UInt8](repeating: 0, count: 4)
        var length = 0
        for b in c.utf8 {
            buffer[length] = b
            length &+= 1
        }
        if length == 0 { return consumeToEndUTF8() }
        let target = Array(buffer[..<length])
        guard let targetIx = nextIndexOf(target) else { return consumeToEndUTF8() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    @inline(__always)
    public func consumeTo(_ seq: String) -> String {
        return String(decoding: consumeTo(seq.utf8Array), as: UTF8.self)
    }
    
    public func consumeTo(_ seq: [UInt8]) -> ArraySlice<UInt8> {
        if seq.count == 1 {
            return consumeToAnyOfOne(seq[0])
        }
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
        while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if (firstByte >= 65 && firstByte <= 90) || (firstByte >= 97 && firstByte <= 122) {
                    pos += 1
                    continue
                }
                return cacheString(start, pos)
            }
            break
        }

        var utf8Decoder = UTF8()
        while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if (firstByte >= 65 && firstByte <= 90) || (firstByte >= 97 && firstByte <= 122) {
                    pos += 1
                    continue
                }
                return cacheString(start, pos)
            }

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
        letterLoop: while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if (firstByte >= 65 && firstByte <= 90) || (firstByte >= 97 && firstByte <= 122) {
                    pos += 1
                    continue
                }
                break letterLoop
            }
            break
        }

        var utf8Decoder = UTF8()
        letterLoop: while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if (firstByte >= 65 && firstByte <= 90) || (firstByte >= 97 && firstByte <= 122) {
                    pos += 1
                    continue
                }
                break letterLoop
            }

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
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if firstByte >= 48 && firstByte <= 57 {
                    pos += 1
                    continue
                }
                break digitLoop
            }
            break
        }

        digitLoop: while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if firstByte >= 48 && firstByte <= 57 {
                    pos += 1
                    continue
                }
                break digitLoop
            }

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
        while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                let isHex = (firstByte >= 48 && firstByte <= 57) ||
                    (firstByte >= 65 && firstByte <= 70) ||
                    (firstByte >= 97 && firstByte <= 102)
                if isHex {
                    pos += 1
                    continue
                }
                return cacheString(start, pos)
            }
            break
        }

        var utf8Decoder = UTF8()
        while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                let isHex = (firstByte >= 48 && firstByte <= 57) ||
                    (firstByte >= 65 && firstByte <= 70) ||
                    (firstByte >= 97 && firstByte <= 102)
                if isHex {
                    pos += 1
                    continue
                }
                return cacheString(start, pos)
            }

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
        while pos < end {
            let firstByte = input[pos]
            if firstByte < 0x80 {
                if firstByte >= 48 && firstByte <= 57 {
                    pos += 1
                    continue
                }
                return cacheString(start, pos)
            }

            let slice = currentUTF8()
            if slice.isEmpty { return cacheString(start, pos) }
            var iterator = slice.makeIterator()
            var utf8Decoder = UTF8()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.decimalDigits.contains(scalar):
                input.formIndex(&pos, offsetBy: slice.count)
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    @inline(__always)
    public func matches(_ c: UnicodeScalar) -> Bool {
        guard pos < end else { return false }
        if c.value < 0x80 {
            return input[pos] == UInt8(c.value)
        }
        
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
        guard !seq.isEmpty else { return true }
        guard let endIndex = input.index(pos, offsetBy: seq.count, limitedBy: end) else { return false }

        if !ignoreCase {
            if input[pos..<endIndex].elementsEqual(seq) {
                if consume { pos = endIndex }
                return true
            }
            return false
        }

        var allAscii = true
        for b in seq where b & 0x80 != 0 {
            allAscii = false
            break
        }
        if allAscii {
            var idx = pos
            for expected in seq {
                let actual = input[idx]
                let a = (actual >= 65 && actual <= 90) ? actual &+ 32 : actual
                let e = (expected >= 65 && expected <= 90) ? expected &+ 32 : expected
                if a != e { return false }
                idx = input.index(after: idx)
            }
            if consume { pos = idx }
            return true
        }

        var current = pos
        var utf8Decoder = UTF8()
        var seqIterator = seq.makeIterator()

        while let expectedByte = seqIterator.next() {
            guard current < end else { return false }

            var inputIterator = input[current...].makeIterator()
            switch utf8Decoder.decode(&inputIterator) {
            case .scalarValue(let scalar):
                let expectedScalar = UnicodeScalar(expectedByte)
                guard scalar.properties.uppercaseMapping == expectedScalar.properties.uppercaseMapping else { return false }
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
        guard input.count > pos
        else { return false }

        if let byte = currentByte(), byte < 0x80 {
            return seq.contains(byte)
        }
        if seq.isSingleByteOnly {
            guard let byte = currentByte() else { return false }
            return seq.contains(byte)
        }

        let slice = currentUTF8()
        if slice.isEmpty { return false }
        if slice.count == 1 {
            return seq.contains(slice.first!)
        }
        return seq.contains(slice)
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
        guard pos < end,
              input.count > pos
        else { return false }

        if let byte = currentByte() {
            var allSingleByte = true
            for utf8Bytes in seq where utf8Bytes.count != 1 {
                allSingleByte = false
                break
            }
            if allSingleByte {
                for utf8Bytes in seq where utf8Bytes.first == byte {
                    return true
                }
                return false
            }
        }

        let slice = currentUTF8()
        if slice.isEmpty { return false }
        for utf8Bytes in seq where utf8Bytes.count == slice.count {
            if utf8Bytes.elementsEqual(slice) { return true }
        }
        return false
    }
    
    public func matchesLetter() -> Bool {
        guard pos < end else { return false }
        
        let firstByte = input[pos]
        if firstByte < 0x80 {
            return (firstByte >= 65 && firstByte <= 90) || (firstByte >= 97 && firstByte <= 122)
        }
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
        guard pos < end,
              input.count > pos
        else { return false }

        let firstByte = input[pos]
        if firstByte < 0x80 {
            return firstByte >= 48 && firstByte <= 57
        }

        let slice = currentUTF8()
        if slice.isEmpty { return false }
        if slice.count == 1 {
            let b = slice.first!
            return b >= 48 && b <= 57
        }
        return Self.digits.contains(slice)
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
        var allAscii = true
        for b in seq where b & 0x80 != 0 {
            allAscii = false
            break
        }
        if allAscii {
            return containsAsciiTransformed(seq, upper: false) || containsAsciiTransformed(seq, upper: true)
        }
        let loScan = seq.lowercased()
        let hiScan = seq.uppercased()
        return nextIndexOf(loScan) != nil || nextIndexOf(hiScan) != nil
    }

    @inline(__always)
    public func containsIgnoreCase(prefix: [UInt8], suffix: [UInt8]) -> Bool {
        let totalCount = prefix.count + suffix.count
        if totalCount == 0 { return true }
        var allAscii = true
        for b in prefix where b & 0x80 != 0 {
            allAscii = false
            break
        }
        if allAscii {
            for b in suffix where b & 0x80 != 0 {
                allAscii = false
                break
            }
        }
        if allAscii {
            return containsAsciiTransformed(prefix: prefix, suffix: suffix, upper: false)
                || containsAsciiTransformed(prefix: prefix, suffix: suffix, upper: true)
        }
        let combined = prefix + suffix
        let loScan = combined.lowercased()
        let hiScan = combined.uppercased()
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

    @inline(__always)
    private func containsAsciiTransformed(_ seq: [UInt8], upper: Bool) -> Bool {
        guard !seq.isEmpty else { return true }
        let transformedFirst: UInt8
        if upper {
            let b = seq[0]
            transformedFirst = (b >= 97 && b <= 122) ? b &- 32 : b
        } else {
            let b = seq[0]
            transformedFirst = (b >= 65 && b <= 90) ? b &+ 32 : b
        }
        if seq.count == 1 {
            return input[pos...].firstIndex(of: transformedFirst) != nil
        }
        let lastStart = end - seq.count
        if pos > lastStart { return false }
        var i = pos
        while i <= lastStart {
            if input[i] == transformedFirst {
                var j = 1
                while j < seq.count {
                    let b = seq[j]
                    let expected: UInt8
                    if upper {
                        expected = (b >= 97 && b <= 122) ? b &- 32 : b
                    } else {
                        expected = (b >= 65 && b <= 90) ? b &+ 32 : b
                    }
                    if input[i + j] != expected { break }
                    j &+= 1
                }
                if j == seq.count { return true }
            }
            i &+= 1
        }
        return false
    }

    @inline(__always)
    private func containsAsciiTransformed(prefix: [UInt8], suffix: [UInt8], upper: Bool) -> Bool {
        let totalCount = prefix.count + suffix.count
        guard totalCount > 0 else { return true }
        let firstByte: UInt8 = prefix.isEmpty ? suffix[0] : prefix[0]
        let transformedFirst: UInt8
        if upper {
            transformedFirst = (firstByte >= 97 && firstByte <= 122) ? firstByte &- 32 : firstByte
        } else {
            transformedFirst = (firstByte >= 65 && firstByte <= 90) ? firstByte &+ 32 : firstByte
        }
        if totalCount == 1 {
            return input[pos...].firstIndex(of: transformedFirst) != nil
        }
        let lastStart = end - totalCount
        if pos > lastStart { return false }
        var i = pos
        let prefixCount = prefix.count
        while i <= lastStart {
            if input[i] == transformedFirst {
                var j = 1
                while j < totalCount {
                    let b: UInt8 = j < prefixCount ? prefix[j] : suffix[j - prefixCount]
                    let expected: UInt8
                    if upper {
                        expected = (b >= 97 && b <= 122) ? b &- 32 : b
                    } else {
                        expected = (b >= 65 && b <= 90) ? b &+ 32 : b
                    }
                    if input[i + j] != expected {
                        break
                    }
                    j += 1
                }
                if j == totalCount {
                    return true
                }
            }
            i += 1
        }
        return false
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
        var buffer = [UInt8](repeating: 0, count: 4)
        var length = 0
        for b in c.utf8 {
            buffer[length] = b
            length &+= 1
        }
        if length == 0 { return nil }
        let target = Array(buffer[..<length])
        guard let targetIx = nextIndexOf(target) else { return nil }
        let byteOffset = input.distance(from: input.startIndex, to: targetIx)
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        return utf8View.index(utf8View.startIndex, offsetBy: byteOffset)
    }
    
    public func nextIndexOf(_ seq: String) -> String.UTF8View.Index? {
        let targetUtf8 = seq.utf8Array
        guard let targetIx = nextIndexOf(targetUtf8) else { return nil }
        let byteOffset = input.distance(from: input.startIndex, to: targetIx)
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        return utf8View.index(utf8View.startIndex, offsetBy: byteOffset)
    }

    public func nextIndexOf(_ targetUtf8: [UInt8]) -> [UInt8].Index? {
        #if PROFILE
        let _p = Profiler.start("CharacterReader.nextIndexOf")
        defer { Profiler.end("CharacterReader.nextIndexOf", _p) }
        #endif
        let targetCount = targetUtf8.count
        if targetCount == 1 {
            return input[pos...].firstIndex(of: targetUtf8[0])
        }
        let lastStart = end - targetCount
        if pos > lastStart { return nil }

        let first = targetUtf8[0]
        if targetCount == 2 {
            let second = targetUtf8[1]
            var start = pos
            while start <= lastStart {
                guard let firstCharIx = input[start...lastStart].firstIndex(of: first) else { return nil }
                let nextIx = firstCharIx + 1
                if input[nextIx] == second {
                    return firstCharIx
                }
                start = firstCharIx + 1
            }
            return nil
        }

        if targetCount == 3 {
            let second = targetUtf8[1]
            let third = targetUtf8[2]
            var start = pos
            while start <= lastStart {
                guard let firstCharIx = input[start...lastStart].firstIndex(of: first) else { return nil }
                let nextIx = firstCharIx + 1
                if input[nextIx] == second && input[nextIx + 1] == third {
                    return firstCharIx
                }
                start = firstCharIx + 1
            }
            return nil
        }

        var start = pos
        while start <= lastStart {
            guard let firstCharIx = input[start...lastStart].firstIndex(of: first) else { return nil }
            var current = firstCharIx + 1
            var matched = true
            var j = 1
            while j < targetCount {
                if input[current] != targetUtf8[j] {
                    matched = false
                    break
                }
                current += 1
                j += 1
            }
            if matched {
                return firstCharIx
            }
            start = firstCharIx + 1
        }
        return nil
    }

    public func consumeToAnyOfTwo(_ a: UInt8, _ b: UInt8) -> ArraySlice<UInt8> {
        #if PROFILE
        let _p = Profiler.start("CharacterReader.consumeToAnyOfTwo")
        defer { Profiler.end("CharacterReader.consumeToAnyOfTwo", _p) }
        #endif
        let start = pos
        let count = end - pos
        if count <= 0 {
            return input[start..<pos]
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 32 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                @inline(__always)
                func memchrMin(_ len: Int) -> ArraySlice<UInt8> {
                    let startPtr = basePtr.advanced(by: pos)
                    let startRaw = UnsafeRawPointer(startPtr)
                    let pa = memchr(startPtr, Int32(a), len)
                    let pb = (a == b) ? nil : memchr(startPtr, Int32(b), len)
                    var minOff = len
                    if let pa {
                        let off = Int(bitPattern: pa) - Int(bitPattern: startRaw)
                        if off < minOff { minOff = off }
                    }
                    if let pb {
                        let off = Int(bitPattern: pb) - Int(bitPattern: startRaw)
                        if off < minOff { minOff = off }
                    }
                    if minOff != len {
                        pos = start + minOff
                        return input[start..<pos]
                    }
                    pos = end
                    return input[start..<pos]
                }
                if count >= 256 {
                    return memchrMin(count)
                }
                if count >= 64 {
                    @inline(__always)
                    func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                        let mask = byte &* 0x0101010101010101
                        let x = word ^ mask
                        return ((x &- 0x0101010101010101) & ~x & 0x8080808080808080) != 0
                    }
                    let aWord = UInt64(a)
                    let bWord = UInt64(b)
                    let baseAddress = UInt(bitPattern: basePtr)
                    var i = pos
                    while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                        let byte = basePtr[i]
                        if byte == a || byte == b {
                            pos = i
                            return input[start..<pos]
                        }
                        i &+= 1
                    }
                    let endWord = end &- 8
                    while i <= endWord {
                        let word = UnsafeRawPointer(basePtr.advanced(by: i)).load(as: UInt64.self)
                        var hit = hasByte(word, aWord)
                        if !hit && a != b {
                            hit = hasByte(word, bWord)
                        }
                        if hit { break }
                        i &+= 8
                    }
                    while i < end {
                        let byte = basePtr[i]
                        if byte == a || byte == b {
                            pos = i
                            return input[start..<pos]
                        }
                        i &+= 1
                    }
                    pos = end
                    return input[start..<pos]
                }
                return memchrMin(count)
            }
        }
        #endif
        while pos < end {
            let byte = input[pos]
            if byte == a || byte == b {
                return input[start..<pos]
            }
            pos &+= 1
        }
        return input[start..<pos]
    }

    @inline(__always)
    public func consumeToAnyOfOne(_ a: UInt8) -> ArraySlice<UInt8> {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return input[start..<pos]
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 64 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* 0x0101010101010101
                    let x = word ^ mask
                    return ((x &- 0x0101010101010101) & ~x & 0x8080808080808080) != 0
                }
                let aWord = UInt64(a)
                let baseAddress = UInt(bitPattern: basePtr)
                var i = pos
                while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                    if basePtr[i] == a {
                        pos = i
                        return input[start..<pos]
                    }
                    i &+= 1
                }
                let endWord = end &- 8
                while i <= endWord {
                    let word = UnsafeRawPointer(basePtr.advanced(by: i)).load(as: UInt64.self)
                    if hasByte(word, aWord) { break }
                    i &+= 8
                }
                while i < end {
                    if basePtr[i] == a {
                        pos = i
                        return input[start..<pos]
                    }
                    i &+= 1
                }
                pos = end
                return input[start..<pos]
            }
        }
        if count >= 32 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                let startPtr = basePtr.advanced(by: pos)
                if let pa = memchr(startPtr, Int32(a), count) {
                    let off = Int(bitPattern: pa) - Int(bitPattern: startPtr)
                    pos = start + off
                    return input[start..<pos]
                }
                pos = end
                return input[start..<pos]
            }
        }
        #endif
        while pos < end {
            if input[pos] == a {
                return input[start..<pos]
            }
            pos &+= 1
        }
        return input[start..<pos]
    }

    @inline(__always)
    public func consumeToAnyOfThree(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> ArraySlice<UInt8> {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return input[start..<pos]
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 64 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* 0x0101010101010101
                    let x = word ^ mask
                    return ((x &- 0x0101010101010101) & ~x & 0x8080808080808080) != 0
                }
                let aWord = UInt64(a)
                let bWord = UInt64(b)
                let cWord = UInt64(c)
                let baseAddress = UInt(bitPattern: basePtr)
                var i = pos
                while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                    let byte = basePtr[i]
                    if byte == a || byte == b || byte == c {
                        pos = i
                        return input[start..<pos]
                    }
                    i &+= 1
                }
                let endWord = end &- 8
                while i <= endWord {
                    let word = UnsafeRawPointer(basePtr.advanced(by: i)).load(as: UInt64.self)
                    var hit = hasByte(word, aWord)
                    if !hit && a != b {
                        hit = hasByte(word, bWord)
                    }
                    if !hit && c != a && c != b {
                        hit = hasByte(word, cWord)
                    }
                    if hit { break }
                    i &+= 8
                }
                while i < end {
                    let byte = basePtr[i]
                    if byte == a || byte == b || byte == c {
                        pos = i
                        return input[start..<pos]
                    }
                    i &+= 1
                }
                pos = end
                return input[start..<pos]
            }
        }
        if count >= 32 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                let startPtr = basePtr.advanced(by: pos)
                let startRaw = UnsafeRawPointer(startPtr)
                let len = count
                let pa = memchr(startPtr, Int32(a), len)
                let pb = (a == b) ? nil : memchr(startPtr, Int32(b), len)
                let pc = (a == c || b == c) ? nil : memchr(startPtr, Int32(c), len)
                var minOff = len
                if let pa {
                    let off = Int(bitPattern: pa) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if let pb {
                    let off = Int(bitPattern: pb) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if let pc {
                    let off = Int(bitPattern: pc) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if minOff != len {
                    pos = start + minOff
                    return input[start..<pos]
                }
                pos = end
                return input[start..<pos]
            }
        }
        #endif
        while pos < end {
            let byte = input[pos]
            if byte == a || byte == b || byte == c {
                return input[start..<pos]
            }
            pos &+= 1
        }
        return input[start..<pos]
    }

    @inline(__always)
    public func consumeToAnyOfFour(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> ArraySlice<UInt8> {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return input[start..<pos]
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 64 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* 0x0101010101010101
                    let x = word ^ mask
                    return ((x &- 0x0101010101010101) & ~x & 0x8080808080808080) != 0
                }
                let aWord = UInt64(a)
                let bWord = UInt64(b)
                let cWord = UInt64(c)
                let dWord = UInt64(d)
                let baseAddress = UInt(bitPattern: basePtr)
                var i = pos
                while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                    let byte = basePtr[i]
                    if byte == a || byte == b || byte == c || byte == d {
                        pos = i
                        return input[start..<pos]
                    }
                    i &+= 1
                }
                let endWord = end &- 8
                while i <= endWord {
                    let word = UnsafeRawPointer(basePtr.advanced(by: i)).load(as: UInt64.self)
                    var hit = hasByte(word, aWord)
                    if !hit && a != b {
                        hit = hasByte(word, bWord)
                    }
                    if !hit && c != a && c != b {
                        hit = hasByte(word, cWord)
                    }
                    if !hit && d != a && d != b && d != c {
                        hit = hasByte(word, dWord)
                    }
                    if hit { break }
                    i &+= 8
                }
                while i < end {
                    let byte = basePtr[i]
                    if byte == a || byte == b || byte == c || byte == d {
                        pos = i
                        return input[start..<pos]
                    }
                    i &+= 1
                }
                pos = end
                return input[start..<pos]
            }
        }
        if count >= 32 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                let startPtr = basePtr.advanced(by: pos)
                let startRaw = UnsafeRawPointer(startPtr)
                let len = count
                let pa = memchr(startPtr, Int32(a), len)
                let pb = (a == b) ? nil : memchr(startPtr, Int32(b), len)
                let pc = (a == c || b == c) ? nil : memchr(startPtr, Int32(c), len)
                let pd = (a == d || b == d || c == d) ? nil : memchr(startPtr, Int32(d), len)
                var minOff = len
                if let pa {
                    let off = Int(bitPattern: pa) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if let pb {
                    let off = Int(bitPattern: pb) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if let pc {
                    let off = Int(bitPattern: pc) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if let pd {
                    let off = Int(bitPattern: pd) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if minOff != len {
                    pos = start + minOff
                    return input[start..<pos]
                }
                pos = end
                return input[start..<pos]
            }
        }
        #endif
        while pos < end {
            let byte = input[pos]
            if byte == a || byte == b || byte == c || byte == d {
                return input[start..<pos]
            }
            pos &+= 1
        }
        return input[start..<pos]
    }

    @inline(__always)
    public func advanceAsciiWhitespace() {
        while pos < end && input[pos].isWhitespace {
            pos &+= 1
        }
    }

    public static let dataTerminators = ParsingStrings([.Ampersand, .LessThan, TokeniserStateVars.nullScalr])

    @inline(__always)
    public func consumeData() -> ArraySlice<UInt8> {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return input[start..<pos]
        }

        let useNoNullFastPath = self.useNoNullFastPath

        // Small unrolled scan for short runs before falling back to memchr.
        var i = pos
        let scanEnd = min(end, pos + 16)
        if useNoNullFastPath {
            while i < scanEnd {
                let b = input[i]
                if b == TokeniserStateVars.ampersandByte || b == TokeniserStateVars.lessThanByte { // &, <
                    pos = i
                    return input[start..<pos]
                }
                i &+= 1
            }
        } else {
            while i < scanEnd {
                let b = input[i]
                if b == TokeniserStateVars.ampersandByte || b == TokeniserStateVars.lessThanByte || b == TokeniserStateVars.nullByte { // &, <, null
                    pos = i
                    return input[start..<pos]
                }
                i &+= 1
            }
        }
        pos = i
        if pos >= end {
            return input[start..<pos]
        }

        let remaining = end - pos
        #if canImport(Darwin) || canImport(Glibc)
        if remaining >= 32 {
            return input.withUnsafeBytes { buf in
                guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                    return input[start..<pos]
                }
                let startPtr = basePtr.advanced(by: pos)
                let startRaw = UnsafeRawPointer(startPtr)
                let len = end - pos
                var minOff = len
                let pa = memchr(startPtr, Int32(TokeniserStateVars.ampersandByte), len) // &
                let pb = memchr(startPtr, Int32(TokeniserStateVars.lessThanByte), len) // <
                if let pa {
                    let off = Int(bitPattern: pa) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if let pb {
                    let off = Int(bitPattern: pb) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if !useNoNullFastPath, let pc = memchr(startPtr, Int32(TokeniserStateVars.nullByte), len) {
                    let off = Int(bitPattern: pc) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if minOff != len {
                    pos = pos + minOff
                    return input[start..<pos]
                }
                pos = end
                return input[start..<pos]
            }
        }
        // No mid-tier memchr: default to scalar loop for short remaining spans.
        #endif

        if useNoNullFastPath {
            while pos < end {
                let b = input[pos]
                if b == TokeniserStateVars.ampersandByte || b == TokeniserStateVars.lessThanByte { // &, <
                    return input[start..<pos]
                }
                pos &+= 1
            }
        } else {
            while pos < end {
                let b = input[pos]
                if b == TokeniserStateVars.ampersandByte || b == TokeniserStateVars.lessThanByte || b == TokeniserStateVars.nullByte { // &, <, null
                    return input[start..<pos]
                }
                pos &+= 1
            }
        }
        return input[start..<pos]
    }

    @inline(__always)
    public func consumeDataFastNoNull() -> ArraySlice<UInt8> {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return input[start..<pos]
        }
        #if canImport(Darwin) || canImport(Glibc)
        return input.withUnsafeBytes { buf in
            guard let basePtr = buf.bindMemory(to: UInt8.self).baseAddress else {
                return input[start..<pos]
            }
            let startPtr = basePtr.advanced(by: start)
            let len = count
            let pa = memchr(startPtr, Int32(TokeniserStateVars.ampersandByte), len) // &
            let pb = memchr(startPtr, Int32(TokeniserStateVars.lessThanByte), len) // <
            if pa == nil && pb == nil {
                pos = end
                return input[start..<pos]
            }
            let target: UnsafeMutableRawPointer
            if let pa = pa, let pb = pb {
                target = (pa < pb) ? pa : pb
            } else if let pa = pa {
                target = pa
            } else {
                target = pb!
            }
            let offset = Int(bitPattern: target) - Int(bitPattern: startPtr)
            pos = start + offset
            return input[start..<pos]
        }
        #else
        return consumeData()
        #endif
    }
    
    public static let tagNameTerminators = ParsingStrings([.BackslashT, .BackslashN, .BackslashR, .BackslashF, .Space, .Slash, .GreaterThan, TokeniserStateVars.nullScalr])
    public static let tagNameDelims: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        table[Int(TokeniserStateVars.tabByte)] = true // \t
        table[Int(TokeniserStateVars.newLineByte)] = true // \n
        table[Int(TokeniserStateVars.carriageReturnByte)] = true // \r
        table[Int(TokeniserStateVars.formFeedByte)] = true // \f
        table[Int(TokeniserStateVars.spaceByte)] = true // space
        table[Int(TokeniserStateVars.slashByte)] = true // /
        table[Int(TokeniserStateVars.greaterThanByte)] = true // >
        table[Int(TokeniserStateVars.nullByte)] = true // null
        return table
    }()
    public static let attributeValueUnquotedDelims: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        table[Int(TokeniserStateVars.tabByte)] = true // \t
        table[Int(TokeniserStateVars.newLineByte)] = true // \n
        table[Int(TokeniserStateVars.carriageReturnByte)] = true // \r
        table[Int(TokeniserStateVars.formFeedByte)] = true // \f
        table[Int(TokeniserStateVars.spaceByte)] = true // space
        table[Int(TokeniserStateVars.ampersandByte)] = true // &
        table[Int(TokeniserStateVars.greaterThanByte)] = true // >
        table[Int(TokeniserStateVars.nullByte)] = true // null
        table[Int(TokeniserStateVars.quoteByte)] = true // "
        table[Int(TokeniserStateVars.apostropheByte)] = true // '
        table[Int(TokeniserStateVars.lessThanByte)] = true // <
        table[Int(TokeniserStateVars.equalSignByte)] = true // =
        table[Int(TokeniserStateVars.backtickByte)] = true // `
        return table
    }()

    public static let attributeValueDoubleQuotedDelims: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        table[Int(TokeniserStateVars.quoteByte)] = true // "
        table[Int(TokeniserStateVars.ampersandByte)] = true // &
        table[Int(TokeniserStateVars.nullByte)] = true // null
        return table
    }()

    public static let attributeValueSingleQuotedDelims: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        table[Int(TokeniserStateVars.apostropheByte)] = true // '
        table[Int(TokeniserStateVars.ampersandByte)] = true // &
        table[Int(TokeniserStateVars.nullByte)] = true // null
        return table
    }()
    public static let attributeNameDelims: [Bool] = {
        var table = [Bool](repeating: false, count: 256)
        table[Int(TokeniserStateVars.tabByte)] = true // \t
        table[Int(TokeniserStateVars.newLineByte)] = true // \n
        table[Int(TokeniserStateVars.carriageReturnByte)] = true // \r
        table[Int(TokeniserStateVars.formFeedByte)] = true // \f
        table[Int(TokeniserStateVars.spaceByte)] = true // space
        table[Int(TokeniserStateVars.slashByte)] = true // /
        table[Int(TokeniserStateVars.equalSignByte)] = true // =
        table[Int(TokeniserStateVars.greaterThanByte)] = true // >
        table[Int(TokeniserStateVars.nullByte)] = true // null
        table[Int(TokeniserStateVars.quoteByte)] = true // "
        table[Int(TokeniserStateVars.apostropheByte)] = true // '
        table[Int(TokeniserStateVars.lessThanByte)] = true // <
        return table
    }()
    
    @inlinable
    public func consumeTagName() -> ArraySlice<UInt8> {
        return consumeTagNameWithUppercaseFlag().0
    }

    @inline(__always)
    public func consumeTagNameWithUppercaseFlag() -> (ArraySlice<UInt8>, Bool) {
        // Fast path for ASCII tag names
        if pos < end && input[pos] < 0x80 {
            let start = pos
            var i = pos
            var hasUppercase = false
            while i < end {
                let b = input[i]
                if b >= 0x80 {
                    let slice: ArraySlice<UInt8> = consumeToAny(CharacterReader.tagNameTerminators)
                    return (slice, Attributes.containsAsciiUppercase(slice))
                }
                if CharacterReader.tagNameDelims[Int(b)] {
                    pos = i
                    return (input[start..<pos], hasUppercase)
                }
                if !hasUppercase && b >= 65 && b <= 90 {
                    hasUppercase = true
                }
                i &+= 1
            }
            pos = i
            return (input[start..<pos], hasUppercase)
        }
        let slice: ArraySlice<UInt8> = consumeToAny(CharacterReader.tagNameTerminators)
        return (slice, Attributes.containsAsciiUppercase(slice))
    }


    public func consumeAttributeName() -> ArraySlice<UInt8> {
        // Fast path for ASCII attribute names
        if pos < end && input[pos] < 0x80 {
            let start = pos
            var i = pos
            while i < end {
                let b = input[i]
                if b >= 0x80 {
                    return consumeToAny(TokeniserStateVars.attributeNameChars)
                }
                if CharacterReader.attributeNameDelims[Int(b)] {
                    pos = i
                    return input[start..<pos]
                }
                i &+= 1
            }
            pos = i
            return input[start..<pos]
        }
        return consumeToAny(TokeniserStateVars.attributeNameChars)
    }


    @inline(__always)
    public func consumeAttributeValueUnquoted() -> ArraySlice<UInt8> {
        let start = pos
        while pos < end {
            let byte = input[pos]
            if CharacterReader.attributeValueUnquotedDelims[Int(byte)] {
                return input[start..<pos]
            }
            pos &+= 1
        }
        return input[start..<pos]
    }

    @inline(__always)
    public func consumeAttributeValueDoubleQuoted() -> ArraySlice<UInt8> {
        if canSkipNullCheck {
            return consumeToAnyOfTwo(TokeniserStateVars.quoteByte, TokeniserStateVars.ampersandByte)
        }
        return consumeToAnyOfThree(TokeniserStateVars.quoteByte, TokeniserStateVars.ampersandByte, TokeniserStateVars.nullByte)
    }

    @inline(__always)
    public func consumeAttributeValueSingleQuoted() -> ArraySlice<UInt8> {
        if canSkipNullCheck {
            return consumeToAnyOfTwo(TokeniserStateVars.apostropheByte, TokeniserStateVars.ampersandByte)
        }
        return consumeToAnyOfThree(TokeniserStateVars.apostropheByte, TokeniserStateVars.ampersandByte, TokeniserStateVars.nullByte)
    }
}

extension CharacterReader: CustomDebugStringConvertible {
    public var debugDescription: String {
        return toString()
    }
}
