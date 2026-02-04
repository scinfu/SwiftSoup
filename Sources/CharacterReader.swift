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
    public let input: UnsafeBufferPointer<UInt8>
    private var storage: ByteStorage?
    private let owner: AnyObject?
    public var pos: Int
    private var mark: Int
    private let start: Int
    public let end: Int
    
    private static let letters = ParsingStrings("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) })
    private static let digits = ParsingStrings(["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"])
    @usableFromInline
    static let asciiUpperLimitByte: UInt8 = TokeniserStateVars.asciiUpperLimitByte
    @usableFromInline
    static let asciiMaxScalar: UInt32 = 0x7F
    @usableFromInline
    static let utf8Lead2Min: UInt8 = 0xC0
    @usableFromInline
    static let utf8Lead2Max: UInt8 = 0xDF
    @usableFromInline
    static let utf8Lead3Min: UInt8 = 0xE0
    @usableFromInline
    static let utf8Lead3Max: UInt8 = 0xEF
    @usableFromInline
    static let utf8Lead4Min: UInt8 = 0xF0
    @usableFromInline
    static let utf8Lead4Max: UInt8 = 0xF7
    @usableFromInline
    static let utf8Lead2Mask: UInt8 = 0xE0
    @usableFromInline
    static let utf8Lead3Mask: UInt8 = 0xF0
    @usableFromInline
    static let utf8Lead4Mask: UInt8 = 0xF8
    @usableFromInline
    static let utf8ContinuationMask: UInt8 = 0xC0
    @usableFromInline
    static let utf8ContinuationValue: UInt8 = 0x80
    @usableFromInline
    static let repeatedByteMask: UInt64 = 0x0101010101010101
    @usableFromInline
    static let highBitRepeatMask: UInt64 = 0x8080808080808080
    private static let utf8WidthTable: [UInt8] = {
        var table = [UInt8](repeating: 1, count: 256)
        var i = Int(utf8Lead2Min)
        let lead2Max = Int(utf8Lead2Max)
        while i <= lead2Max {
            table[i] = 2
            i += 1
        }
        i = Int(utf8Lead3Min)
        let lead3Max = Int(utf8Lead3Max)
        while i <= lead3Max {
            table[i] = 3
            i += 1
        }
        i = Int(utf8Lead4Min)
        let lead4Max = Int(utf8Lead4Max)
        while i <= lead4Max {
            table[i] = 4
            i += 1
        }
        return table
    }()
    
    public init(_ input: [UInt8]) {
        self.storage = ByteStorage(array: input)
        self.owner = nil
        var base: UnsafePointer<UInt8>? = nil
        input.withUnsafeBufferPointer { buf in
            base = buf.baseAddress
        }
        self.input = UnsafeBufferPointer(start: base, count: input.count)
        self.start = 0
        self.pos = 0
        self.mark = 0
        self.end = input.count
    }

    init(_ input: UnsafeBufferPointer<UInt8>, storage: ByteStorage? = nil, owner: AnyObject? = nil) {
        self.storage = storage
        self.owner = owner
        self.input = input
        self.start = 0
        self.pos = 0
        self.mark = 0
        self.end = input.count
    }

    public convenience init(_ input: UnsafeBufferPointer<UInt8>, owner: AnyObject? = nil) {
        self.init(input, storage: nil, owner: owner)
    }
    
    public convenience init(_ input: String) {
        self.init(input.utf8Array)
    }

    @usableFromInline
    @inline(__always)
    func slice(_ start: Int, _ end: Int) -> ByteSlice {
        if let storage {
            return ByteSlice(storage: storage, start: start, end: end)
        }
        let array = Array(input)
        let storage = ByteStorage(array: array)
        self.storage = storage
        return ByteSlice(storage: storage, start: start, end: end)
    }

    public func getPos() -> Int {
        return pos
    }
    
    public func isEmpty() -> Bool {
        return pos >= end
    }
    
    public func current() -> UnicodeScalar {
        guard pos < end else { return CharacterReader.EOF }

        let firstByte = input[pos]
        if firstByte < Self.asciiUpperLimitByte {
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
    
    func currentUTF8Slice() -> ByteSlice {
        guard pos < end else { return TokeniserStateVars.eofUTF8Slice }
        
        let firstByte = input[pos]

        let length: Int
        
        // Determine UTF-8 sequence length based on the first byte
        if firstByte & Self.asciiUpperLimitByte == 0 { // 1-byte ASCII (0xxxxxxx)
            length = 1
        } else if firstByte & Self.utf8Lead2Mask == Self.utf8Lead2Min { // 2-byte sequence (110xxxxx)
            length = 2
        } else if firstByte & Self.utf8Lead3Mask == Self.utf8Lead3Min { // 3-byte sequence (1110xxxx)
            length = 3
        } else if firstByte & Self.utf8Lead4Mask == Self.utf8Lead4Min { // 4-byte sequence (11110xxx)
            length = 4
        } else {
            return ByteSlice.empty // Invalid UTF-8 leading byte
        }
        
        // Ensure there are enough bytes remaining in `input`
        if pos + length > end {
            return ByteSlice.empty // Incomplete UTF-8 sequence
        }
        
        // Validate continuation bytes (they should all be 10xxxxxx)
        for i in 1..<length {
            if input[pos + i] & Self.utf8ContinuationMask != Self.utf8ContinuationValue {
                return ByteSlice.empty // Invalid UTF-8 sequence
            }
        }
        
        // Return the valid UTF-8 byte sequence
        return slice(pos, pos + length)
    }

    public func currentUTF8() -> ArraySlice<UInt8> {
        return currentUTF8Slice().toArraySlice()
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
        if firstByte < Self.asciiUpperLimitByte {
            pos += 1
            return UnicodeScalar(firstByte)
        }

        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            let scalarLength = UTF8.width(scalar)
            pos += scalarLength
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
            index -= 1
            var iterator = input[index..<pos].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar):
                scalarLength = UTF8.width(scalar)
                pos -= scalarLength
                return
            case .emptyInput, .error:
                break // Continue moving back until a valid scalar is found
            }
        }
    }
    
    public func advance() {
        guard pos < end else { return }
        let firstByte = input[pos]
        if firstByte < Self.asciiUpperLimitByte {
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
        if firstByte < Self.asciiUpperLimitByte {
            pos += 1
            return String(UnicodeScalar(firstByte))
        }

        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            let scalarLength = UTF8.width(scalar)
            pos += scalarLength
            return String(scalar)
        case .emptyInput, .error:
            return ""
        }
    }
    
    @inline(__always)
    func consumeToAnySlice(_ chars: ParsingStrings) -> String {
        return String(decoding: consumeToAnySlice(chars), as: UTF8.self)
    }
    
    @inline(__always)
    func consumeToAnySlice(_ chars: ParsingStrings) -> ByteSlice {
        let start = pos
        if chars.isSingleByteOnly {
            switch chars.singleByteCount {
            case 1:
                return consumeToAnyOfOneSlice(chars.singleByteList[0])
            case 2:
                return consumeToAnyOfTwoSlice(chars.singleByteList[0], chars.singleByteList[1])
            case 3:
                return consumeToAnyOfThreeSlice(chars.singleByteList[0], chars.singleByteList[1], chars.singleByteList[2])
            case 4:
                return consumeToAnyOfFourSlice(chars.singleByteList[0], chars.singleByteList[1], chars.singleByteList[2], chars.singleByteList[3])
            default:
                break
            }
            while pos < end {
                let byte = input[pos]
                if testBit(chars.singleByteMask, byte) {
                    return slice(start, pos)
                }
                pos &+= 1
            }
            return slice(start, pos)
        }

        while pos < end {
            // Skip continuation bytes
            if input[pos] & 0b11000000 == 0b10000000 {
                pos += 1
                continue
            }

            let firstByte = input[pos]
            if firstByte < Self.asciiUpperLimitByte {
                if chars.contains(firstByte) {
                    return slice(start, pos)
                }
                pos += 1
                continue
            }

            let charLen = firstByte < Self.utf8Lead3Min ? 2 : firstByte < Self.utf8Lead4Min ? 3 : 4

            // Check if the current multi-byte sequence matches any character in `chars`
            if chars.contains(slice(pos, min(pos + charLen, end))) {
                return slice(start, pos)
            }

            pos += charLen
        }
        
        return slice(start, pos)
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
    
    func consumeToSlice(_ c: UnicodeScalar) -> ByteSlice {
        if c.value <= Self.asciiMaxScalar {
            let byte = UInt8(c.value)
            return consumeToAnyOfOneSlice(byte)
        }
        var buffer = [UInt8](repeating: 0, count: 4)
        var length = 0
        for b in c.utf8 {
            buffer[length] = b
            length &+= 1
        }
        if length == 0 { return consumeToEndUTF8Slice() }
        let target = Array(buffer[..<length])
        guard let targetIx = nextIndexOf(target) else { return consumeToEndUTF8Slice() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    @inline(__always)
    func consumeToSlice(_ seq: String) -> String {
        return String(decoding: consumeToSlice(seq.utf8Array), as: UTF8.self)
    }
    
    func consumeToSlice(_ seq: [UInt8]) -> ByteSlice {
        if seq.count == 1 {
            return consumeToAnyOfOneSlice(seq[0])
        }
        guard let targetIx = nextIndexOf(seq) else { return consumeToEndUTF8Slice() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    @inline(__always)
    public func consumeToEnd() -> String {
        return String(decoding: consumeToEndUTF8Slice(), as: UTF8.self)
    }
    
    @inline(__always)
    func consumeToEndUTF8Slice() -> ByteSlice {
        let consumed = cacheString(pos, end)
        pos = end
        return consumed
    }
    
    func consumeLetterSequenceSlice() -> ByteSlice {
        let start = pos
        while pos < end {
            let firstByte = input[pos]
            if firstByte < Self.asciiUpperLimitByte {
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
            if firstByte < Self.asciiUpperLimitByte {
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
                pos += scalarLength
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    func consumeLetterThenDigitSequenceSlice() -> ByteSlice {
        let start = pos
        letterLoop: while pos < end {
            let firstByte = input[pos]
            if firstByte < Self.asciiUpperLimitByte {
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
            if firstByte < Self.asciiUpperLimitByte {
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
                pos += scalarLength
            default:
                break letterLoop
            }
        }
        
        digitLoop: while pos < end {
            let firstByte = input[pos]
            if firstByte < Self.asciiUpperLimitByte {
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
            if firstByte < Self.asciiUpperLimitByte {
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
                pos += scalarLength
            default:
                break digitLoop
            }
        }
        
        return cacheString(start, pos)
    }
    
    func consumeHexSequenceSlice() -> ByteSlice {
        let start = pos
        while pos < end {
            let firstByte = input[pos]
            if firstByte < Self.asciiUpperLimitByte {
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
            if firstByte < Self.asciiUpperLimitByte {
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
                pos += scalarLength
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    func consumeDigitSequenceSlice() -> ByteSlice {
        let start = pos
        while pos < end {
            let firstByte = input[pos]
            if firstByte < Self.asciiUpperLimitByte {
                if firstByte >= 48 && firstByte <= 57 {
                    pos += 1
                    continue
                }
                return cacheString(start, pos)
            }

            let slice = currentUTF8Slice()
            if slice.isEmpty { return cacheString(start, pos) }
            var iterator = slice.makeIterator()
            var utf8Decoder = UTF8()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.decimalDigits.contains(scalar):
                pos += slice.count
            case .scalarValue, .emptyInput, .error:
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    @inline(__always)
    public func matches(_ c: UnicodeScalar) -> Bool {
        guard pos < end else { return false }
        if c.value < Self.asciiUpperLimitByte {
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
        let endIndex = pos + seq.count
        guard endIndex <= end else { return false }

        if !ignoreCase {
            if input[pos..<endIndex].elementsEqual(seq) {
                if consume { pos = endIndex }
                return true
            }
            return false
        }

        var allAscii = true
        for b in seq where b & Self.asciiUpperLimitByte != 0 {
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
                idx += 1
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
                current += scalarLength
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

        if let byte = currentByte(), byte < Self.asciiUpperLimitByte {
            return seq.contains(byte)
        }
        if seq.isSingleByteOnly {
            guard let byte = currentByte() else { return false }
            return seq.contains(byte)
        }

        let slice = currentUTF8Slice()
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

        let slice = currentUTF8Slice()
        if slice.isEmpty { return false }
        for utf8Bytes in seq where utf8Bytes.count == slice.count {
            if utf8Bytes.elementsEqual(slice) { return true }
        }
        return false
    }
    
    public func matchesLetter() -> Bool {
        guard pos < end else { return false }
        
        let firstByte = input[pos]
        if firstByte < Self.asciiUpperLimitByte {
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
        
        return Self.letters.contains(slice(pos, pos + length))
    }
    
    public func matchesDigit() -> Bool {
        guard pos < end,
              input.count > pos
        else { return false }

        let firstByte = input[pos]
        if firstByte < Self.asciiUpperLimitByte {
            return firstByte >= 48 && firstByte <= 57
        }

        let slice = currentUTF8Slice()
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
        for b in seq where b & Self.asciiUpperLimitByte != 0 {
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
        for b in prefix where b & Self.asciiUpperLimitByte != 0 {
            allAscii = false
            break
        }
        if allAscii {
            for b in suffix where b & Self.asciiUpperLimitByte != 0 {
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
    private func cacheString(_ start: Int, _ end: Int) -> ByteSlice {
        return slice(start, end)
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
        let byteOffset = targetIx
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        return utf8View.index(utf8View.startIndex, offsetBy: byteOffset)
    }
    
    public func nextIndexOf(_ seq: String) -> String.UTF8View.Index? {
        let targetUtf8 = seq.utf8Array
        guard let targetIx = nextIndexOf(targetUtf8) else { return nil }
        let byteOffset = targetIx
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        return utf8View.index(utf8View.startIndex, offsetBy: byteOffset)
    }

    public func nextIndexOf(_ targetUtf8: [UInt8]) -> Int? {
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

    func consumeToAnyOfTwoSlice(_ a: UInt8, _ b: UInt8) -> ByteSlice {
        #if PROFILE
        let _p = Profiler.start("CharacterReader.consumeToAnyOfTwoSlice")
        defer { Profiler.end("CharacterReader.consumeToAnyOfTwoSlice", _p) }
        #endif
        if a == b {
            return consumeToAnyOfOneSlice(a)
        }
        let start = pos
        let count = end - pos
        if count <= 0 {
            return slice(start, pos)
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 16 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
            }
                @inline(__always)
                func memchrMin(_ len: Int) -> ByteSlice {
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
                        return slice(start, pos)
                    }
                    pos = end
                    return slice(start, pos)
                }
                if count >= 128 {
                    @inline(__always)
                    func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                        let mask = byte &* Self.repeatedByteMask
                        let x = word ^ mask
                        return ((x &- Self.repeatedByteMask) & ~x & Self.highBitRepeatMask) != 0
                    }
                    let aWord = UInt64(a)
                    let bWord = UInt64(b)
                    let baseAddress = UInt(bitPattern: basePtr)
                    var i = pos
                    while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                        let byte = basePtr[i]
                        if byte == a || byte == b {
                            pos = i
                            return slice(start, pos)
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
                            return slice(start, pos)
                        }
                        i &+= 1
                    }
                    pos = end
                    return slice(start, pos)
                }
                return memchrMin(count)
        }
        #endif
        while pos < end {
            let byte = input[pos]
            if byte == a || byte == b {
                return slice(start, pos)
            }
            pos &+= 1
        }
        return slice(start, pos)
    }

    @inline(__always)
    func consumeToAnyOfOneSlice(_ a: UInt8) -> ByteSlice {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return slice(start, pos)
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 64 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
            }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* Self.repeatedByteMask
                    let x = word ^ mask
                    return ((x &- Self.repeatedByteMask) & ~x & Self.highBitRepeatMask) != 0
                }
                let aWord = UInt64(a)
                let baseAddress = UInt(bitPattern: basePtr)
                var i = pos
                while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                    if basePtr[i] == a {
                        pos = i
                        return slice(start, pos)
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
                        return slice(start, pos)
                    }
                    i &+= 1
                }
                pos = end
                return slice(start, pos)
        }
        if count >= 32 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
            }
                let startPtr = basePtr.advanced(by: pos)
                if let pa = memchr(startPtr, Int32(a), count) {
                    let off = Int(bitPattern: pa) - Int(bitPattern: startPtr)
                    pos = start + off
                    return slice(start, pos)
                }
                pos = end
                return slice(start, pos)
        }
        #endif
        while pos < end {
            if input[pos] == a {
                return slice(start, pos)
            }
            pos &+= 1
        }
        return slice(start, pos)
    }

    @inline(__always)
    func consumeToAnyOfThreeSlice(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> ByteSlice {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return slice(start, pos)
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 64 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
            }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* Self.repeatedByteMask
                    let x = word ^ mask
                    return ((x &- Self.repeatedByteMask) & ~x & Self.highBitRepeatMask) != 0
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
                        return slice(start, pos)
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
                        return slice(start, pos)
                    }
                    i &+= 1
                }
                pos = end
                return slice(start, pos)
        }
        if count >= 32 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
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
                    return slice(start, pos)
                }
                pos = end
                return slice(start, pos)
        }
        #endif
        while pos < end {
            let byte = input[pos]
            if byte == a || byte == b || byte == c {
                return slice(start, pos)
            }
            pos &+= 1
        }
        return slice(start, pos)
    }

    @inline(__always)
    func consumeToAnyOfFourSlice(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> ByteSlice {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return slice(start, pos)
        }
        #if canImport(Darwin) || canImport(Glibc)
        if count >= 64 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
            }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* Self.repeatedByteMask
                    let x = word ^ mask
                    return ((x &- Self.repeatedByteMask) & ~x & Self.highBitRepeatMask) != 0
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
                        return slice(start, pos)
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
                        return slice(start, pos)
                    }
                    i &+= 1
                }
                pos = end
                return slice(start, pos)
        }
        if count >= 32 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
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
                    return slice(start, pos)
                }
                pos = end
                return slice(start, pos)
        }
        #endif
        while pos < end {
            let byte = input[pos]
            if byte == a || byte == b || byte == c || byte == d {
                return slice(start, pos)
            }
            pos &+= 1
        }
        return slice(start, pos)
    }

    @inline(__always)
    public func advanceAsciiWhitespace() {
        while pos < end && input[pos].isWhitespace {
            pos &+= 1
        }
    }

    public static let dataTerminators = ParsingStrings([.Ampersand, .LessThan, TokeniserStateVars.nullScalr])

    @inline(__always)
    func consumeDataSlice() -> ByteSlice {
        let start = pos
        let count = end - pos
        if count <= 0 {
            return slice(start, pos)
        }

        // Small unrolled scan for short runs before falling back to memchr.
        var i = pos
        let scanEnd = min(end, pos + 16)
        while i < scanEnd {
            let b = input[i]
            if b == TokeniserStateVars.ampersandByte || b == TokeniserStateVars.lessThanByte || b == TokeniserStateVars.nullByte { // &, <, null
                pos = i
                return slice(start, pos)
            }
            i &+= 1
        }
        pos = i
        if pos >= end {
            return slice(start, pos)
        }

        let remaining = end - pos
        #if canImport(Darwin) || canImport(Glibc)
        if remaining >= 64 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
            }
                @inline(__always)
                func hasByte(_ word: UInt64, _ byte: UInt64) -> Bool {
                    let mask = byte &* Self.repeatedByteMask
                    let x = word ^ mask
                    return ((x &- Self.repeatedByteMask) & ~x & Self.highBitRepeatMask) != 0
                }
                let aWord = UInt64(TokeniserStateVars.ampersandByte)
                let bWord = UInt64(TokeniserStateVars.lessThanByte)
                let cWord = UInt64(TokeniserStateVars.nullByte)
                let baseAddress = UInt(bitPattern: basePtr)
                var i = pos
                while i < end && ((baseAddress &+ UInt(i)) & 7) != 0 {
                    let byte = basePtr[i]
                    if byte == TokeniserStateVars.ampersandByte ||
                        byte == TokeniserStateVars.lessThanByte ||
                        byte == TokeniserStateVars.nullByte {
                        pos = i
                        return slice(start, pos)
                    }
                    i &+= 1
                }
                let endWord = end &- 8
                while i <= endWord {
                    let word = UnsafeRawPointer(basePtr.advanced(by: i)).load(as: UInt64.self)
                    if hasByte(word, aWord) || hasByte(word, bWord) || hasByte(word, cWord) { break }
                    i &+= 8
                }
                while i < end {
                    let byte = basePtr[i]
                    if byte == TokeniserStateVars.ampersandByte ||
                        byte == TokeniserStateVars.lessThanByte ||
                        byte == TokeniserStateVars.nullByte {
                        pos = i
                        return slice(start, pos)
                    }
                    i &+= 1
                }
                pos = end
                return slice(start, pos)
        }
        if remaining >= 16 {
            guard let basePtr = input.baseAddress else {
                return slice(start, pos)
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
                if let pc = memchr(startPtr, Int32(TokeniserStateVars.nullByte), len) {
                    let off = Int(bitPattern: pc) - Int(bitPattern: startRaw)
                    if off < minOff { minOff = off }
                }
                if minOff != len {
                    pos = pos + minOff
                    return slice(start, pos)
                }
                pos = end
                return slice(start, pos)
        }
        // No mid-tier memchr: default to scalar loop for short remaining spans.
        #endif

        while pos < end {
            let b = input[pos]
            if b == TokeniserStateVars.ampersandByte || b == TokeniserStateVars.lessThanByte || b == TokeniserStateVars.nullByte { // &, <, null
                return slice(start, pos)
            }
            pos &+= 1
        }
        return slice(start, pos)
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
    
    func consumeTagNameSlice() -> ByteSlice {
        return consumeTagNameWithUppercaseFlagSlice().0
    }

    @inline(__always)
    func consumeTagNameWithUppercaseFlagSlice() -> (ByteSlice, Bool) {
        // Fast path for ASCII tag names
        if pos < end && input[pos] < Self.asciiUpperLimitByte {
            let start = pos
            var i = pos
            var hasUppercase = false
            while i < end {
                let b = input[i]
                if b >= Self.asciiUpperLimitByte {
                    let slice: ByteSlice = consumeToAnySlice(CharacterReader.tagNameTerminators)
                    return (slice, Attributes.containsAsciiUppercase(slice))
                }
                if CharacterReader.tagNameDelims[Int(b)] {
                    pos = i
                    return (slice(start, pos), hasUppercase)
                }
                if !hasUppercase && b >= 65 && b <= 90 {
                    hasUppercase = true
                }
                i &+= 1
            }
            pos = i
            return (slice(start, pos), hasUppercase)
        }
        let slice: ByteSlice = consumeToAnySlice(CharacterReader.tagNameTerminators)
        return (slice, Attributes.containsAsciiUppercase(slice))
    }


    func consumeAttributeNameSlice() -> ByteSlice {
        // Fast path for ASCII attribute names
        if pos < end && input[pos] < Self.asciiUpperLimitByte {
            let start = pos
            var i = pos
            while i < end {
                let b = input[i]
                if b >= Self.asciiUpperLimitByte {
                    return consumeToAnySlice(TokeniserStateVars.attributeNameChars)
                }
                if CharacterReader.attributeNameDelims[Int(b)] {
                    pos = i
                    return slice(start, pos)
                }
                i &+= 1
            }
            pos = i
            return slice(start, pos)
        }
        return consumeToAnySlice(TokeniserStateVars.attributeNameChars)
    }


    @inline(__always)
    func consumeAttributeValueUnquotedSlice() -> ByteSlice {
        let start = pos
        while pos < end {
            let byte = input[pos]
            if CharacterReader.attributeValueUnquotedDelims[Int(byte)] {
                return slice(start, pos)
            }
            pos &+= 1
        }
        return slice(start, pos)
    }

    @inline(__always)
    func consumeAttributeValueDoubleQuotedSlice() -> ByteSlice {
        return consumeToAnyOfThreeSlice(TokeniserStateVars.quoteByte, TokeniserStateVars.ampersandByte, TokeniserStateVars.nullByte)
    }

    @inline(__always)
    func consumeAttributeValueSingleQuotedSlice() -> ByteSlice {
        return consumeToAnyOfThreeSlice(TokeniserStateVars.apostropheByte, TokeniserStateVars.ampersandByte, TokeniserStateVars.nullByte)
    }

    // Public ArraySlice wrappers to preserve API.
    @inline(__always)
    public func consumeToAny(_ chars: ParsingStrings) -> ArraySlice<UInt8> {
        return consumeToAnySlice(chars).toArraySlice()
    }

    @inline(__always)
    public func consumeTo(_ c: UnicodeScalar) -> ArraySlice<UInt8> {
        return consumeToSlice(c).toArraySlice()
    }

    @inline(__always)
    public func consumeTo(_ seq: [UInt8]) -> ArraySlice<UInt8> {
        return consumeToSlice(seq).toArraySlice()
    }

    @inline(__always)
    public func consumeTo(_ seq: String) -> String {
        return String(decoding: consumeToSlice(seq.utf8Array), as: UTF8.self)
    }

    @inline(__always)
    public func consumeToEndUTF8() -> ArraySlice<UInt8> {
        return consumeToEndUTF8Slice().toArraySlice()
    }

    @inline(__always)
    public func consumeLetterSequence() -> ArraySlice<UInt8> {
        return consumeLetterSequenceSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeLetterThenDigitSequence() -> ArraySlice<UInt8> {
        return consumeLetterThenDigitSequenceSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeHexSequence() -> ArraySlice<UInt8> {
        return consumeHexSequenceSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeDigitSequence() -> ArraySlice<UInt8> {
        return consumeDigitSequenceSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeToAnyOfOne(_ a: UInt8) -> ArraySlice<UInt8> {
        return consumeToAnyOfOneSlice(a).toArraySlice()
    }

    @inline(__always)
    public func consumeToAnyOfTwo(_ a: UInt8, _ b: UInt8) -> ArraySlice<UInt8> {
        return consumeToAnyOfTwoSlice(a, b).toArraySlice()
    }

    @inline(__always)
    public func consumeToAnyOfThree(_ a: UInt8, _ b: UInt8, _ c: UInt8) -> ArraySlice<UInt8> {
        return consumeToAnyOfThreeSlice(a, b, c).toArraySlice()
    }

    @inline(__always)
    public func consumeToAnyOfFour(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> ArraySlice<UInt8> {
        return consumeToAnyOfFourSlice(a, b, c, d).toArraySlice()
    }

    @inline(__always)
    public func consumeData() -> ArraySlice<UInt8> {
        return consumeDataSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeDataFastNoNull() -> ArraySlice<UInt8> {
        return consumeDataSlice().toArraySlice()
    }

    @inline(__always)
    @inline(__always)
    public func consumeTagName() -> ArraySlice<UInt8> {
        return consumeTagNameSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeTagNameWithUppercaseFlag() -> (ArraySlice<UInt8>, Bool) {
        let (slice, hasUppercase) = consumeTagNameWithUppercaseFlagSlice()
        return (slice.toArraySlice(), hasUppercase)
    }

    @inline(__always)
    public func consumeAttributeName() -> ArraySlice<UInt8> {
        return consumeAttributeNameSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeAttributeValueUnquoted() -> ArraySlice<UInt8> {
        return consumeAttributeValueUnquotedSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeAttributeValueDoubleQuoted() -> ArraySlice<UInt8> {
        return consumeAttributeValueDoubleQuotedSlice().toArraySlice()
    }

    @inline(__always)
    public func consumeAttributeValueSingleQuoted() -> ArraySlice<UInt8> {
        return consumeAttributeValueSingleQuotedSlice().toArraySlice()
    }

}

extension CharacterReader: CustomDebugStringConvertible {
    public var debugDescription: String {
        return toString()
    }
}
