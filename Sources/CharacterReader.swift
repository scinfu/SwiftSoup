import Foundation

public final class CharacterReader {
    private static let empty = ""
    public static let EOF: UnicodeScalar = "\u{FFFF}" // 65535
    private let input: String.UTF8View
    private var pos: String.UTF8View.Index
    private var mark: String.UTF8View.Index
    
    public init(_ input: String) {
        self.input = input.utf8
        self.pos = self.input.startIndex
        self.mark = self.input.startIndex
    }
    
    public func getPos() -> Int {
        return input.distance(from: input.startIndex, to: pos)
    }
    
    public func isEmpty() -> Bool {
        return pos >= input.endIndex
    }
    
    public func current() -> UnicodeScalar {
        guard pos < input.endIndex else { return CharacterReader.EOF }
        return UnicodeScalar(input[pos])
    }
    
    @discardableResult
    public func consume() -> UnicodeScalar {
        guard pos < input.endIndex else { return CharacterReader.EOF }
        let val = UnicodeScalar(input[pos])
        input.formIndex(after: &pos)
        return val
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
        let scalar = UnicodeScalar(input[pos])
        input.formIndex(after: &pos)
        return String(scalar)
    }
    
    public func consumeToAny(_ chars: Set<UnicodeScalar>) -> String {
        let start = pos
        let utf8CharArrays = chars.map { Array($0.utf8) }
        
        if let result = input.withContiguousStorageIfAvailable({ buffer -> String in
            var utf8Pos = buffer.startIndex
            while utf8Pos < buffer.endIndex {
                let currentSlice = buffer[utf8Pos..<buffer.endIndex]
                if utf8CharArrays.contains(where: { currentSlice.starts(with: $0) }) {
                    let end = input.index(input.startIndex, offsetBy: utf8Pos - buffer.startIndex)
                    pos = end
                    let distance = buffer.distance(from: buffer.startIndex, to: utf8Pos)
                    return String(decoding: buffer[..<distance], as: UTF8.self)
                }
                utf8Pos += 1
            }
            pos = input.endIndex
            let distance = buffer.distance(from: buffer.startIndex, to: utf8Pos)
            return String(decoding: buffer[..<distance], as: UTF8.self)
        }) {
            return result
        }
        
        while pos < input.endIndex {
            let scalar = UnicodeScalar(input[pos])
            if chars.contains(scalar) {
                break
            }
            input.formIndex(after: &pos)
        }
        return String(decoding: input[start..<pos], as: UTF8.self)
    }

    public func consumeTo(_ c: UnicodeScalar) -> String {
        guard let targetIx = nextIndexOf(c) else { return consumeToEnd() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    public func consumeTo(_ seq: String) -> String {
        guard let targetIx = nextIndexOf(seq) else { return consumeToEnd() }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    public func consumeToEnd() -> String {
        let consumed = cacheString(pos, input.endIndex)
        pos = input.endIndex
        return consumed
    }
    
    public func consumeLetterSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let scalar = UnicodeScalar(input[pos])
            if CharacterSet.letters.contains(scalar) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeLetterThenDigitSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let scalar = UnicodeScalar(input[pos])
            if CharacterSet.letters.contains(scalar) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        while pos < input.endIndex {
            let scalar = UnicodeScalar(input[pos])
            if CharacterSet.decimalDigits.contains(scalar) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeHexSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let scalar = UnicodeScalar(input[pos])
            if CharacterSet(charactersIn: "0123456789ABCDEFabcdef").contains(scalar) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeDigitSequence() -> String {
        let start = pos
        while pos < input.endIndex {
            let scalar = UnicodeScalar(input[pos])
            if CharacterSet.decimalDigits.contains(scalar) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func matches(_ c: UnicodeScalar) -> Bool {
        guard pos < input.endIndex else { return false }
        return UnicodeScalar(input[pos]) == c
    }
    
    public func matches(_ seq: String, ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        var current = pos
        let scalars = seq.unicodeScalars
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
    
    public func matchesIgnoreCase(_ seq: String) -> Bool {
        return matches(seq, ignoreCase: true)
    }
    
    public func matchesAny(_ seq: UnicodeScalar...) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesAny(_ seq: [UnicodeScalar]) -> Bool {
        guard pos < input.endIndex else { return false }
        return seq.contains(UnicodeScalar(input[pos]))
    }
    
    public func matchesAnySorted(_ seq: [UnicodeScalar]) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesLetter() -> Bool {
        guard pos < input.endIndex else { return false }
        return CharacterSet.letters.contains(UnicodeScalar(input[pos]))
    }
    
    public func matchesDigit() -> Bool {
        guard pos < input.endIndex else { return false }
        return CharacterSet.decimalDigits.contains(UnicodeScalar(input[pos]))
    }
    
    @discardableResult
    public func matchConsume(_ seq: String) -> Bool {
        return matches(seq, consume: true)
    }
    
    @discardableResult
    public func matchConsumeIgnoreCase(_ seq: String) -> Bool {
        return matches(seq, ignoreCase: true, consume: true)
    }
    
    public func containsIgnoreCase(_ seq: String) -> Bool {
        let loScan = seq.lowercased(with: Locale(identifier: "en"))
        let hiScan = seq.uppercased(with: Locale(identifier: "eng"))
        return nextIndexOf(loScan) != nil || nextIndexOf(hiScan) != nil
    }
    
    public func toString() -> String {
        return String(input[pos...]) ?? ""
    }
    
    private func cacheString(_ start: String.UTF8View.Index, _ end: String.UTF8View.Index) -> String {
        return String(decoding: input[start..<end], as: UTF8.self)
    }
    
    public func nextIndexOf(_ c: UnicodeScalar) -> String.UTF8View.Index? {
        return input[pos...].firstIndex { UnicodeScalar($0) == c }
    }
    
    public func nextIndexOf(_ seq: String) -> String.UTF8View.Index? {
        var start = pos
        let targetUtf8 = seq.utf8
        
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

    static let dataTerminators: Set<UnicodeScalar> = [.Ampersand, .LessThan, TokeniserStateVars.nullScalr]
    
    public func consumeData() -> String {
        return consumeToAny(CharacterReader.dataTerminators)
    }
    
    static let tagNameTerminators: Set<UnicodeScalar> = [.BackslashT, .BackslashN, .BackslashR, .BackslashF, .Space, .Slash, .GreaterThan, TokeniserStateVars.nullScalr]
    
    public func consumeTagName() -> String {
        return consumeToAny(CharacterReader.tagNameTerminators)
    }
    
    public func consumeToAnySorted(_ chars: Set<UnicodeScalar>) -> String {
        return consumeToAny(chars)
    }
}

extension CharacterReader: CustomDebugStringConvertible {
    public var debugDescription: String {
        return toString()
    }
}
