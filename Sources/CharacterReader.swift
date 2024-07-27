import Foundation

public final class CharacterReader {
    private static let empty = ""
    public static let EOF: UnicodeScalar = "\u{FFFF}" // 65535
    private let input: String
    private var pos: String.Index
    private var mark: String.Index
    
    public init(_ input: String) {
        self.input = input
        self.pos = input.startIndex
        self.mark = input.startIndex
    }
    
    public func getPos() -> Int {
        return input.distance(from: input.startIndex, to: pos)
    }
    
    public func isEmpty() -> Bool {
        return pos >= input.endIndex
    }
    
    public func current() -> UnicodeScalar {
        return pos < input.endIndex ? input.unicodeScalars[pos] : CharacterReader.EOF
    }
    
    @discardableResult
    public func consume() -> UnicodeScalar {
        guard pos < input.endIndex else {
            return CharacterReader.EOF
        }
        let val = input.unicodeScalars[pos]
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
        let str = String(input[pos])
        input.formIndex(after: &pos)
        return str
    }
    
    public func consumeToAny(_ chars: Set<UnicodeScalar>) -> String {
        let start = pos
        let utf8CharArrays = chars.map { Array($0.utf8) }
        
        if let result = input.utf8.withContiguousStorageIfAvailable({ buffer -> String in
            var utf8Pos = buffer.startIndex
            while utf8Pos < buffer.endIndex {
                let currentSlice = buffer[utf8Pos..<buffer.endIndex]
                if utf8CharArrays.contains(where: { currentSlice.starts(with: $0) }) {
                    pos = input.index(input.startIndex, offsetBy: utf8Pos)
                    return String(input[start..<pos])
                }
                utf8Pos += 1
            }
            pos = input.endIndex
            return String(input[start..<pos])
        }) {
            return result
        }
        
        while pos < input.endIndex {
            if chars.contains(where: { input[pos].unicodeScalars.contains($0) }) {
                break
            }
            input.formIndex(after: &pos)
        }
        return String(input[start..<pos])
    }
    
    public func consumeTo(_ c: UnicodeScalar) -> String {
        guard let targetIx = nextIndexOf(c) else {
            return consumeToEnd()
        }
        let consumed = cacheString(pos, targetIx)
        pos = targetIx
        return consumed
    }
    
    public func consumeTo(_ seq: String) -> String {
        guard let targetIx = nextIndexOf(seq) else {
            return consumeToEnd()
        }
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
        let endIndex = input.endIndex
        while pos < endIndex {
            let c = input.unicodeScalars[pos]
            if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(.letters)) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeLetterThenDigitSequence() -> String {
        let start = pos
        let endIndex = input.endIndex
        while pos < endIndex {
            let c = input.unicodeScalars[pos]
            if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(.letters)) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        while pos < endIndex {
            let c = input.unicodeScalars[pos]
            if (c >= "0" && c <= "9") {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeHexSequence() -> String {
        let start = pos
        let endIndex = input.endIndex
        while pos < endIndex {
            let c = input.unicodeScalars[pos]
            if ((c >= "0" && c <= "9") || (c >= "A" && c <= "F") || (c >= "a" && c <= "f")) {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func consumeDigitSequence() -> String {
        let start = pos
        let endIndex = input.endIndex
        while pos < endIndex {
            let c = input.unicodeScalars[pos]
            if (c >= "0" && c <= "9") {
                input.formIndex(after: &pos)
            } else {
                break
            }
        }
        return cacheString(start, pos)
    }
    
    public func matches(_ c: UnicodeScalar) -> Bool {
        return !isEmpty() && input.unicodeScalars[pos] == c
    }
    
    public func matches(_ seq: String, ignoreCase: Bool = false, consume: Bool = false) -> Bool {
        var current = pos
        let scalars = seq.unicodeScalars
        let endIndex = input.endIndex
        for scalar in scalars {
            guard current < endIndex else { return false }
            let c = input.unicodeScalars[current]
            if ignoreCase {
                guard c.uppercase == scalar.uppercase else { return false }
            } else {
                guard c == scalar else { return false }
            }
            input.unicodeScalars.formIndex(after: &current)
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
        return seq.contains(input.unicodeScalars[pos])
    }
    
    public func matchesAnySorted(_ seq: [UnicodeScalar]) -> Bool {
        return matchesAny(seq)
    }
    
    public func matchesLetter() -> Bool {
        guard pos < input.endIndex else { return false }
        let c = input.unicodeScalars[pos]
        return (c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c.isMemberOfCharacterSet(.letters)
    }
    
    public func matchesDigit() -> Bool {
        guard pos < input.endIndex else { return false }
        let c = input.unicodeScalars[pos]
        return c >= "0" && c <= "9"
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
        return String(input[pos...])
    }
    
    private func cacheString(_ start: String.Index, _ end: String.Index) -> String {
        return String(input[start..<end])
    }
    
    public func nextIndexOf(_ c: UnicodeScalar) -> String.Index? {
        return input.unicodeScalars[pos...].firstIndex(of: c)
    }
    
    public func nextIndexOf(_ seq: String) -> String.Index? {
        var start = pos
        let targetScalars = seq.unicodeScalars
        guard let firstChar = targetScalars.first else { return pos }
        MATCH: while true {
            guard let firstCharIx = input.unicodeScalars[start...].firstIndex(of: firstChar) else { return nil }
            var current = firstCharIx
            for scalar in targetScalars.dropFirst() {
                input.unicodeScalars.formIndex(after: &current)
                guard current < input.endIndex else { return nil }
                if input.unicodeScalars[current] != scalar {
                    start = input.index(after: firstCharIx)
                    continue MATCH
                }
            }
            return firstCharIx
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
