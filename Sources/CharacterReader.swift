import Foundation

public final class CharacterReader {
    private static let empty = ""
    public static let EOF: UnicodeScalar = "\u{FFFF}" // 65535
    private let input: [UInt8]
    private var pos: [UInt8].Index
    private var mark: [UInt8].Index
    
    public init(_ input: [UInt8]) {
        self.input = input
        self.pos = self.input.startIndex
        self.mark = self.input.startIndex
    }
    
    public convenience init(_ input: String) {
        self.init(input.utf8Array)
    }

    public func getPos() -> Int {
        return input.distance(from: input.startIndex, to: pos)
    }
    
    public func isEmpty() -> Bool {
        return pos >= input.endIndex
    }
    
    public func current() -> UnicodeScalar {
        guard pos < input.endIndex else { return CharacterReader.EOF }
        
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            return scalar
        case .emptyInput, .error:
            return CharacterReader.EOF
        }
    }
    
    @discardableResult
    public func consume() -> UnicodeScalar {
        guard pos < input.endIndex else { return CharacterReader.EOF }
        
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            input.formIndex(after: &pos)
            return scalar
        case .emptyInput, .error:
            return CharacterReader.EOF
        }
    }
    
    public func unconsume() {
        guard pos > input.startIndex else { return }
        input.formIndex(before: &pos)
    }
    
    public func advance() {
        guard pos < input.endIndex else { return }
        input.formIndex(after: &pos)
    }
    
    public func markPos() {
        mark = pos
    }
    
    public func rewindToMark() {
        pos = mark
    }
    
    public func consumeAsString() -> String {
        guard pos < input.endIndex else { return "" }
        
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            input.formIndex(after: &pos)
            return String(scalar)
        case .emptyInput, .error:
            return ""
        }
    }
    
    public func consumeToAny(_ chars: Set<String>) -> String {
        return String(decoding: consumeToAny(Set(chars.map { $0.utf8Array })), as: UTF8.self)
    }
    
    public func consumeToAny(_ chars: Set<[UInt8]>) -> [UInt8] {
        let start = pos
        
        while pos < input.count {
            var matched = false
            for char in chars {
                if input[pos..<min(pos + char.count, input.count)].elementsEqual(char) {
                    matched = true
                    break
                }
            }
            if matched {
                break
            }
            pos += 1
        }
        
        return Array(input[start..<pos])
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
    
    public func consumeTo(_ c: UnicodeScalar) -> [UInt8] {
        guard let targetIx = nextIndexOf(c) else { return consumeToEndUTF8() }
        
        // Convert `String.UTF8View.Index` (targetIx) to `[UInt8].Index` for `input`
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        let byteOffset = utf8View.distance(from: utf8View.startIndex, to: targetIx)
        let targetByteIndex = input.index(input.startIndex, offsetBy: byteOffset)
        
        // Use the `cacheString` method with `pos` and `targetByteIndex`
        let consumed = cacheString(pos, targetByteIndex)
        pos = targetByteIndex // Update `pos` to the new position
        return consumed
    }
    
    public func consumeTo(_ seq: String) -> String {
        return String(decoding: consumeTo(seq.utf8Array), as: UTF8.self)
    }
    
    public func consumeTo(_ seq: [UInt8]) -> [UInt8] {
        guard let targetIx = nextIndexOf(seq) else { return consumeToEndUTF8() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    public func consumeToEnd() -> String {
        return String(decoding: consumeToEndUTF8(), as: UTF8.self)
    }
    
    public func consumeToEndUTF8() -> [UInt8] {
        let consumed = cacheString(pos, input.endIndex)
        pos = input.endIndex
        return consumed
    }
    
    public func consumeLetterSequence() -> [UInt8] {
        let start = pos
        var utf8Decoder = UTF8()
        
        while pos < input.endIndex {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.letters.contains(scalar):
                // Advance the index by the number of bytes consumed for this scalar
                for _ in input[pos..<input.index(pos, offsetBy: scalar.utf8.count)] {
                    input.formIndex(after: &pos)
                }
            case .scalarValue, .emptyInput, .error:
                // Break the loop if not a letter or any decoding issue
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeLetterThenDigitSequence() -> [UInt8] {
        let start = pos
        var utf8Decoder = UTF8()
        
        // Consume letter sequence
        letterLoop: while pos < input.endIndex {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.letters.contains(scalar):
                // Advance the index by the number of bytes consumed for this scalar
                for _ in input[pos..<input.index(pos, offsetBy: scalar.utf8.count)] {
                    input.formIndex(after: &pos)
                }
            default:
                // Stop the loop if not a letter
                break letterLoop
            }
        }
        
        // Consume digit sequence
        digitLoop: while pos < input.endIndex {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.decimalDigits.contains(scalar):
                // Advance the index by the number of bytes consumed for this scalar
                for _ in input[pos..<input.index(pos, offsetBy: scalar.utf8.count)] {
                    input.formIndex(after: &pos)
                }
            default:
                // Stop the loop if not a digit
                break digitLoop
            }
        }
        
        return cacheString(start, pos)
    }
    
    public func consumeHexSequence() -> [UInt8] {
        let start = pos
        var utf8Decoder = UTF8()
        
        while pos < input.endIndex {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(scalar):
                // Advance the index by the number of bytes consumed for this scalar
                for _ in input[pos..<input.index(pos, offsetBy: scalar.utf8.count)] {
                    input.formIndex(after: &pos)
                }
            case .scalarValue, .emptyInput, .error:
                // Break the loop if not a hex character or on decoding error
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeDigitSequence() -> [UInt8] {
        let start = pos
        var utf8Decoder = UTF8()
        
        while pos < input.endIndex {
            var iterator = input[pos...].makeIterator()
            switch utf8Decoder.decode(&iterator) {
            case .scalarValue(let scalar) where CharacterSet.decimalDigits.contains(scalar):
                // Advance the index by the number of bytes consumed for this scalar
                for _ in input[pos..<input.index(pos, offsetBy: scalar.utf8.count)] {
                    input.formIndex(after: &pos)
                }
            case .scalarValue, .emptyInput, .error:
                // Break the loop if not a digit or any decoding issue
                return cacheString(start, pos)
            }
        }
        return cacheString(start, pos)
    }
    
    public func matches(_ c: UnicodeScalar) -> Bool {
        guard pos < input.endIndex else { return false }
        
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
    
    public func matches(_ seq: String, ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        return matches(seq.utf8Array, ignoreCase: ignoreCase, consume: consume)
    }

    public func matches(_ seq: [UInt8], ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        var current = pos
        let scalars = seq.unicodeScalars()
        for scalar in scalars {
            guard current < input.endIndex else { return false }
            let c = UnicodeScalar(input[current])
            if ignoreCase {
                guard c.uppercase == scalar.uppercase else { return false }
            } else {
                guard c == scalar else { return false }
            }
            input.formIndex(after: &current)
        }
        if consume {
            pos = current
        }
        return true
    }
    
    public func matchesIgnoreCase(_ seq: [UInt8]) -> Bool {
        return matches(seq, ignoreCase: true)
    }
    
    public func matchesIgnoreCase(_ seq: String) -> Bool {
        return matches(seq.utf8Array, ignoreCase: true)
    }

    public func matchesAny(_ seq: UnicodeScalar...) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesAny(_ seq: [UnicodeScalar]) -> Bool {
        guard pos < input.endIndex else { return false }
        
        // Decode the UTF-8 byte sequence
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            return seq.contains(scalar)
        case .emptyInput, .error:
            return false // Handle errors or end of input gracefully
        }
    }
    
    public func matchesAnySorted(_ seq: [UnicodeScalar]) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesLetter() -> Bool {
        guard pos < input.endIndex else { return false }
        
        // Decode the UTF-8 byte sequence
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            return CharacterSet.letters.contains(scalar)
        case .emptyInput, .error:
            return false
        }
    }
    
    public func matchesDigit() -> Bool {
        guard pos < input.endIndex else { return false }
        
        // Decode the UTF-8 byte sequence
        var utf8Decoder = UTF8()
        var iterator = input[pos...].makeIterator()
        switch utf8Decoder.decode(&iterator) {
        case .scalarValue(let scalar):
            return CharacterSet.decimalDigits.contains(scalar)
        case .emptyInput, .error:
            return false
        }
    }
    
    @discardableResult
    public func matchConsume(_ seq: [UInt8]) -> Bool {
        return matches(seq, consume: true)
    }
    
    @discardableResult
    public func matchConsumeIgnoreCase(_ seq: [UInt8]) -> Bool {
        return matches(seq, ignoreCase: true, consume: true)
    }
    
    public func containsIgnoreCase(_ seq: [UInt8]) -> Bool {
        let loScan = seq.lowercased()
        let hiScan = seq.uppercased()
        return nextIndexOf(loScan) != nil || nextIndexOf(hiScan) != nil
    }
    
    public func containsIgnoreCase(_ seq: String) -> Bool {
        return containsIgnoreCase(seq.utf8Array)
    }

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
    private func cacheString(_ start: [UInt8].Index, _ end: [UInt8].Index) -> [UInt8] {
        return Array(input[start..<end])
    }
    
    public func nextIndexOf(_ c: UnicodeScalar) -> String.UTF8View.Index? {
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        let startIndex = utf8View.index(utf8View.startIndex, offsetBy: getPos())
        
        return utf8View[startIndex...].firstIndex { UnicodeScalar($0) == c }
    }
    
    public func nextIndexOf(_ seq: String) -> String.UTF8View.Index? {
        let utf8View = String(decoding: input, as: UTF8.self).utf8
        let startIndex = utf8View.index(utf8View.startIndex, offsetBy: getPos())
        let targetUtf8 = Array(seq.utf8) // Convert the sequence into an Array for easier handling
        
        var current = startIndex
        
        while current <= utf8View.endIndex {
            if utf8View[current...].starts(with: targetUtf8) {
                return current
            }
            
            // Safely increment the index to avoid splitting UTF-8 character bytes
            utf8View.formIndex(after: &current)
            if current >= utf8View.endIndex {
                break
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
                guard current < input.endIndex else { return nil }
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

    static let dataTerminators = Set<[UInt8]>([.Ampersand, .LessThan, TokeniserStateVars.nullScalr].map { Array($0.utf8) })
    
    public func consumeData() -> [UInt8] {
        return consumeToAny(CharacterReader.dataTerminators)
    }
    
    static let tagNameTerminators = Set<[UInt8]>([.BackslashT, .BackslashN, .BackslashR, .BackslashF, .Space, .Slash, .GreaterThan, TokeniserStateVars.nullScalr].map { Array($0.utf8) })
    
    public func consumeTagName() -> [UInt8] {
        return consumeToAny(CharacterReader.tagNameTerminators)
    }
    
    public func consumeToAnySorted(_ chars: Set<[UInt8]>) -> [UInt8] {
        return consumeToAny(chars)
    }
}

extension CharacterReader: CustomDebugStringConvertible {
    public var debugDescription: String {
        return toString()
    }
}
